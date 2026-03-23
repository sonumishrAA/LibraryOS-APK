import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'financial_calendar_screen.dart';
import 'notifications_screen.dart';
import 'add_student_wizard.dart';
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';
import '../../services/sync_service.dart';
import 'package:collection/collection.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  bool _isLoading = true;
  double _feeCollected = 0;
  double _pendingAmount = 0;
  int _totalStudents = 0;
  int _activeSeats = 0;
  int _totalSeats = 0;
  int _newThisMonth = 0;
  int _expiredStudents = 0;
  bool _isGenderNeutral = false;
  List<dynamic> _shiftDetailed = [];
  List<dynamic> _recentNotifications = [];

  late AnimationController _bgController;
  late AnimationController _floatController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    _loadDashboardData();
    _triggerSync();
    cacheUpdateNotifier.addListener(_loadDashboardData);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
    cacheUpdateNotifier.removeListener(_loadDashboardData);
    super.dispose();
  }

  void _triggerSync() {
    SyncService(libraryId: currentLibraryId).syncIfNeeded().then((_) {
      if (mounted) _loadDashboardData();
    });
  }

  void _loadDashboardData() {
    setState(() => _isLoading = true);
    _calculateRevenue();
    _calculateStats();
    _calculateShiftOccupancy();
    _loadNotifications();
    setState(() => _isLoading = false);
  }

  void _calculateRevenue() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    
    final students = CacheService.read('students');
    final events = CacheService.read('financial_events');

    double collected = 0;
    double pending = 0;
    double refund = 0;

    for (var s in students) {
      final createdAt = DateTime.tryParse(s['created_at'] ?? '') ?? DateTime(2000);
      if (createdAt.isAfter(firstDay)) {
        final paid = (s['amount_paid'] as num).toDouble();
        final totalFee = (s['total_fee'] as num).toDouble();
        final disc = (s['discount_amount'] as num).toDouble();
        
        collected += paid;
        if (s['is_deleted'] != true) {
          pending += (totalFee - disc - paid).clamp(0.0, double.infinity);
        }
      }
    }

    final refundEvents = events.where((e) => 
      e['event_type'] == 'REFUND_ON_DELETE' && 
      DateTime.parse(e['created_at']).isAfter(firstDay)
    );
    for (var e in refundEvents) {
      refund += (e['amount'] as num).toDouble();
    }

    _feeCollected = collected - refund;
    _pendingAmount = pending;
  }

  void _calculateStats() {
    final students = CacheService.read('students');
    final seats = CacheService.read('seats').where((s) => s['is_active'] == true).toList();
    final lib = CacheService.readSingle('library');

    _totalStudents = students.length;

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    _newThisMonth = students.where((s) => DateTime.parse(s['created_at']).isAfter(firstDay)).length;
    _expiredStudents = students.where((s) => DateTime.parse(s['end_date']).isBefore(now)).length;

    _totalSeats = seats.length;
    _isGenderNeutral = lib?['is_gender_neutral'] ?? false;
  }

  void _calculateShiftOccupancy() {
    final now = DateTime.now();
    final seatShifts = CacheService.read('seat_shifts');
    final students = CacheService.read('students');

    final studentGender = {for (var s in students) s['id']: s['gender']};

    final activeAssignments = seatShifts.where((asgn) {
      final studentId = asgn['student_id'];
      final s = students.firstWhereOrNull((st) => st['id'] == studentId);
      if (s == null || s['is_deleted'] == true) return false;
      final endDate = DateTime.tryParse(s['end_date'] ?? '') ?? DateTime(2000);
      return endDate.isAfter(now);
    }).toList();

    _shiftDetailed = activeAssignments.map((a) => {
      'shift_code': a['shift_code'],
      'students': {'gender': studentGender[a['student_id']]}
    }).toList();

    Map<String, int> counts = {'M': 0, 'A': 0, 'E': 0, 'N': 0};
    for (var s in _shiftDetailed) {
      final code = s['shift_code'];
      if (counts.containsKey(code)) counts[code] = counts[code]! + 1;
    }
    
    _activeSeats = counts.values.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);
  }

  void _loadNotifications() {
    _recentNotifications = CacheService.read('notifications').take(5).toList();
  }

  Widget _buildBlob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final val = _bgController.value;
          final sinVal = math.sin(val * math.pi * 2);
          final cosVal = math.cos(val * math.pi * 2);

          return Stack(
            children: [
              Positioned(
                top: -100 + (sinVal * 40),
                right: -100 + (cosVal * 30),
                child: _buildBlob(500, const Color(0xFF1E293B), 0.3), // Slate 800
              ),
              Positioned(
                bottom: -50 + (sinVal * -60),
                left: -150 + (sinVal * 40),
                child: _buildBlob(400, const Color(0xFF6366F1), 0.2), // Indigo 500
              ),
              Positioned(
                 top: 200 + (cosVal * 50),
                 right: -50 + (sinVal * -30),
                 child: _buildBlob(350, const Color(0xFF10B981), 0.15), // Emerald
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(child: CircularProgressIndicator(color: primaryColor))
      );
    }

    return Container(
      color: const Color(0xFF0F172A), // Dark premium slate background
      child: Stack(
        children: [
          _buildAnimatedBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildRevenueCard(),
                const SizedBox(height: 32),
                Text('LIVE STATISTICS', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 2)),
                const SizedBox(height: 16),
                _buildStatsGrid(),
                const SizedBox(height: 32),
                Text('SHIFT OCCUPANCY', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 2)),
                const SizedBox(height: 16),
                _buildOccupancyList(),
                const SizedBox(height: 32),
                _buildQuickActions(),
                const SizedBox(height: 32),
                _buildNotificationsHeader(),
                const SizedBox(height: 16),
                _buildNotificationsList(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 12, Color? glowColor}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
           const BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
           if (glowColor != null) BoxShadow(color: glowColor.withOpacity(0.15), blurRadius: 24, spreadRadius: -5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.transparent),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OWNER DASHBOARD', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 1.5)),
                Text(libraryName, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
          _buildNotificationBadge(),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return StreamBuilder(
      stream: supabase.from('notifications').stream(primaryKey: ['id']).eq('library_id', currentLibraryId),
      builder: (context, snapshot) {
        final List<dynamic> allData = snapshot.data ?? [];
        final filteredNotifs = allData.where((n) => n['title'] != null && n['message'] != null).toList();
        final count = filteredNotifs.where((n) => n['is_read'] == false).length;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                  icon: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 0, top: 0,
                child: AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    final pulse = (math.sin(_floatController.value * math.pi * 4) + 1) / 2;
                    return Container(
                       padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                       constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                       decoration: BoxDecoration(
                         color: const Color(0xFFEF4444),
                         borderRadius: BorderRadius.circular(9),
                         boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.6), blurRadius: 10 * pulse)],
                       ),
                       alignment: Alignment.center,
                       child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    );
                  }
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
           BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
             right: -20, top: -20,
             child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
             ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text('${DateFormat('MMMM').format(DateTime.now()).toUpperCase()} REVENUE', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 12),
                      Text('₹${NumberFormat('#,##,###').format(_feeCollected)}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
                    ],
                  ),
                  Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                     child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 28),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Container(height: 1, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                       const Icon(Icons.pending_actions_rounded, color: Color(0xFFFCA5A5), size: 16),
                       const SizedBox(width: 6),
                       Text('Pending Dues', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFCA5A5), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Text('₹${NumberFormat('#,##,###').format(_pendingAmount)}', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFCA5A5), fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.15,
      children: [
        _buildStatCard(Icons.groups_rounded, const Color(0xFF3B82F6), '$_totalStudents', 'Total Students', glow: true),
        _buildStatCard(Icons.event_seat_rounded, const Color(0xFF10B981), '$_activeSeats/$_totalSeats', 'Active Seats', glow: true),
        _buildStatCard(Icons.person_add_alt_1_rounded, const Color(0xFFF59E0B), '$_newThisMonth', 'New This Month'),
        _buildStatCard(Icons.timer_off_rounded, const Color(0xFFEF4444), '$_expiredStudents', 'Expired Subs'),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, Color color, String value, String label, {bool glow = false}) {
    return _buildGlassCard(
      padding: EdgeInsets.zero,
      glowColor: glow ? color : null,
      child: Stack(
        children: [
          // Premium watermark icon in the background
          Positioned(
             right: -15, bottom: -15,
             child: Transform.rotate(
               angle: -0.2,
               child: Icon(icon, color: Colors.white.withOpacity(0.04), size: 100),
             ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4))),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      Container(
                         padding: const EdgeInsets.all(6),
                         decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                         child: const Icon(Icons.arrow_outward_rounded, color: Colors.white54, size: 14),
                      )
                   ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                       fit: BoxFit.scaleDown,
                       alignment: Alignment.centerLeft,
                       child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1))
                    ),
                    const SizedBox(height: 6),
                    Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white60, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyList() {
    return _buildGlassCard(
      child: Column(
        children: [
          _shiftRow('M', 'Morning Shift', const Color(0xFF3B82F6)),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          _shiftRow('A', 'Afternoon Shift', const Color(0xFF10B981)),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          _shiftRow('E', 'Evening Shift', const Color(0xFFF59E0B)),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          _shiftRow('N', 'Night Shift', const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _shiftRow(String code, String name, Color color) {
    final shiftStudents = _shiftDetailed.where((s) => s['shift_code'] == code).toList();
    final total = shiftStudents.length;
    final countText = '$total/$_totalSeats';
    
    // Progress bar calculations
    double fillPercent = _totalSeats > 0 ? total / _totalSeats : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
               color: color.withOpacity(0.1), 
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: color.withOpacity(0.3))
            ),
            child: Center(child: Text(code, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  // Animated Progress Bar
                  Container(
                     height: 6,
                     decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(3)),
                     child: FractionallySizedBox(
                        widthFactor: fillPercent,
                        alignment: Alignment.centerLeft,
                        child: Container(
                           decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
                           )
                        ),
                     )
                  )
               ],
            )
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(countText, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
              if (!_isGenderNeutral) ...[
                 const SizedBox(height: 4),
                 Row(
                   children: [
                     Icon(Icons.male, color: Colors.blue[300], size: 10),
                     Text('${shiftStudents.where((s) => (s['students'] as Map?)?['gender'] == 'male').length}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 4),
                     Icon(Icons.female, color: Colors.pink[300], size: 10),
                     Text('${shiftStudents.where((s) => (s['students'] as Map?)?['gender'] == 'female').length}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                   ]
                 )
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionButton('Admission', Icons.person_add_alt_1_rounded, const Color(0xFF6366F1), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddStudentWizard())).then((_) => _loadDashboardData())),
        const SizedBox(width: 16),
        _buildActionButton('Calendar', Icons.receipt_long_rounded, const Color(0xFF10B981), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialCalendarScreen())).then((_) => _loadDashboardData())),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                 width: 48, height: 48,
                 decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]),
                 child: Center(child: Icon(icon, color: Colors.white, size: 24)),
              ),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('ACTIVITY ALERTS', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 2)),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())).then((_) => _loadNotifications()), 
          child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
             child: Text('View All', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))
          )
        ),
      ],
    );
  }

  Widget _buildNotificationsList() {
    if (_recentNotifications.isEmpty) {
      return _buildGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
           child: Column(
             children: [
               Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.notifications_active_outlined, color: Colors.white24, size: 36)),
               ),
               const SizedBox(height: 16),
               Text("No recent alerts found", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
             ],
           ),
        ),
      );
    }

    return Column(
      children: _recentNotifications.map((n) => _buildNotificationCard(n)).toList(),
    );
  }

  Widget _buildNotificationCard(dynamic n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationIcon(n['type']),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['title'] ?? 'Alert', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(n['message'] ?? '', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String? type) {
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;
    switch(type) {
      case 'expiry_warning': icon = Icons.timer_outlined; color = const Color(0xFFF59E0B); break;
      case 'fee_collected': icon = Icons.payments_outlined; color = const Color(0xFF10B981); break;
      case 'new_admission': icon = Icons.person_add_outlined; color = const Color(0xFF6366F1); break;
    }
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
