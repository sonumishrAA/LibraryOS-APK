import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  void _fetchNotifications() {
    setState(() => _isLoading = true);
    _notifs = CacheService.read('notifications');
    setState(() => _isLoading = false);
  }

  int get unreadCount => _notifs.where((n) => n['is_read'] == false).length;

  Future<void> _markRead(String id) async {
    try {
      await supabase.from('notifications').update({'is_read': true}).eq('id', id);
      await CacheService.onNotificationRead(id);
      _fetchNotifications();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await supabase.from('notifications').update({'is_read': true}).eq('library_id', currentLibraryId).eq('is_read', false);
      await CacheService.onAllNotificationsRead();
      _fetchNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Map<String, List<Map<String, dynamic>>> get grouped {
    final now = DateTime.now();
    final today = <Map<String, dynamic>>[];
    final yesterday = <Map<String, dynamic>>[];
    final older = <Map<String, dynamic>>[];

    for (final n in _notifs) {
      if (n['title'] == null || n['title'].toString().isEmpty) continue;

      final d = DateTime.parse(n['created_at']).toLocal();
      final dayOnly = DateTime(d.year, d.month, d.day);
      final todayStr = DateTime(now.year, now.month, now.day);
      final yesterdayStr = todayStr.subtract(const Duration(days: 1));

      if (dayOnly == todayStr) {
        today.add(n);
      } else if (dayOnly == yesterdayStr) {
        yesterday.add(n);
      } else {
        older.add(n);
      }
    }

    return {
      if (today.isNotEmpty) 'Today': today,
      if (yesterday.isNotEmpty) 'Yesterday': yesterday,
      if (older.isNotEmpty) 'Older': older,
    };
  }

  @override
  Widget build(BuildContext context) {
    final groups = grouped;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _notifs.isEmpty
              ? Center(child: Text('No notifications', style: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 13)))
              : ListView(
                  children: [
                    ...groups.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(entry.key.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 11, color: textMuted, letterSpacing: 1)),
                            ),
                            // Notification tiles
                            ...entry.value.map((n) => _notifTile(n)),
                          ],
                        )),
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }

  Widget _notifTile(Map<String, dynamic> n) {
    final unread = n['is_read'] == false;
    final type = n['type'] ?? 'info';
    final color = _notifColor(type);
    final icon = _notifIcon(type);

    return InkWell(
      onTap: () => _markRead(n['id'].toString()),
      child: Container(
        color: unread ? Colors.blue.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    n['title'] ?? 'Notification',
                    style: GoogleFonts.plusJakartaSans(fontWeight: unread ? FontWeight.w700 : FontWeight.w500, fontSize: 13, color: unread ? primaryColor : const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 2),
                  // Message
                  Text(
                    n['message'] ?? '',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  // Time
                  Text(
                    _timeAgo(n['created_at']),
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            // Unread dot
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 14),
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Color _notifColor(String type) => switch (type) {
        'new_admission' => Colors.green,
        'fee_collected' => Colors.blue,
        'expiry_warning' => Colors.orange,
        'subscription_expiry' => Colors.red,
        'renewal_done' => Colors.teal,
        'student_renewed' => Colors.teal,
        'seat_changed' => Colors.indigo,
        'data_cleanup_warning' => Colors.red,
        _ => Colors.grey,
      };

  IconData _notifIcon(String type) => switch (type) {
        'new_admission' => Icons.person_add_rounded,
        'fee_collected' => Icons.payments_rounded,
        'expiry_warning' => Icons.warning_amber_rounded,
        'subscription_expiry' => Icons.subscriptions_rounded,
        'renewal_done' => Icons.autorenew_rounded,
        'student_renewed' => Icons.autorenew_rounded,
        'seat_changed' => Icons.chair_rounded,
        'data_cleanup_warning' => Icons.delete_sweep_rounded,
        _ => Icons.notifications_rounded,
      };

  String _timeAgo(String createdAt) {
    final d = DateTime.parse(createdAt).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
