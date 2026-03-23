import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../globals.dart';
import '../login_screen.dart';
import 'home_tab.dart';
import 'libraries_tab.dart';
import 'messages_tab.dart';
import 'pricing_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  final GlobalKey<HomeTabState> _homeKey = GlobalKey<HomeTabState>();
  final GlobalKey<LibrariesTabState> _librariesKey = GlobalKey<LibrariesTabState>();
  final GlobalKey<MessagesTabState> _messagesKey = GlobalKey<MessagesTabState>();
  final GlobalKey<PricingTabState> _pricingKey = GlobalKey<PricingTabState>();

  late final List<Widget> _tabs = [
    HomeTab(key: _homeKey),
    LibrariesTab(key: _librariesKey),
    MessagesTab(key: _messagesKey),
    PricingTab(key: _pricingKey),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Refresh the target tab data
    Future.delayed(const Duration(milliseconds: 100), () {
      switch (index) {
        case 0: _homeKey.currentState?.fetchStats(); break;
        case 1: _librariesKey.currentState?.fetchLibraries(); break;
        case 2: _messagesKey.currentState?.fetchMessages(); break;
        case 3: _pricingKey.currentState?.fetchPlans(); break;
      }
    });
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: adminSurfaceColor,
        title: Text('Logout?', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('You will be signed out.', style: GoogleFonts.plusJakartaSans(color: adminTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: adminTextSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('LOGOUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true) {
      await storage.delete(key: 'admin_jwt');
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double tabWidth = MediaQuery.of(context).size.width / 4;

    return Scaffold(
      backgroundColor: adminBgColor,
      appBar: AppBar(
        backgroundColor: adminBgColor,
        elevation: 0,
        title: Text('Super Admin', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _handleLogout),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: Container(
        height: 64 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: adminSurfaceColor,
          border: Border(top: BorderSide(color: adminBorderColor, width: 0.5)),
        ),
        child: Stack(
          children: [
            // Sliding Background Indicator
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutBack,
              left: _selectedIndex * tabWidth + 8,
              top: 8,
              child: Container(
                width: tabWidth - 16,
                height: 48,
                decoration: BoxDecoration(
                  color: adminAccentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: adminAccentColor.withOpacity(0.3), width: 1),
                ),
              ),
            ),
            // Icons Layer
            Row(
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.business_outlined, Icons.business, 'Libraries'),
                _buildNavItem(2, Icons.message_outlined, Icons.message, 'Messages'),
                _buildNavItem(3, Icons.currency_rupee_outlined, Icons.currency_rupee, 'Pricing'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, color: isSelected ? adminAccentColor : adminTextSecondary, size: 24),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.plusJakartaSans(color: isSelected ? adminAccentColor : adminTextSecondary, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
