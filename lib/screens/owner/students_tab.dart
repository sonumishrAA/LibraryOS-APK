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

class _SettingsTabState extends State<SettingsTab>
    with SingleTickerProviderStateMixin {
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
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
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
      _unreadNotifications = allNotifs
          .where((n) => n['is_read'] != true)
          .length;

      // syncStaff() saves a single object, not a list
      _currentUser = CacheService.readSingle('staff');

      _planCount = _comboPlans.length;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_libraryData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load settings',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchSettingsData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Background glows
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
                    colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.15),
                      Colors.transparent,
                    ],
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
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.12),
                      Colors.transparent,
                    ],
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
        Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFB923C).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFB923C).withOpacity(0.3)),
          ),
          child: Text(
            '$_unreadNotifications UNREAD',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFDBA74),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopGrid() {
    return Column(
      children: [
        _buildExpandableCard(
          0,
          'LIBRARY INFORMATION',
          _libraryData?['name'] ?? 'Library',
          Icons.business,
          _buildLibraryDetails(),
          const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 12),
        _buildExpandableCard(
          1,
          'SHIFT & TIMING',
          '${_shifts.length} Shifts',
          Icons.schedule,
          _buildShiftDetails(),
          const Color(0xFF10B981),
        ),
        const SizedBox(height: 12),
        _buildExpandableCard(
          2,
          'MY PROFILE',
          _currentUser?['name'] ?? 'Account',
          Icons.person_outline,
          _buildProfileDetails(),
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildExpandableCard(
    int index,
    String label,
    String value,
    IconData icon,
    Widget details,
    Color tintColor,
  ) {
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
          border: Border.all(
            color: isExpanded
                ? tintColor.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: tintColor.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tintColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: tintColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: const Icon(
                      Icons.expand_more,
                      color: Colors.white54,
                      size: 16,
                    ),
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
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
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
    if (city != null && city.toString().isNotEmpty)
      locationValue += city.toString();
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
        _buildDetailRow(
          Icons.location_on_outlined,
          'Address',
          _libraryData?['address'] ?? 'N/A',
        ),
        _buildDetailRow(
          Icons.map_outlined,
          'Location',
          locationValue.isEmpty ? 'N/A' : locationValue,
        ),
        _buildDetailRow(
          Icons.phone_outlined,
          'Phone',
          _libraryData?['phone'] ?? 'N/A',
        ),
        _buildDetailRow(
          Icons.chair_alt_rounded,
          'Seats',
          'M: ${_libraryData?['male_seats'] ?? 0}  F: ${_libraryData?['female_seats'] ?? 0}  N: ${_libraryData?['neutral_seats'] ?? 0}',
        ),
        _buildDetailRow(
          Icons.lock_outline,
          'Lockers',
          'M: ${_libraryData?['male_lockers'] ?? 0}  F: ${_libraryData?['female_lockers'] ?? 0}  N: ${_libraryData?['neutral_lockers'] ?? 0}',
        ),
        _buildDetailRow(
          Icons.check_circle_outline,
          'Onboarding',
          _libraryData?['onboarding_done'] == true ? '✅ Done' : '⏳ Pending',
        ),
        _buildDetailRow(
          Icons.calendar_today_outlined,
          'Subscription',
          '${_libraryData?['subscription_status']?.toString().toUpperCase() ?? '—'}  |  Ends: ${_formatSubDate(_libraryData?['subscription_end'])}',
        ),
      ],
    );
  }

  String _formatSubDate(dynamic raw) {
    if (raw == null) return 'N/A';
    try {
      final d = DateTime.parse(raw.toString());
      const mn = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${mn[d.month]} ${d.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  Widget _buildShiftDetails() {
    return Column(
      children: [
        ..._shifts.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.circle,
                    size: 6,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  s['name'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${s['start_time']} - ${s['end_time']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (currentRole == 'owner') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showEditShifts,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text(
                'EDIT TIMINGS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── MY PROFILE ──────────────────────────────────────
  Widget _buildProfileDetails() {
    if (_currentUser == null)
      return const Text(
        'Profile details unavailable',
        style: TextStyle(color: Colors.white54),
      );

    final u = _currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(Icons.person_outline, 'Full Name', u['name'] ?? '—'),
        _buildDetailRow(Icons.alternate_email, 'Email', u['email'] ?? '—'),
        _buildDetailRow(
          Icons.badge_outlined,
          'Role',
          u['role'].toString().toUpperCase(),
        ),
        _buildDetailRow(
          Icons.business_outlined,
          'Library',
          _libraryData?['name'] ?? '—',
        ),
        _buildDetailRow(
          Icons.phone_outlined,
          'Library Phone',
          _libraryData?['phone'] ?? '—',
        ),
        _buildDetailRow(
          Icons.calendar_today_outlined,
          'Member Since',
          _formatSubDate(u['created_at']),
        ),
        if (currentRole == 'owner') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showMyProfileEdit(u),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text(
                'EDIT PROFILE & PASSWORD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
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
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.white38,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildInfrastructureCards() {
    return Column(
      children: [
        _buildInfraCard(
          'Seat Inventory',
          _libraryData != null
              ? '${(_libraryData?['male_seats'] ?? 0) + (_libraryData?['female_seats'] ?? 0) + (_libraryData?['neutral_seats'] ?? 0)} TOTAL SEATS CONFIGURED'
              : 'LOADING...',
          Icons.airline_seat_recline_extra,
          () => _showEditSeatInventory(),
          const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 12),
        _buildInfraCard(
          'Locker & Policy',
          _lockerPolicy != null
              ? '₹${_lockerPolicy?['monthly_fee']}/MO • ${(_lockerPolicy?['eligible_combos'] as List?)?.length ?? 0} COMBOS'
              : 'NOT CONFIGURED',
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

  Widget _buildInfraCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    Color tint,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (currentRole == 'owner')
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // PRICING EDITOR — add/delete months
  // ═══════════════════════════════════════════════════
  void _showEditPricing() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PricingEditor(
        comboPlans: _comboPlans,
        onSave: () => _fetchSettingsData(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // SHIFT EDITOR
  // ═══════════════════════════════════════════════════
  void _showEditShifts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          _ShiftEditor(shifts: _shifts, onSave: () => _fetchSettingsData()),
    );
  }

  // ═══════════════════════════════════════════════════
  // MY PROFILE EDIT — detailed with password
  // ═══════════════════════════════════════════════════
  void _showMyProfileEdit(dynamic s) {
    if (currentRole != 'owner') return;
    final nameCtrl = TextEditingController(text: s['name']);
    final curPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isSaving = false;
    bool showCur = false, showNew = false, showConfirm = false;

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
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.manage_accounts_rounded,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'My Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2D6B),
                  ),
                ),
                Text(
                  'ACCOUNT & SECURITY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),

                // Read-only info cards
                _infoTile(Icons.alternate_email, 'Email', s['email'] ?? '—'),
                const SizedBox(height: 8),
                _infoTile(
                  Icons.badge_outlined,
                  'Role',
                  s['role']?.toString().toUpperCase() ?? '—',
                ),
                _infoTile(
                  Icons.business_outlined,
                  'Library',
                  _libraryData?['name'] ?? '—',
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Editable: name
                _sheetField(
                  'FULL NAME',
                  nameCtrl,
                  Icons.person_outline,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 16),

                // Password section
                Text(
                  'CHANGE PASSWORD',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2D6B),
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Leave blank if you don\'t want to change it',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                _sheetField(
                  'CURRENT PASSWORD',
                  curPassCtrl,
                  Icons.lock_outline_rounded,
                  obscure: !showCur,
                  suffix: IconButton(
                    icon: Icon(
                      showCur
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: textMuted,
                    ),
                    onPressed: () => setSheetState(() => showCur = !showCur),
                  ),
                ),
                const SizedBox(height: 12),
                _sheetField(
                  'NEW PASSWORD',
                  newPassCtrl,
                  Icons.lock_open_rounded,
                  obscure: !showNew,
                  suffix: IconButton(
                    icon: Icon(
                      showNew
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: textMuted,
                    ),
                    onPressed: () => setSheetState(() => showNew = !showNew),
                  ),
                ),
                const SizedBox(height: 12),
                _sheetField(
                  'CONFIRM NEW PASSWORD',
                  confirmPassCtrl,
                  Icons.lock_reset_rounded,
                  obscure: !showConfirm,
                  suffix: IconButton(
                    icon: Icon(
                      showConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: textMuted,
                    ),
                    onPressed: () =>
                        setSheetState(() => showConfirm = !showConfirm),
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);
                            try {
                              // Password change if fields filled
                              if (newPassCtrl.text.isNotEmpty) {
                                if (curPassCtrl.text.isEmpty)
                                  throw 'Enter current password to verify';
                                if (newPassCtrl.text != confirmPassCtrl.text)
                                  throw 'New passwords do not match';
                                if (newPassCtrl.text.length < 8)
                                  throw 'Password must be at least 8 characters';
                                // Re-auth to verify current password
                                final email =
                                    supabase.auth.currentUser?.email ?? '';
                                final re = await supabase.auth
                                    .signInWithPassword(
                                      email: email,
                                      password: curPassCtrl.text,
                                    );
                                if (re.user == null)
                                  throw 'Incorrect current password';
                                await supabase.auth.updateUser(
                                  UserAttributes(password: newPassCtrl.text),
                                );
                              }
                              // Name change
                              if (nameCtrl.text.trim().isNotEmpty &&
                                  nameCtrl.text.trim() != s['name']) {
                                final updated = await supabase
                                    .from('staff')
                                    .update({'name': nameCtrl.text.trim()})
                                    .eq('user_id', s['user_id'])
                                    .select()
                                    .single();
                                await CacheService.onStaffUpdated(updated);
                              }
                              if (mounted) Navigator.pop(context);
                              _fetchSettingsData();
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated ✓'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'SAVE CHANGES',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textMuted),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: textMuted),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // SEAT INVENTORY
  // ═══════════════════════════════════════════════════
  void _showEditSeatInventory() {
    if (currentRole != 'owner') return;
    final isNeutral = (_libraryData?['is_gender_neutral'] as bool? ?? false);
    final neutralCtrl = TextEditingController(
      text: (_libraryData?['neutral_seats'] ?? 0).toString(),
    );
    final maleCtrl = TextEditingController(
      text: (_libraryData?['male_seats'] ?? 0).toString(),
    );
    final femaleCtrl = TextEditingController(
      text: (_libraryData?['female_seats'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => _DarkDialog(
        icon: Icons.chair_alt_rounded,
        iconColor: const Color(0xFF60A5FA),
        iconBg: const Color(0xFF3B82F6),
        title: 'Seat Inventory',
        subtitle: 'MANAGE TOTAL CAPACITY',
        onSave: () async {
          final libUpdate = await supabase
              .from('libraries')
              .update(
                isNeutral
                    ? {'neutral_seats': int.tryParse(neutralCtrl.text) ?? 50}
                    : {
                        'male_seats': int.tryParse(maleCtrl.text) ?? 25,
                        'female_seats': int.tryParse(femaleCtrl.text) ?? 25,
                      },
              )
              .eq('id', currentLibraryId)
              .select()
              .single();
          await CacheService.onLibraryUpdated(libUpdate);
        },
        onSuccess: () => _fetchSettingsData(),
        saveLabel: 'SAVE CHANGES',
        saveColor: const Color(0xFF3B82F6),
        child: isNeutral
            ? _buildModernEntryField(
                label: 'TOTAL SEATS',
                controller: neutralCtrl,
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF60A5FA),
                keyboardType: TextInputType.number,
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildModernEntryField(
                      label: 'MALE SEATS',
                      controller: maleCtrl,
                      icon: Icons.male_rounded,
                      iconColor: const Color(0xFF60A5FA),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernEntryField(
                      label: 'FEMALE SEATS',
                      controller: femaleCtrl,
                      icon: Icons.female_rounded,
                      iconColor: const Color(0xFFF43F5E),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // LOCKER POLICY
  // ═══════════════════════════════════════════════════
  void _showEditLockerPolicy() {
    if (currentRole != 'owner') return;
    final isNeutral = _libraryData?['is_gender_neutral'] as bool? ?? false;
    final feeCtrl = TextEditingController(
      text: _lockerPolicy?['monthly_fee']?.toString() ?? '200',
    );
    final maleCtrl = TextEditingController(
      text: (_libraryData?['male_lockers'] ?? 0).toString(),
    );
    final femaleCtrl = TextEditingController(
      text: (_libraryData?['female_lockers'] ?? 0).toString(),
    );
    final neutralCtrl = TextEditingController(
      text: (_libraryData?['neutral_lockers'] ?? 0).toString(),
    );
    List<String> selectedCombos = List<String>.from(
      _lockerPolicy?['eligible_combos'] ?? [],
    );
    final allCombos = [
      'M',
      'A',
      'E',
      'N',
      'MA',
      'ME',
      'MN',
      'AE',
      'AN',
      'EN',
      'MAE',
      'MAN',
      'MEN',
      'AEN',
      'MAEN',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setD) => _DarkDialog(
          icon: Icons.lock_person_rounded,
          iconColor: const Color(0xFFA78BFA),
          iconBg: const Color(0xFF8B5CF6),
          title: 'Locker Policy',
          subtitle: 'INVENTORY & PRICING',
          onSave: () async {
            final libParams = isNeutral
                ? {'neutral_lockers': int.tryParse(neutralCtrl.text) ?? 5}
                : {
                    'male_lockers': int.tryParse(maleCtrl.text) ?? 0,
                    'female_lockers': int.tryParse(femaleCtrl.text) ?? 0,
                    'neutral_lockers': int.tryParse(neutralCtrl.text) ?? 0,
                  };
            final libUpdate = await supabase
                .from('libraries')
                .update(libParams)
                .eq('id', currentLibraryId)
                .select()
                .single();
            await CacheService.onLibraryUpdated(libUpdate);

            final policyUpdate = await supabase
                .from('locker_policies')
                .upsert({
                  'library_id': currentLibraryId,
                  'monthly_fee': double.tryParse(feeCtrl.text) ?? 200.0,
                  'eligible_combos': selectedCombos,
                }, onConflict: 'library_id')
                .select()
                .single();
            await CacheService.onLockerPolicyUpdated(policyUpdate);
          },
          onSuccess: () => _fetchSettingsData(),
          saveLabel: 'SAVE POLICY',
          saveColor: const Color(0xFF22C55E),
          child: Column(
            children: [
              isNeutral
                  ? _buildModernEntryField(
                      label: 'TOTAL LOCKERS',
                      controller: neutralCtrl,
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFFA78BFA),
                      keyboardType: TextInputType.number,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildModernEntryField(
                            label: 'MALE',
                            controller: maleCtrl,
                            icon: Icons.male_rounded,
                            iconColor: const Color(0xFF60A5FA),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernEntryField(
                            label: 'FEMALE',
                            controller: femaleCtrl,
                            icon: Icons.female_rounded,
                            iconColor: const Color(0xFFF43F5E),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 20),
              _buildModernEntryField(
                label: 'MONTHLY FEE (₹)',
                controller: feeCtrl,
                icon: Icons.currency_rupee_rounded,
                iconColor: const Color(0xFFFBBF24),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ELIGIBLE COMBOS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white54,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCombos.map((combo) {
                  final isSel = selectedCombos.contains(combo);
                  return GestureDetector(
                    onTap: () => setD(() {
                      if (isSel)
                        selectedCombos.remove(combo);
                      else
                        selectedCombos.add(combo);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSel
                            ? const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              )
                            : null,
                        color: isSel ? null : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        combo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSel ? Colors.white : Colors.white54,
                        ),
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

  Widget _buildModernEntryField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════
  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: TextButton.icon(
        onPressed: _showLogoutConfirm,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.logout, color: Color(0xFFFCA5A5), size: 18),
        label: Text(
          'LOGOUT',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFFECACA),
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 2.0,
          ),
        ),
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
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFF87171),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Logout?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: Colors.white54,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          await CacheService.clearAll();
                          await supabase.auth.signOut();
                          if (mounted)
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'LOGOUT',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
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
}

// ═══════════════════════════════════════════════════
// REUSABLE DARK DIALOG WRAPPER
// ═══════════════════════════════════════════════════
class _DarkDialog extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget child;
  final Future<void> Function() onSave;
  final VoidCallback onSuccess;
  final String saveLabel;
  final Color saveColor;

  const _DarkDialog({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onSave,
    required this.onSuccess,
    required this.saveLabel,
    required this.saveColor,
  });

  @override
  State<_DarkDialog> createState() => _DarkDialogState();
}

class _DarkDialogState extends State<_DarkDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
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
                      gradient: LinearGradient(
                        colors: [
                          widget.iconBg.withOpacity(0.2),
                          widget.iconBg.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 28),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                widget.subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white54,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              widget.child,
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.saveColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.saveColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await widget.onSave();
                            if (mounted) Navigator.pop(context);
                            widget.onSuccess();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved ✓'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            setState(() => _saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.saveLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// PRICING EDITOR — add/delete month durations
// ═══════════════════════════════════════════════════
class _PricingEditor extends StatefulWidget {
  final List<dynamic> comboPlans;
  final VoidCallback onSave;

  const _PricingEditor({required this.comboPlans, required this.onSave});

  @override
  State<_PricingEditor> createState() => _PricingEditorState();
}

class _PricingEditorState extends State<_PricingEditor> {
  final List<String> _combos = [
    'M',
    'A',
    'E',
    'N',
    'MA',
    'ME',
    'MN',
    'AE',
    'AN',
    'EN',
    'MAE',
    'MAN',
    'MEN',
    'AEN',
    'MAEN',
  ];

  // Which months are currently active
  late Set<int> _activeMonths;
  final ScrollController _tableScroll = ScrollController();
  // Controllers: combo -> month -> controller
  late Map<String, Map<int, TextEditingController>> _controllers;

  int _selectedMonth = 1;
  bool _isDeletingMonth = false;
  bool _isAddingMonth = false;
  int? _monthToAdd;

  @override
  void initState() {
    super.initState();
    _activeMonths =
        widget.comboPlans.map<int>((p) => p['months'] as int).toSet()
          ..add(1); // always at least 1
    _controllers = {};
    for (final combo in _combos) {
      _controllers[combo] = {};
      for (final month in _activeMonths) {
        final plan = widget.comboPlans.firstWhereOrNull(
          (p) => p['combination_key'] == combo && p['months'] == month,
        );
        _controllers[combo]![month] = TextEditingController(
          text: plan?['fee']?.toString() ?? '',
        );
      }
    }
    if (_activeMonths.isNotEmpty) {
      _selectedMonth = _activeMonths.first;
    }
  }

  @override
  void dispose() {
    for (final m in _controllers.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    _tableScroll.dispose();
    super.dispose();
  }

  List<int> get _sortedMonths => _activeMonths.toList()..sort();

  // Available months to add (1-12 minus already active)
  List<int> get _availableMonthsToAdd => List.generate(
    12,
    (i) => i + 1,
  ).where((m) => !_activeMonths.contains(m)).toList();

  Future<void> _addMonth(int month) async {
    setState(() => _isAddingMonth = true);
    try {
      // Insert combo_plans rows for all combos for this month (fee=0)
      final rows = _combos
          .map(
            (combo) => {
              'library_id': currentLibraryId,
              'combination_key': combo,
              'months': month,
              'fee': 0.0,
            },
          )
          .toList();
      final inserted = await supabase.from('combo_plans').insert(rows).select();

      // Update cache
      for (final row in (inserted as List)) {
        await CacheService.onComboPlanAdded(Map<String, dynamic>.from(row));
      }

      // Update local state
      setState(() {
        _activeMonths.add(month);
        for (final combo in _combos) {
          _controllers[combo]![month] = TextEditingController(text: '0');
        }
        _selectedMonth = month;
        _monthToAdd = null;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$month-month plan added ✓'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isAddingMonth = false);
    }
  }

  Future<void> _deleteMonth(int month) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Delete $month-month plan?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'All $month-month pricing for every combo will be removed.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isDeletingMonth = true);
    try {
      await supabase
          .from('combo_plans')
          .delete()
          .eq('library_id', currentLibraryId)
          .eq('months', month);

      await CacheService.onComboPlanMonthDeleted(month);

      setState(() {
        _activeMonths.remove(month);
        for (final combo in _combos) {
          _controllers[combo]![month]?.dispose();
          _controllers[combo]!.remove(month);
        }
        if (_selectedMonth == month && _activeMonths.isNotEmpty) {
          _selectedMonth = _activeMonths.first;
        }
      });
      widget.onSave();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$month-month plan deleted'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isDeletingMonth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plans & Pricing',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'MANAGE MONTH DURATIONS & FEES',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white54,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Month chips + add button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DURATION MONTHS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white54,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._sortedMonths.map((m) {
                        final isSelected = _selectedMonth == m;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMonth = m),
                          onLongPress: _sortedMonths.length > 1
                              ? () => _deleteMonth(m)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF818CF8)
                                    : Colors.white.withOpacity(0.1),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withOpacity(0.35),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${m}m',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                if (_sortedMonths.length > 1) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _deleteMonth(m),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: isSelected
                                          ? Colors.white70
                                          : Colors.white38,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),

                      // ADD button
                      if (_availableMonthsToAdd.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showAddMonthPicker(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Color(0xFF34D399),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ADD MONTH',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF34D399),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFF2D3748), height: 1),

            // Table: combo → fee
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Combo sidebar
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: Border(
                        right: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Text(
                            'COMBO',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white54,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: _tableScroll,
                            children: _combos
                                .map(
                                  (combo) => Container(
                                    height: 56,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.white.withOpacity(0.05),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      combo,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Fee column for selected month
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Text(
                            'FEE FOR ${_selectedMonth}M (₹)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: _tableScroll,
                            children: _combos.map((combo) {
                              final ctrl = _controllers[combo]?[_selectedMonth];
                              if (ctrl == null)
                                return const SizedBox(height: 56);
                              return Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.05),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  onChanged: (v) async {
                                    final fee = double.tryParse(v);
                                    if (fee == null) return;
                                    final plan = widget.comboPlans
                                        .firstWhereOrNull(
                                          (p) =>
                                              p['combination_key'] == combo &&
                                              p['months'] == _selectedMonth,
                                        );
                                    if (plan != null) {
                                      final updated = await supabase
                                          .from('combo_plans')
                                          .update({'fee': fee})
                                          .eq('id', plan['id'])
                                          .eq('library_id', currentLibraryId)
                                          .select()
                                          .single();
                                      await CacheService.onComboPlanUpdated(
                                        updated,
                                      );
                                      plan['fee'] = fee;
                                    }
                                  },
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                      Icons.currency_rupee_rounded,
                                      size: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 28,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Done button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'DONE',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Month to Add',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableMonthsToAdd.map((m) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addMonth(m);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      '$m Month${m > 1 ? 's' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF34D399),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SHIFT EDITOR
// ═══════════════════════════════════════════════════
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
    _localShifts = widget.shifts
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final current = isStart
        ? _localShifts[index]['start_time']
        : _localShifts[index]['end_time'];
    final parts = current.toString().split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: primaryColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final timeStr =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isStart)
          _localShifts[index]['start_time'] = timeStr;
        else
          _localShifts[index]['end_time'] = timeStr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        32,
        12,
        32,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEA580C).withOpacity(0.2),
                      const Color(0xFFEA580C).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Color(0xFFF97316),
                  size: 28,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withOpacity(0.5),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Shift Timings',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'CONFIGURE YOUR WORKING HOURS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: List.generate(_localShifts.length, (index) {
                  final s = _localShifts[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wb_sunny_rounded,
                            color: Color(0xFFFCD34D),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            s['name'],
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _buildTimeBlock(
                          s['start_time'],
                          () => _pickTime(index, true),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '-',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                        _buildTimeBlock(
                          s['end_time'],
                          () => _pickTime(index, false),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                try {
                  for (final s in _localShifts) {
                    final updated = await supabase
                        .from('shifts')
                        .update({
                          'start_time': s['start_time'],
                          'end_time': s['end_time'],
                        })
                        .eq('id', s['id'])
                        .select()
                        .single();
                    await CacheService.onShiftUpdated(updated);
                  }
                  widget.onSave();
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Timings updated ✓'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'SAVE TIMINGS',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          time,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
