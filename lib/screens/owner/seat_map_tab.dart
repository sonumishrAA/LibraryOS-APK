import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';

class SeatMapTab extends StatefulWidget {
  const SeatMapTab({super.key});

  @override
  State<SeatMapTab> createState() => _SeatMapTabState();
}

class _SeatMapTabState extends State<SeatMapTab> with TickerProviderStateMixin {
  double rs(BuildContext context, double size) {
    final width = MediaQuery.of(context).size.width;
    return size * (width / 390);
  }

  String getSeatNumber(String? seatId) {
    if (seatId == null) return '—';
    final seat = _seats.firstWhere(
      (s) => s['id']?.toString() == seatId.toString(),
      orElse: () => <String, dynamic>{},
    );
    return seat['seat_number']?.toString() ?? '—';
  }

  String _genderFilter = 'ALL';
  String _shiftFilter = 'ALL';
  List<dynamic> _seats = [];
  List<dynamic> _occupiedShifts = [];
  bool _isLoading = true;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _bgController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

    _fetchSeatData();
    cacheUpdateNotifier.addListener(_fetchSeatData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchSeatData();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    cacheUpdateNotifier.removeListener(_fetchSeatData);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchSeatData() async {
    setState(() => _isLoading = true);
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      _seats = CacheService.read('seats').where((s) => s['is_active'] == true).toList();
      final allShifts = CacheService.read('seat_shifts');
      final allStudents = CacheService.read('students');

      _occupiedShifts = allShifts.map((s) {
        final student = allStudents.firstWhereOrNull((st) => st['id']?.toString() == s['student_id']?.toString());
        final endDate = s['end_date']?.toString() ?? student?['end_date']?.toString() ?? todayStr;
        return {
          ...s,
          'end_date': endDate,
          'students': student,
        };
      }).where((s) {
        return (s['end_date'] as String).compareTo(todayStr) >= 0;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching seat map: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get filteredSeats {
    return _seats.where((seat) {
      if (_genderFilter != 'ALL') {
        final seatGender = seat['gender']?.toString().toLowerCase() ?? 'neutral';
        if (seatGender != 'neutral' && seatGender != _genderFilter.toLowerCase()) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final numA = int.tryParse(a['seat_number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(b['seat_number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return numA.compareTo(numB);
      });
  }

  int get _occupiedCount {
    final now = DateTime.now();
    return _occupiedShifts.where((o) {
      final endDate = o['end_date']?.toString();
      if (endDate == null || endDate.isEmpty) return true;
      try {
        return DateTime.parse(endDate).isAfter(now);
      } catch (_) {
        return true;
      }
    }).length;
  }

  List<String> get visibleShifts {
    if (_shiftFilter == 'ALL') return ['M', 'A', 'E', 'N'];
    return [_shiftFilter];
  }

  Map<String, dynamic>? getStudentForShift(String seatId, String shift) {
    final occupied = _occupiedShifts.firstWhereOrNull(
      (o) => o['seat_id']?.toString() == seatId && o['shift_code']?.toString() == shift,
    );
    if (occupied == null) return null;
    return occupied['students'] as Map<String, dynamic>?;
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

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 24, Color? glowColor, Border? border}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: Colors.white.withOpacity(0.08)),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(child: CircularProgressIndicator(color: primaryColor))
      );
    }
    
    final seats = filteredSeats;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seat Map', style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 18), fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${seats.length} seats  •  $_occupiedCount occupied', style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 13), color: Colors.white54, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          // Gender pills - Glassmorphic
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1))
            ),
            child: Row(
              children: ['ALL', 'male', 'female']
                  .map((g) => GestureDetector(
                        onTap: () => setState(() {
                          _genderFilter = g;
                          _currentPage = 0;
                          if (_pageController.hasClients) _pageController.jumpToPage(0);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: rs(context, 10), vertical: rs(context, 4)),
                          decoration: BoxDecoration(
                              color: _genderFilter == g ? const Color(0xFF6366F1).withOpacity(0.3) : Colors.transparent, 
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _genderFilter == g ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.transparent)
                          ),
                          child: Text(
                            g == 'ALL' ? 'All' : g == 'male' ? 'M' : 'F',
                            style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 11), fontWeight: FontWeight.w700, color: _genderFilter == g ? Colors.white : Colors.white54),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                // Shift filter row - Glassmorphic
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(
                    children: ['ALL', 'M', 'A', 'E', 'N'].map((s) {
                      final selected = _shiftFilter == s;
                      final shiftColors = {
                        'M': const Color(0xFF3B82F6),
                        'A': const Color(0xFF10B981),
                        'E': const Color(0xFFF59E0B),
                        'N': const Color(0xFF8B5CF6),
                      };
                      final color = s == 'ALL' ? const Color(0xFF6366F1) : shiftColors[s]!;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _shiftFilter = s;
                            _currentPage = 0;
                            if (_pageController.hasClients) _pageController.jumpToPage(0);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: rs(context, 14), vertical: rs(context, 6)),
                            decoration: BoxDecoration(
                                color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05), 
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1))
                            ),
                            child: Text(s == 'ALL' ? 'All' : s, style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 13), fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.white54)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
      
                // Counter
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swipe, size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text('${_currentPage + 1} / ${seats.length}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
      
                // PageView
                Expanded(
                  child: seats.isEmpty
                      ? Center(child: Text('No seats found', style: GoogleFonts.plusJakartaSans(color: Colors.white54)))
                      : Row(
                          children: [
                            // Left nav
                            GestureDetector(
                              onTap: _currentPage > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
                              child: Container(
                                width: rs(context, 32),
                                height: rs(context, 32),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(color: _currentPage > 0 ? Colors.white.withOpacity(0.1) : Colors.transparent, shape: BoxShape.circle),
                                child: Icon(Icons.chevron_left, color: _currentPage > 0 ? Colors.white : Colors.white24, size: rs(context, 22)),
                              ),
                            ),
                            // Card
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: seats.length,
                                onPageChanged: (i) => setState(() => _currentPage = i),
                                itemBuilder: (_, i) => _seatPage(seats[i]),
                              ),
                            ),
                            // Right nav
                            GestureDetector(
                              onTap: _currentPage < seats.length - 1 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
                              child: Container(
                                width: rs(context, 32),
                                height: rs(context, 32),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(color: _currentPage < seats.length - 1 ? Colors.white.withOpacity(0.1) : Colors.transparent, shape: BoxShape.circle),
                                child: Icon(Icons.chevron_right, color: _currentPage < seats.length - 1 ? Colors.white : Colors.white24, size: rs(context, 22)),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getOccupiedList(String seatId) {
    return ['M', 'A', 'E', 'N'].where((s) => getStudentForShift(seatId, s) != null).toList();
  }

  Widget _seatPage(Map seat) {
    try {
      final seatId = seat['id']?.toString() ?? '';
      final occupiedList = _getOccupiedList(seatId);
      final occupiedCount = occupiedList.length;

      return Padding(
        padding: EdgeInsets.fromLTRB(rs(context, 14), 4, rs(context, 14), 14),
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            // Pulse border/glow instead of floating to keep text perfectly stable
            final pulse = (math.sin(_floatController.value * math.pi * 2) + 1) / 2; // 0.0 to 1.0
            final dynamicGlow = Color.lerp(Colors.transparent, const Color(0xFF6366F1).withOpacity(0.2), pulse);
            final dynamicBorder = Border.all(color: Colors.white.withOpacity(0.05 + (pulse * 0.1)));

            return _buildGlassCard(
              padding: EdgeInsets.zero,
              glowColor: dynamicGlow,
              border: dynamicBorder,
              child: Column(
                children: [
                  // Premium Gradient Card header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                        border: Border(bottom: BorderSide(color: Colors.white24)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text(seat['seat_number']?.toString() ?? '—',
                                style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 20), fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          // Occupied indicator
                          Text('$occupiedCount/4 occupied',
                              style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 13), color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
                          const Spacer(),
                          // Gender badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: Text(seat['gender'].toString().toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 12), color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),
      
                    // Shift list
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: visibleShifts.map((shift) {
                            final student = getStudentForShift(seatId, shift);
                            return Expanded(child: _shiftRow(shift, student));
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
          }
        ),
      );
    } catch (e) {
      return Container(color: Colors.red[900], child: Center(child: Text('Error: $e')));
    }
  }

  Widget _shiftBadge(String shift) {
    final shiftColors = {
      'M': const Color(0xFF3B82F6), // blue
      'A': const Color(0xFF10B981), // green
      'E': const Color(0xFFF59E0B), // orange
      'N': const Color(0xFF8B5CF6), // purple
    };
    final color = shiftColors[shift] ?? Colors.grey;
    return Container(
      width: rs(context, 32),
      height: rs(context, 32),
      decoration: BoxDecoration(
         color: color.withOpacity(0.2), 
         shape: BoxShape.circle, 
         border: Border.all(color: color.withOpacity(0.4)),
         boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4)]
      ),
      child: Center(child: Text(shift, style: GoogleFonts.plusJakartaSans(fontSize: rs(context, 14), fontWeight: FontWeight.w900, color: color))),
    );
  }

  Widget _statusPill(String status) {
    status = status.toLowerCase();
    final map = {
      'paid': const Color(0xFF10B981),
      'partial': const Color(0xFFF59E0B),
      'pending': const Color(0xFFEF4444),
      'discounted': const Color(0xFF8B5CF6),
    };
    final color = map[status] ?? Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(
        status == 'paid' ? '✓ PAID' : status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
      ),
    );
  }

  Widget _shiftRow(String shift, Map? student) {
    try {
      final isOccupied = student != null;
      final pending = isOccupied ? (((student['total_fee'] as num) - (student['discount_amount'] as num) - (student['amount_paid'] as num)).toDouble()).clamp(0.0, double.infinity) : 0.0;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isOccupied ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isOccupied ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05)),
        ),
        child: isOccupied ? _occupiedContent(shift, student, pending) : _availableContent(shift),
      );
    } catch (e) {
      return Container(color: Colors.transparent, child: Text('Error: $e'));
    }
  }

  Widget _occupiedContent(String shift, Map student, double pending) {
    final admDate = student['admission_date']?.toString() ?? '';
    final endDate = student['end_date']?.toString() ?? '';
    final months = student['plan_months'] ?? 1;
    final paid = (student['amount_paid'] as num).toInt();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: _shiftBadge(shift),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Name + status pill same row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      student['name']?.toString() ?? '—',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusPill(student['payment_status']?.toString() ?? 'pending'),
                ],
              ),
              const SizedBox(height: 4),
              // Father
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      student['father_name']?.toString() ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Address
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      student['address']?.toString() ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Date range + plan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_shortDate(admDate)} – ${_shortDate(endDate)}  [${months}m]',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '₹$paid ',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981)),
                        ),
                        if (pending > 0) ...[
                          const TextSpan(text: '• ', style: TextStyle(color: Colors.white38)),
                          TextSpan(
                            text: '₹${pending.toInt()}',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444)),
                          ),
                        ],
                      ],
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _availableContent(String shift) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _shiftBadge(shift),
            const SizedBox(width: 12),
            Text(
              'Available',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white38),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
           children: [
             const SizedBox(width: 44),
             Container(height: 6, width: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(3))),
           ]
        ),
        const SizedBox(height: 8),
        Row(
           children: [
             const SizedBox(width: 44),
             Container(height: 6, width: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(3))),
           ]
        ),
      ],
    );
  }

  String _shortDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '—';
    try {
      final d = DateTime.parse(date.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return '—';
    }
  }
}
