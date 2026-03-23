import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../constants.dart';
import '../../globals.dart';
import '../../login_screen.dart';
import 'home_tab.dart';
import 'seat_map_tab.dart';
import 'settings_tab.dart';
import 'students_tab.dart';
import 'alerts_tab.dart';
import 'renew_sheet.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _selectedIndex = 0;

  void _showExpiredStaffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Expired'),
        content: const Text('Contact library owner to renew.'),
        actions: [
          TextButton(
            onPressed: () => _handleLogout(),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _openRenewFlow() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RenewSheet(),
    );
  }

  bool _showSubscriptionBanner() {
    final daysLeft = subscriptionEnd.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7 && subscriptionStatus != 'expired';
  }

  @override
  Widget build(BuildContext context) {
    final expired =
        subscriptionEnd.isBefore(DateTime.now()) ||
        subscriptionStatus == 'expired';

    if (expired) {
      return _buildExpiredScreen();
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_showSubscriptionBanner()) _buildSubscriptionBanner(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  HomeTab(
                    onNotificationClick: () =>
                        setState(() => _selectedIndex = 3),
                  ),
                  const SeatMapTab(),
                  StudentsTab(),
                  const AlertsTab(),
                  SettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_outlined, 'active': Icons.home, 'label': 'Home'},
      {
        'icon': Icons.grid_view_outlined,
        'active': Icons.grid_view_rounded,
        'label': 'Seats',
      },
      {
        'icon': Icons.people_outline,
        'active': Icons.people,
        'label': 'Students',
      },
      {
        'icon': Icons.notifications_outlined,
        'active': Icons.notifications,
        'label': 'Alerts',
      },
      {
        'icon': Icons.settings_outlined,
        'active': Icons.settings,
        'label': 'Settings',
      },
    ];

    double width = MediaQuery.of(context).size.width;
    double itemWidth = (width - 32) / 5;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.transparent),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: _selectedIndex * itemWidth + (itemWidth - 54) / 2,
                top: 8,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Row(
                children: items.asMap().entries.map((entry) {
                  int index = entry.key;
                  bool isSelected = _selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected
                                ? entry.value['active'] as IconData
                                : entry.value['icon'] as IconData,
                            color: isSelected
                                ? const Color(0xFF818CF8)
                                : Colors.white54,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.value['label'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF818CF8)
                                  : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_off_outlined,
                  color: Color(0xFFEF4444),
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Subscription Expired',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                currentRole == 'owner'
                    ? 'Your library subscription has expired. Please renew to continue.'
                    : 'The library subscription has expired. Contact the owner to renew.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              if (currentRole == 'owner')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openRenewFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2D6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'RENEW NOW',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Spacer(),
              TextButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout and switch account'),
                style: TextButton.styleFrom(foregroundColor: textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner() {
    final daysLeft = subscriptionEnd.difference(DateTime.now()).inDays;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFFEF3C7)),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB45309),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Subscription expires ${DateFormat('dd MMM').format(subscriptionEnd)} — $daysLeft days left',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
          if (currentRole == 'owner')
            ElevatedButton(
              onPressed: _openRenewFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2D6B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Renew Now',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
