import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';
import '../../login_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  dynamic _libraryData;
  List<dynamic> _shifts = [];
  int _planCount = 0;
  dynamic _lockerPolicy;
  int _unreadNotifications = 0;
  int? _expandedIndex;
  List<dynamic> _comboPlans = [];
  dynamic _currentUser;

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _fetchSettingsData();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _fetchSettingsData() async {
    setState(() => _isLoading = true);
    try {
      _libraryData = CacheService.readSingle('library');
      _shifts = CacheService.read('shifts');
      _comboPlans = CacheService.read('combos');
      _lockerPolicy = CacheService.readSingle('locker_policies');
      final allNotifs = CacheService.read('notifications');
      _unreadNotifications = allNotifs.where((n) => n['is_read'] != true).length;

      final staff = CacheService.read('staff');
      _currentUser = staff.firstWhereOrNull((s) => s['user_id'] == supabase.auth.currentUser?.id);
      
      _planCount = _comboPlans.length;

      // Sort shifts: Morning, Afternoon, Evening, Night
      const order = ['Morning', 'Afternoon', 'Evening', 'Night'];
      _shifts.sort((a, b) {
        int aIdx = order.indexWhere((o) => a['name'].toString().contains(o));
        int bIdx = order.indexWhere((o) => b['name'].toString().contains(o));
        if (aIdx == -1) aIdx = 99;
        if (bIdx == -1) bIdx = 99;
        return aIdx.compareTo(bIdx);
      });

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading cached settings: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_libraryData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            Text('Failed to load settings', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchSettingsData,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Background Glows
        Positioned(
          top: -100,
          left: -100,
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, 50 * _bgController.value),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF8B5CF6).withOpacity(0.15), Colors.transparent],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          right: -100,
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) => Transform.translate(
              offset: Offset(50 * _bgController.value, 0),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF3B82F6).withOpacity(0.12), Colors.transparent],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),

        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTopGrid(),
              const SizedBox(height: 32),
              _buildSectionLabel('INFRASTRUCTURE'),
              const SizedBox(height: 12),
              _buildInfrastructureCards(),
              const SizedBox(height: 32),
              _buildLogoutButton(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Settings', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFFB923C).withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFB923C).withOpacity(0.3))),
          child: Text('$_unreadNotifications UNREAD', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFFDBA74))),
        ),
      ],
    );
  }

  Widget _buildTopGrid() {
    return Column(
      children: [
        _buildExpandableCard(0, 'LIBRARY INFORMATION', _libraryData?['name'] ?? 'Library', Icons.business, _buildLibraryDetails(), const Color(0xFF3B82F6)),
        const SizedBox(height: 12),
        _buildExpandableCard(1, 'SHIFT & TIMING', '${_shifts.length} Shifts', Icons.schedule, _buildShiftDetails(), const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _buildExpandableCard(2, 'MY PROFILE', _currentUser?['name'] ?? 'Account', Icons.person_outline, _buildProfileDetails(), const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _buildExpandableCard(int index, String label, String value, IconData icon, Widget details, Color tintColor) {
    bool isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isExpanded ? tintColor.withOpacity(0.5) : Colors.white.withOpacity(0.08), width: 1.5),
          boxShadow: isExpanded ? [BoxShadow(color: tintColor.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: tintColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: tintColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white54, letterSpacing: 0.5)),
                      Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
                    child: const Icon(Icons.expand_more, color: Colors.white54, size: 16),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: details,
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryDetails() {
    final district = _libraryData?['district'];
    final state = _libraryData?['state'];
    final city = _libraryData?['city'];
    final pincode = _libraryData?['pincode'];

    String locationValue = '';
    if (city != null && city.toString().isNotEmpty) locationValue += city.toString();
    if (district != null && district.toString().isNotEmpty) {
      if (locationValue.isNotEmpty) locationValue += ', ';
      locationValue += district.toString();
    }
    if (state != null && state.toString().isNotEmpty) {
      if (locationValue.isNotEmpty) locationValue += ', ';
      locationValue += state.toString();
    }
    if (pincode != null && pincode.toString().isNotEmpty) {
      locationValue += ' - $pincode';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(Icons.location_on_outlined, 'Address', _libraryData?['address'] ?? 'N/A'),
        _buildDetailRow(Icons.map_outlined, 'Location', locationValue.isEmpty ? 'N/A' : locationValue),
        _buildDetailRow(Icons.phone_outlined, 'Phone', _libraryData?['phone'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildShiftDetails() {
    return Column(
      children: [
        ..._shifts.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.circle, size: 6, color: Color(0xFF10B981))),
              const SizedBox(width: 12),
              Text(s['name'], style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                child: Text('${s['start_time']} - ${s['end_time']}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        )).toList(),
        if (currentRole == 'owner') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showEditShifts,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('EDIT TIMINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.02),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileDetails() {
    if (_currentUser == null) return const Text('Profile details unavailable', style: TextStyle(color: Colors.white54));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(Icons.person_outline, 'Full Name', _currentUser['name']),
        _buildDetailRow(Icons.alternate_email, 'Email Address', _currentUser['email']),
        _buildDetailRow(Icons.badge_outlined, 'Role', _currentUser['role'].toString().toUpperCase()),
        if (currentRole == 'owner')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showMyProfileEdit(_currentUser),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('EDIT PROFILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.02),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white38, letterSpacing: 2.0));
  }

  Widget _buildInfrastructureCards() {
    return Column(
      children: [
        _buildInfraCard(
          'Seat Inventory',
          _libraryData != null ? '${(_libraryData?['male_seats'] ?? 0) + (_libraryData?['female_seats'] ?? 0) + (_libraryData?['neutral_seats'] ?? 0)} TOTAL SEATS CONFIGURED' : 'LOADING...',
          Icons.airline_seat_recline_extra,
          () => _showEditSeatInventory(),
          const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 12),
        _buildInfraCard(
          'Locker & Policy',
          _lockerPolicy != null ? '₹${_lockerPolicy?['monthly_fee']}/MO • ${(_lockerPolicy?['eligible_combos'] as List?)?.length ?? 0} COMBOS' : 'NOT CONFIGURED',
          Icons.lock_outline,
          () => _showEditLockerPolicy(),
          const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 12),
        _buildInfraCard(
          'Plans & Pricing',
          '$_planCount ACTIVE COMBO PLANS',
          Icons.payments_outlined,
          () => _showEditPricing(),
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildInfraCard(String title, String subtitle, IconData icon, VoidCallback onTap, Color tint) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: tint.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.3)),
              ],
            ),
          ),
          if (currentRole == 'owner')
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditPricing() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _PricingEditor(
        planCount: _planCount,
        comboPlans: _comboPlans,
        onSave: () => _fetchSettingsData(),
      ),
    );
  }

  void _showEditShifts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ShiftEditor(
        shifts: _shifts,
        onSave: () => _fetchSettingsData(),
      ),
    );
  }



  void _showMyProfileEdit(dynamic s) {
    if (currentRole != 'owner') return;
    final nameController = TextEditingController(text: s['name']);
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    bool isSaving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFDF2F8), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFFDB2777)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: textMuted)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('My Profile', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1E2D6B))),
                Text('MANAGE YOUR ACCOUNT & SECURITY', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted, letterSpacing: 1.0)),
                const SizedBox(height: 24),
                
                _buildModernEntryField(
                  label: 'FULL NAME',
                  controller: nameController,
                  icon: Icons.badge_outlined,
                  color: const Color(0xFFF9FAFB),
                  iconColor: const Color(0xFF6B7280),
                ),
                const SizedBox(height: 16),
                _buildModernEntryField(
                  label: 'EMAIL ADDRESS',
                  controller: TextEditingController(text: s['email']),
                  icon: Icons.email_outlined,
                  color: const Color(0xFFF3F4F6),
                  iconColor: const Color(0xFF9CA3AF),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                Text('Note: Email cannot be changed for library owners.', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: textMuted, fontStyle: FontStyle.italic)),
  
                _buildModernEntryField(
                  label: 'CURRENT PASSWORD',
                  controller: currentPassController,
                  icon: Icons.lock_outline_rounded,
                  color: const Color(0xFFF9FAFB),
                  iconColor: const Color(0xFF6B7280),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                _buildModernEntryField(
                  label: 'NEW PASSWORD',
                  controller: newPassController,
                  icon: Icons.lock_outline_rounded,
                  color: const Color(0xFFF9FAFB),
                  iconColor: const Color(0xFF6B7280),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                _buildModernEntryField(
                  label: 'CONFIRM NEW PASSWORD',
                  controller: confirmPassController,
                  icon: Icons.lock_reset_rounded,
                  color: const Color(0xFFF9FAFB),
                  iconColor: const Color(0xFF6B7280),
                  obscureText: true,
                ),
  
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      try {
                        setSheetState(() => isSaving = true);
                        if (newPassController.text.isNotEmpty) {
                          if (currentPassController.text.isEmpty) throw 'Please enter current password to verify';
                          if (newPassController.text != confirmPassController.text) throw 'Passwords do not match';
                          if (newPassController.text.length < 8) throw 'New password must be at least 8 characters';
                          
                          // Step 1: Re-authenticate
                          final email = supabase.auth.currentUser?.email ?? '';
                          final authRes = await supabase.auth.signInWithPassword(email: email, password: currentPassController.text);
                          if (authRes.user == null) throw 'Incorrect current password';
                          
                          // Step 2: Update password
                          await supabase.auth.updateUser(UserAttributes(password: newPassController.text));
                        }
                        
                        if (nameController.text != s['name']) {
                          final updated = await supabase.from('staff').update({'name': nameController.text}).eq('user_id', s['user_id']).select().single();
                          await CacheService.onStaffUpdated(updated);
                        }
                        
                        Navigator.pop(context);
                        _fetchSettingsData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green));
                      } catch (e) {
                        setSheetState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('SAVE PROFILE CHANGES', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }






  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
      child: TextButton.icon(
        onPressed: _showLogoutConfirm,
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        icon: const Icon(Icons.logout, color: Color(0xFFFCA5A5), size: 18),
        label: Text('LOGOUT', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFECACA), fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 2.0)),
      ),
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 32),
              ),
              const SizedBox(height: 24),
              Text('Logout?', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Text('Are you sure you want to sign out? You will need to login again to access your library.', 
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70, height: 1.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('CANCEL', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFB91C1C)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          await CacheService.clearAll();
                          await supabase.auth.signOut();
                          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text('LOGOUT', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSeatInventory() {
    if (currentRole != 'owner') return;
    final isNeutral = (_libraryData?['is_gender_neutral'] as bool? ?? false);
    final neutralController = TextEditingController(text: (_libraryData?['neutral_seats'] ?? 0).toString());
    final maleController = TextEditingController(text: (_libraryData?['male_seats'] ?? 0).toString());
    final femaleController = TextEditingController(text: (_libraryData?['female_seats'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFF3B82F6).withOpacity(0.2), const Color(0xFF3B82F6).withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chair_alt_rounded, color: Color(0xFF60A5FA), size: 28),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5)),
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Seat Inventory', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('MANAGE TOTAL CAPACITY', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.5)),
              const SizedBox(height: 32),
              if (isNeutral) 
                _buildModernEntryField(
                  label: 'TOTAL SEATS',
                  controller: neutralController,
                  icon: Icons.groups_rounded,
                  color: Colors.white.withOpacity(0.05),
                  iconColor: const Color(0xFF60A5FA),
                  keyboardType: TextInputType.number,
                )
              else Row(
                children: [
                  Expanded(child: _buildModernEntryField(
                    label: 'MALE SEATS',
                    controller: maleController,
                    icon: Icons.male_rounded,
                    color: Colors.white.withOpacity(0.05),
                    iconColor: const Color(0xFF60A5FA),
                    keyboardType: TextInputType.number,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildModernEntryField(
                    label: 'FEMALE SEATS',
                    controller: femaleController,
                    icon: Icons.female_rounded,
                    color: Colors.white.withOpacity(0.05),
                    iconColor: const Color(0xFFF43F5E),
                    keyboardType: TextInputType.number,
                  )),
                ],
              ),
              const SizedBox(height: 24),
              _buildNoteCard('Seat numbers will be generated based on these counts.'),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: StatefulBuilder(
                  builder: (context, setBtnState) {
                    bool isSaving = false;
                    return ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        try {
                          setBtnState(() => isSaving = true);
                          final Map<String, dynamic> updates = isNeutral
                            ? {'neutral_seats': int.tryParse(neutralController.text) ?? 50}
                            : {'male_seats': int.tryParse(maleController.text) ?? 25, 'female_seats': int.tryParse(femaleController.text) ?? 25};
                          final libUpdate = await supabase.from('libraries').update(updates).eq('id', currentLibraryId).select().single();
                          await CacheService.onLibraryUpdated(libUpdate);
                          Navigator.pop(context);
                          _fetchSettingsData();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory updated'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                        } catch (e) {
                          setBtnState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('SAVE CHANGES', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernEntryField({required String label, required TextEditingController controller, required IconData icon, required Color color, required Color iconColor, TextInputType keyboardType = TextInputType.text, bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditLockerPolicy() {
    if (currentRole != 'owner') return;
    final isNeutral = _libraryData?['is_gender_neutral'] as bool? ?? false;
    final feeController = TextEditingController(text: _lockerPolicy?['monthly_fee']?.toString() ?? '200');
    final maleController = TextEditingController(text: (_libraryData?['male_lockers'] ?? 0).toString());
    final femaleController = TextEditingController(text: (_libraryData?['female_lockers'] ?? 0).toString());
    final neutralController = TextEditingController(text: (_libraryData?['neutral_lockers'] ?? 0).toString());
    List<String> selectedCombos = List<String>.from(_lockerPolicy?['eligible_combos'] ?? []);
    final allCombos = ['M', 'A', 'E', 'N', 'MA', 'ME', 'MN', 'AE', 'AN', 'EN', 'MAE', 'MAN', 'MEN', 'AEN', 'MAEN'];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.2), const Color(0xFF8B5CF6).withOpacity(0.05)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_person_rounded, color: Color(0xFFA78BFA), size: 28),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5)),
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Locker Policy', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('INVENTORY & PRICING', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.5)),
                  
                  const SizedBox(height: 32),
                  if (isNeutral) 
                    _buildModernEntryField(
                      label: 'TOTAL LOCKERS',
                      controller: neutralController,
                      icon: Icons.inventory_2_rounded,
                      color: Colors.white.withOpacity(0.05),
                      iconColor: const Color(0xFFA78BFA),
                      keyboardType: TextInputType.number,
                    )
                  else Row(
                    children: [
                      Expanded(child: _buildModernEntryField(
                        label: 'MALE',
                        controller: maleController,
                        icon: Icons.male_rounded,
                        color: Colors.white.withOpacity(0.05),
                        iconColor: const Color(0xFF60A5FA),
                        keyboardType: TextInputType.number,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModernEntryField(
                        label: 'FEMALE',
                        controller: femaleController,
                        icon: Icons.female_rounded,
                        color: Colors.white.withOpacity(0.05),
                        iconColor: const Color(0xFFF43F5E),
                        keyboardType: TextInputType.number,
                      )),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  _buildModernEntryField(
                    label: 'MONTHLY FEE (₹)',
                    controller: feeController,
                    icon: Icons.currency_rupee_rounded,
                    color: Colors.white.withOpacity(0.05),
                    iconColor: const Color(0xFFFBBF24),
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 32),
                  Text('ELIGIBLE SHIFTS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.0)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allCombos.map((combo) {
                      final isSelected = selectedCombos.contains(combo);
                      return GestureDetector(
                        onTap: () => setDialogState(() { if (isSelected) selectedCombos.remove(combo); else selectedCombos.add(combo); }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]) : null,
                            color: isSelected ? null : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1), width: 1.5),
                            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                          ),
                          child: Text(combo, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.white54)),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: StatefulBuilder(
                      builder: (context, setBtnState) {
                        return ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            try {
                              setBtnState(() => isSaving = true);
                              final libUpdateParams = isNeutral 
                                ? {'neutral_lockers': int.tryParse(neutralController.text) ?? 5} 
                                : {
                                    'male_lockers': int.tryParse(maleController.text) ?? 0, 
                                    'female_lockers': int.tryParse(femaleController.text) ?? 0, 
                                    'neutral_lockers': int.tryParse(neutralController.text) ?? 0
                                  };
                              final libUpdate = await supabase.from('libraries').update(libUpdateParams).eq('id', currentLibraryId).select().single();
                              await CacheService.onLibraryUpdated(libUpdate);

                              final policyUpdate = await supabase.from('locker_policies').upsert({
                                'library_id': currentLibraryId, 
                                'monthly_fee': double.tryParse(feeController.text) ?? 200.0, 
                                'eligible_combos': selectedCombos
                              }, onConflict: 'library_id').select().single();
                              await CacheService.onLockerPolicyUpdated(policyUpdate);
                              Navigator.pop(context);
                              _fetchSettingsData();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Policy updated'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                            } catch (e) {
                              setBtnState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('SAVE POLICY', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFBBF24).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFFDE68A)),
          const SizedBox(width: 8),
          Expanded(child: Text(note, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFFDE68A), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

}

class _PricingEditor extends StatefulWidget {
  final int planCount;
  final List<dynamic> comboPlans;
  final VoidCallback onSave;

  const _PricingEditor({required this.planCount, required this.comboPlans, required this.onSave});

  @override
  State<_PricingEditor> createState() => _PricingEditorState();
}

class _PricingEditorState extends State<_PricingEditor> {
  late Map<String, Map<int, TextEditingController>> _controllers;
  late Map<String, Map<int, bool>> _isDirty;
  final List<String> _combos = ['M', 'A', 'E', 'N', 'MA', 'ME', 'MN', 'AE', 'AN', 'EN', 'MAE', 'MAN', 'MEN', 'AEN', 'MAEN'];
  final List<int> _months = [1, 3, 6, 12];
  int _selectedMonth = 1;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _isDirty = {};
    for (var combo in _combos) {
      _controllers[combo] = {};
      _isDirty[combo] = {};
      for (var month in _months) {
        final plan = widget.comboPlans.firstWhereOrNull(
          (p) => p['combination_key'] == combo && p['months'] == month,
        );
        _controllers[combo]![month] = TextEditingController(text: plan?['fee']?.toString() ?? '');
        _isDirty[combo]![month] = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plans & Pricing', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                    Text('ADJUST PRICING BY DURATION', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.5)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5)),
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
                  items: _months.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text('DURATION: $m MONTH${m > 1 ? 'S' : ''}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
                  )).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedMonth = v); },
                  dropdownColor: const Color(0xFF1E293B),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar for Combos
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                          ),
                          child: Text('COMBINATION', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1.0)),
                        ),
                        ..._combos.map((combo) => Container(
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
                          ),
                          child: Text(combo, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white)),
                        )),
                      ],
                    ),
                  ),
                  
                  // Single Column Grid for Selected Month
                  Expanded(
                    child: Column(
                      children: [
                        // Static Header Row for the selected column
                        Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                          ),
                          child: Text('MONTHLY FEE (₹)', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: primaryColor)),
                        ),
                        
                        // Data Rows
                        ..._combos.map((combo) {
                          final isDirty = _isDirty[combo]![_selectedMonth]!;
                          return Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
                            ),
                            child: TextField(
                              controller: _controllers[combo]![_selectedMonth],
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: isDirty ? const Color(0xFF60A5FA) : Colors.white),
                              textAlign: TextAlign.center,
                              onChanged: (v) async {
                                final fee = double.tryParse(v);
                                if (fee == null) return;
                                final plan = widget.comboPlans.firstWhereOrNull(
                                  (p) => p['combination_key'] == combo && p['months'] == _selectedMonth,
                                );
                                if (plan != null) {
                                  final updated = await supabase.from('combo_plans').update({'fee': fee}).eq('id', plan['id']).eq('library_id', currentLibraryId).select().single();
                                  await CacheService.onComboPlanUpdated(updated);
                                  setState(() {
                                    plan['fee'] = fee;
                                    _isDirty[combo]![_selectedMonth] = true;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 14, color: Color(0xFF94A3B8)),
                                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                                filled: true,
                                fillColor: isDirty ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('DONE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _ShiftEditor extends StatefulWidget {
  final List<dynamic> shifts;
  final VoidCallback onSave;

  const _ShiftEditor({required this.shifts, required this.onSave});

  @override
  State<_ShiftEditor> createState() => _ShiftEditorState();
}

class _ShiftEditorState extends State<_ShiftEditor> {
  late List<Map<String, dynamic>> _localShifts;

  @override
  void initState() {
    super.initState();
    _localShifts = widget.shifts.map((s) => Map<String, dynamic>.from(s)).toList();
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final current = isStart ? _localShifts[index]['start_time'] : _localShifts[index]['end_time'];
    final timeParts = current.toString().split(':');
    final initial = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, surface: Colors.white, onSurface: primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isStart) _localShifts[index]['start_time'] = timeStr;
        else _localShifts[index]['end_time'] = timeStr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, -20)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(32, 12, 32, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFFEA580C).withOpacity(0.2), const Color(0xFFEA580C).withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alarm_on_rounded, color: Color(0xFFF97316), size: 28),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5)),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Shift Timings', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          Text('CONFIGURE YOUR WORKING HOURS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1.5)),
          const SizedBox(height: 32),
          
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: List.generate(_localShifts.length, (index) {
                  final s = _localShifts[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFCD34D), size: 18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(s['name'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white))),
                        
                        _buildTimeBlock(s['start_time'], () => _pickTime(index, true)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-', style: TextStyle(color: Colors.white54))),
                        _buildTimeBlock(s['end_time'], () => _pickTime(index, false)),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFD97706)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: const Color(0xFFEA580C).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                try {
                  for (var s in _localShifts) {
                    final updated = await Supabase.instance.client.from('shifts').update({
                      'start_time': s['start_time'],
                      'end_time': s['end_time'],
                    }).eq('id', s['id']).select().single();
                    await CacheService.onShiftUpdated(updated);
                  }
                  widget.onSave();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timings updated'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('SAVE TIMINGS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(time, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
      ),
    );
  }
}
