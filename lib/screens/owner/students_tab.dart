import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../constants.dart';
import 'student_detail_screen.dart';
import 'add_student_wizard.dart';
import '../../services/cache_service.dart';
import 'package:collection/collection.dart';
import '../../globals.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'ALL';
  List<dynamic> _students = [];
  Map<String, int> _counts = {'ALL': 0, 'PAID': 0, 'PENDING': 0, 'PARTIAL': 0, 'EXPIRED': 0};

  late AnimationController _bgController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    
    _fetchStudents();
    cacheUpdateNotifier.addListener(_fetchStudents);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    cacheUpdateNotifier.removeListener(_fetchStudents);
    super.dispose();
  }

  void _fetchStudents() {
    setState(() => _isLoading = true);
    final students = CacheService.read('students');
    final seats = CacheService.read('seats');
    
    _students = students.map((s) {
      final seat = seats.firstWhereOrNull((st) => st['id'] == s['seat_id']);
      return {
        ...s,
        'seats': seat != null ? {'seat_number': seat['seat_number']} : null,
      };
    }).toList();

    _calculateCounts();
    if (mounted) setState(() => _isLoading = false);
  }

  void _calculateCounts() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    int paid = 0, pending = 0, partial = 0, expired = 0;
    
    for (var s in _students) {
      final isExpired = s['end_date'].compareTo(today) < 0;
      if (isExpired) {
        expired++;
      } else {
        final status = s['payment_status']?.toString().toUpperCase();
        if (status == 'PAID') paid++;
        else if (status == 'PENDING') pending++;
        else if (status == 'PARTIAL') partial++;
      }
    }
    
    _counts = {
      'ALL': _students.length,
      'PAID': paid,
      'PENDING': pending,
      'PARTIAL': partial,
      'EXPIRED': expired,
    };
  }

  List<dynamic> get _filteredStudents {
    final today = DateTime.now().toIso8601String().split('T')[0];

    return _students.where((s) {
      if (s['is_deleted'] == true) return false;
      
      final nameMatches = s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final seatMatches = s['seats'] != null && s['seats']['seat_number'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final comboMatches = s['combination_key']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      if (!(nameMatches || seatMatches || comboMatches)) return false;

      final isExpired = s['end_date'].compareTo(today) < 0;

      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'EXPIRED') return isExpired;
      
      final status = s['payment_status']?.toString().toUpperCase();
      if (isExpired) return false; 
      
      return status == _selectedFilter;
    }).toList();
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildFilterChips(),
                Expanded(
                  child: _filteredStudents.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // Bottom padding for floating nav
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) => _buildStudentCard(_filteredStudents[index]),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Students', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          GestureDetector(
            onTap: _showNewAdmission,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Add Student', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search by name or seat...',
                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['ALL', 'PAID', 'PENDING', 'PARTIAL', 'EXPIRED'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          final colorMap = {
            'ALL': const Color(0xFF6366F1),
            'PAID': const Color(0xFF10B981),
            'PENDING': const Color(0xFFEF4444),
            'PARTIAL': const Color(0xFFF59E0B),
            'EXPIRED': const Color(0xFF8B5CF6),
          };
          final activeColor = colorMap[f]!;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.25) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? activeColor.withOpacity(0.6) : Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Text(f, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.white54)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.3) : Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_counts[f]}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : Colors.white54)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentCard(dynamic s) {
    final status = s['payment_status']?.toString().toUpperCase() ?? 'PENDING';
    final today = DateTime.now().toIso8601String().split('T')[0];
    final isExpired = s['end_date'].compareTo(today) < 0;
    
    Color statusTxt = const Color(0xFFEF4444); // red
    if (status == 'PAID') { statusTxt = const Color(0xFF10B981); } // green
    else if (status == 'PARTIAL') { statusTxt = const Color(0xFFF59E0B); } // orange

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showStudentDetails(s),
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final pulse = (math.sin(_floatController.value * math.pi * 2) + 1) / 2;
            final dynamicBorder = Border.all(
              color: isExpired 
                  ? Colors.red.withOpacity(0.3 + (pulse * 0.2)) 
                  : Colors.white.withOpacity(0.08 + (pulse * 0.04))
            );
            final glowColor = isExpired ? Colors.red.withOpacity(0.15) : null;

            return _buildGlassCard(
              borderRadius: 16,
              border: dynamicBorder,
              glowColor: glowColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(s['name'] ?? '—', 
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white), 
                          overflow: TextOverflow.ellipsis
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red.withOpacity(0.2) : statusTxt.withOpacity(0.15), 
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isExpired ? Colors.red.withOpacity(0.4) : statusTxt.withOpacity(0.3))
                        ),
                        child: Text(isExpired ? 'EXPIRED' : status, 
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: isExpired ? const Color(0xFFFCA5A5) : statusTxt, letterSpacing: 0.5)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoItem(Icons.airline_seat_recline_normal, s['seats']?['seat_number'] ?? 'N/A'),
                      const SizedBox(width: 16),
                      _buildInfoItem(
                        Icons.calendar_today, 
                        '${isExpired ? "Expired" : "Ends"}: ${_formatDate(s['end_date'])}', 
                        color: isExpired ? const Color(0xFFFCA5A5) : null
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoItem(Icons.phone_outlined, s['phone'] ?? 'No Phone'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(s['combination_key'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? Colors.white54),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: color ?? Colors.white70, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showStudentDetails(dynamic s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StudentDetailScreen(student: s)),
    ).then((_) => _fetchStudents());
  }

  void _showNewAdmission() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const AddStudentWizard())
    ).then((_) => _fetchStudents());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text('No students found', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return '—';
    try {
      final date = DateTime.parse(iso.toString());
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]}';
    } catch (e) {
      return iso.toString();
    }
  }
}
