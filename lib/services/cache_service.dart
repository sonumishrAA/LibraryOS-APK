import 'dart:convert';
import 'package:hive/hive.dart';
import '../globals.dart';
import 'sync_service.dart';

class CacheService {
  static List<Map<String, dynamic>> read(String box) => SyncService.read(box);

  static Map<String, dynamic>? readSingle(String box) => SyncService.readSingle(box);

  // Helper to save data back to box
  static Future<void> _updateBox(String boxName, dynamic data) async {
    await Hive.box(boxName).put('data', jsonEncode(data));
    cacheUpdateNotifier.value++;
  }

  // Student add
  static Future<void> onStudentAdded(Map<String, dynamic> student) async {
    final list = read('students');
    list.add(student);
    await _updateBox('students', list);
  }

  // Student update
  static Future<void> onStudentUpdated(Map<String, dynamic> updated) async {
    final list = read('students');
    final i = list.indexWhere((s) => s['id'] == updated['id']);
    if (i != -1) {
      list[i] = updated;
      await _updateBox('students', list);
    }
  }

  // Student delete
  static Future<void> onStudentDeleted(String studentId) async {
    final students = read('students');
    final i = students.indexWhere((s) => s['id'] == studentId);
    if (i != -1) {
      students[i]['is_deleted'] = true;
      await _updateBox('students', students);
    }

    // Also remove seat shifts
    await onSeatShiftsDeleted(studentId);
  }

  // Purane seat shifts hatao student ka
  static Future<void> onSeatShiftsDeleted(String studentId) async {
    final list = read('seat_shifts');
    list.removeWhere((s) => s['student_id'] == studentId);
    await _updateBox('seat_shifts', list);
  }

  // Seat shifts add
  static Future<void> onSeatShiftsAdded(List<Map<String, dynamic>> newShifts) async {
    final list = read('seat_shifts');
    list.addAll(newShifts);
    await _updateBox('seat_shifts', list);
  }

  // Locker update
  static Future<void> onLockerUpdated(String lockerId, String status) async {
    final list = read('lockers');
    final i = list.indexWhere((l) => l['id'] == lockerId);
    if (i != -1) {
      list[i]['status'] = status;
      await _updateBox('lockers', list);
    }
  }

  // Notification add
  static Future<void> onNotificationAdded(Map<String, dynamic> notif) async {
    final list = read('notifications');
    list.insert(0, notif); // newest first
    if (list.length > 50) list.removeLast();
    await _updateBox('notifications', list);
  }

  // Notification mark read
  static Future<void> onNotificationRead(String id) async {
    final list = read('notifications');
    final i = list.indexWhere((n) => n['id'] == id);
    if (i != -1) {
      list[i]['is_read'] = true;
      await _updateBox('notifications', list);
    }
  }

  // All notifications mark read
  static Future<void> onAllNotificationsRead() async {
    final list = read('notifications');
    for (final n in list) {
      n['is_read'] = true;
    }
    await _updateBox('notifications', list);
  }

  // Financial event add
  static Future<void> onFinancialEventAdded(Map<String, dynamic> event) async {
    final list = read('financial_events');
    list.add(event);
    await _updateBox('financial_events', list);
  }

  // Payment record add
  static Future<void> onPaymentRecordAdded(Map<String, dynamic> record) async {
    final list = read('payment_records');
    list.insert(0, record);
    await _updateBox('payment_records', list);
  }

  // Shift update
  static Future<void> onShiftUpdated(Map<String, dynamic> updated) async {
    final list = read('shifts');
    final i = list.indexWhere((s) => s['id'] == updated['id']);
    if (i != -1) {
      list[i] = updated;
      await _updateBox('shifts', list);
    }
  }

  // Combo plan update
  static Future<void> onComboPlanUpdated(Map<String, dynamic> updated) async {
    final list = read('combos');
    final i = list.indexWhere((c) => c['id'] == updated['id']);
    if (i != -1) {
      list[i] = updated;
      await _updateBox('combos', list);
    }
  }

  // Library update
  static Future<void> onLibraryUpdated(Map<String, dynamic> updated) async {
    await Hive.box('library').put('data', jsonEncode(updated));
  }

  // Staff update
  static Future<void> onStaffUpdated(Map<String, dynamic> updated) async {
    final list = read('staff');
    final i = list.indexWhere((s) => s['id'] == updated['id']);
    if (i != -1) {
      list[i] = updated;
      await _updateBox('staff', list);
    }
  }

  // Locker policy update
  static Future<void> onLockerPolicyUpdated(Map<String, dynamic> updated) async {
    await Hive.box('locker_policies').put('data', jsonEncode(updated));
  }

  // Clear all
  static Future<void> clearAll() async {
    final boxes = [
      'library', 'staff', 'seats', 'students', 'shifts', 'combos', 
      'lockers', 'locker_policies', 'seat_shifts', 'notifications', 
      'financial_events', 'payment_records'
    ];
    await Future.wait(boxes.map((b) => Hive.box(b).clear()));
  }
}
