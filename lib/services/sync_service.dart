import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  final String libraryId;
  final _supabase = Supabase.instance.client;

  SyncService({required this.libraryId});

  // Helper — Hive mein save karo
  Future<void> _save(String box, dynamic data) async {
    await Hive.box(box).put('data', jsonEncode(data));
  }

  // Helper — Hive se read karo
  static List<Map<String, dynamic>> read(String box) {
    final raw = Hive.box(box).get('data');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((e) => Map<String, dynamic>.from(e))
        );
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Map<String, dynamic>? readSingle(String box) {
    final raw = Hive.box(box).get('data');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (e) {
      return null;
    }
  }

  // 1. Library
  Future<void> syncLibrary() async {
    final data = await _supabase
      .from('libraries')
      .select()
      .eq('id', libraryId)
      .single();
    await _save('library', data);
  }

  // 2. Staff
  Future<void> syncStaff() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
      .from('staff')
      .select()
      .eq('user_id', userId)
      .single();
    await _save('staff', data);
  }

  // 3. Seats
  Future<void> syncSeats() async {
    final data = await _supabase
      .from('seats')
      .select('id, seat_number, gender, is_active')
      .eq('library_id', libraryId)
      .eq('is_active', true);
    await _save('seats', data);
  }

  // 4. Students
  Future<void> syncStudents() async {
    final data = await _supabase
      .from('students')
      .select()
      .eq('library_id', libraryId)
      .eq('is_deleted', false);
    await _save('students', data);
  }

  // 5. Shifts
  Future<void> syncShifts() async {
    final data = await _supabase
      .from('shifts')
      .select()
      .eq('library_id', libraryId);
    await _save('shifts', data);
  }

  // 6. Combo plans
  Future<void> syncCombos() async {
    final data = await _supabase
      .from('combo_plans')
      .select()
      .eq('library_id', libraryId);
    await _save('combos', data);
  }

  // 7. Lockers
  Future<void> syncLockers() async {
    final data = await _supabase
      .from('lockers')
      .select()
      .eq('library_id', libraryId);
    await _save('lockers', data);
  }

  // 8. Locker policies
  Future<void> syncLockerPolicies() async {
    final data = await _supabase
      .from('locker_policies')
      .select()
      .eq('library_id', libraryId)
      .maybeSingle();
    if (data != null) await _save('locker_policies', data);
  }

  // 9. Seat shifts
  Future<void> syncSeatShifts() async {
    final seats = read('seats');
    final seatIds = seats.map((s) => s['id']).toList();
    if (seatIds.isEmpty) return;
    
    final data = await _supabase
      .from('student_seat_shifts')
      .select('seat_id, shift_code, student_id')
      .inFilter('seat_id', seatIds); // Corrected to just fetch assignments, filtering by student deletion is done client-side or during student sync
    
    await _save('seat_shifts', data);
  }

  // 10. Notifications — last 50
  Future<void> syncNotifications() async {
    final data = await _supabase
      .from('notifications')
      .select()
      .eq('library_id', libraryId)
      .not('title', 'is', null)
      .order('created_at', ascending: false)
      .limit(50);
    await _save('notifications', data);
  }

  // 11. Financial events 
  Future<void> syncFinancialEvents() async {
    final data = await _supabase
      .from('financial_events')
      .select()
      .eq('library_id', libraryId)
      .order('created_at', ascending: true);
    await _save('financial_events', data);
  }

  // 12. Payment records
  Future<void> syncPaymentRecords() async {
    final data = await _supabase
      .from('payment_records')
      .select()
      .eq('library_id', libraryId)
      .order('created_at', ascending: false);
    await _save('payment_records', data);
  }

  // Full sync
  Future<void> fullSync({
    required Function(String step, double progress) onProgress,
  }) async {
    final List<MapEntry<String, Future<void> Function()>> tasks = [
      MapEntry('Syncing library essentials...', syncLibrary),
      MapEntry('Verifying your profile...', syncStaff),
      MapEntry('Mapping floor plan...', syncSeats),
      MapEntry('Organizing student directory...', syncStudents),
      MapEntry('Scheduling library shifts...', syncShifts),
      MapEntry('Configuring combo plans...', syncCombos),
      MapEntry('Securing locker inventory...', syncLockers),
      MapEntry('Reviewing locker policies...', syncLockerPolicies),
      MapEntry('Allocating seat assignments...', syncSeatShifts),
      MapEntry('Updating notification feed...', syncNotifications),
      MapEntry('Analyzing financial trends...', syncFinancialEvents),
      MapEntry('Processing recent payments...', syncPaymentRecords),
    ];

    for (int i = 0; i < tasks.length; i++) {
      onProgress(tasks[i].key, i / tasks.length);
      await tasks[i].value();
    }

    onProgress('All done!', 1.0);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sync', DateTime.now().millisecondsSinceEpoch);
  }

  // Background sync
  Future<void> backgroundSync() async {
    await Future.wait([
      syncLibrary(),
      syncStudents(),
      syncSeatShifts(),
      syncNotifications(),
      syncFinancialEvents(),
      syncPaymentRecords(),
    ]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sync', DateTime.now().millisecondsSinceEpoch);
  }

  // Sync if needed (every 30 mins)
  Future<void> syncIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('last_sync') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 30 minutes = 30 * 60 * 1000 = 1,800,000 ms
    if (now - lastSync > 1800000) {
      await backgroundSync();
    }
  }
}
