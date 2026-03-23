import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../globals.dart';
import '../../services/cache_service.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  List<dynamic> _notifications = [];
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _fetchNotifications();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _fetchNotifications() {
    setState(() => _isLoading = true);
    _notifications = CacheService.read('notifications');
    setState(() => _isLoading = false);
  }

  Future<void> _markAllRead() async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('library_id', currentLibraryId)
          .eq('is_read', false);
      
      await CacheService.onAllNotificationsRead();
      _fetchNotifications();
    } catch (e) {
      debugPrint('Error marking all read: $e');
    }
  }

  Future<void> _markAsRead(dynamic n) async {
    if (n['is_read'] == true) return;
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', n['id']);
      
      await CacheService.onNotificationRead(n['id']);
      _fetchNotifications();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  List<dynamic> get _filteredNotifications {
    return _notifications.where((n) {
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'UNREAD') return n['is_read'] == false;
      
      final type = n['type']?.toString().toLowerCase() ?? '';
      if (_selectedFilter == 'EXPIRY') return type.contains('expiry');
      if (_selectedFilter == 'ADMISSION') return type.contains('admission');
      if (_selectedFilter == 'FEE') return type.contains('fee') || type.contains('payment');
      
      return true;
    }).toList();
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -100 + 50 * math.sin(_bgController.value * 2 * math.pi),
              left: -50 + 30 * math.cos(_bgController.value * 2 * math.pi),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withOpacity(0.15)),
                ),
              ),
            ),
            Positioned(
              bottom: -50 + 40 * math.cos(_bgController.value * 2 * math.pi),
              right: -50 + 40 * math.sin(_bgController.value * 2 * math.pi),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 250, height: 250,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF10B981).withOpacity(0.1)),
                ),
              ),
            ),
            Positioned(
              top: 200 + 30 * math.sin(_bgController.value * 2 * math.pi),
              right: -100 + 20 * math.cos(_bgController.value * 2 * math.pi),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF43F5E).withOpacity(0.1)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasUnread = _notifications.any((n) => n['is_read'] == false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),
          SafeArea(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Activity Alerts', 
                              style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)
                            ),
                            if (hasUnread)
                              TextButton(
                                onPressed: _markAllRead,
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Text('Mark all read', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF818CF8))),
                              ),
                          ],
                        ),
                      ),
                      _buildFilterChips(),
                      Expanded(
                        child: _filteredNotifications.isEmpty 
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 100),
                              itemCount: _filteredNotifications.length,
                              itemBuilder: (context, index) => _buildNotificationCard(_filteredNotifications[index]),
                            ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['ALL', 'UNREAD', 'EXPIRY', 'ADMISSION', 'FEE'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6366F1).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.08)),
                boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 12)] : [],
              ),
              child: Text(
                f, 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: 0.5,
                  color: isSelected ? Colors.white : Colors.white54
                )
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(dynamic n) {
    final isUnread = n['is_read'] == false;
    final createdAt = DateTime.parse(n['created_at']);
    final iconData = _getIconData(n['type']);

    return GestureDetector(
      onTap: () => _markAsRead(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isUnread ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isUnread ? iconData.color.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
          boxShadow: isUnread ? [BoxShadow(color: iconData.color.withOpacity(0.15), blurRadius: 20)] : [],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: iconData.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(iconData.icon, color: iconData.color, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(n['title'] ?? 'Notification', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(n['message'] ?? '', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Text(_timeAgo(createdAt), style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: iconData.color, 
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: iconData.color.withOpacity(0.8), blurRadius: 6)]
                      )
                    ),
                  ],
                ],
              ),
            ),
            if (isUnread)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4, 
                  decoration: BoxDecoration(
                    color: iconData.color,
                    boxShadow: [BoxShadow(color: iconData.color, blurRadius: 8)],
                  )
                ),
              ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color}) _getIconData(String? typeStr) {
    final type = typeStr?.toLowerCase() ?? '';
    if (type.contains('expiry_warning')) return (icon: Icons.timer_outlined, color: const Color(0xFFFBBF24));
    if (type.contains('subscription')) return (icon: Icons.error_outline, color: const Color(0xFFF87171));
    if (type.contains('admission')) return (icon: Icons.person_add_outlined, color: const Color(0xFF38BDF8));
    if (type.contains('fee') || type.contains('payment')) return (icon: Icons.payments_outlined, color: const Color(0xFF34D399));
    if (type.contains('seat')) return (icon: Icons.airline_seat_recline_normal, color: const Color(0xFFA78BFA));
    return (icon: Icons.info_outline, color: const Color(0xFF94A3B8));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none, size: 64, color: Colors.white24),
          ),
          const SizedBox(height: 24),
          Text('No new alerts', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text("You're all caught up!", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
