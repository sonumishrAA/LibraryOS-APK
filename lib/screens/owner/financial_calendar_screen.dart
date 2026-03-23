import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';

class FinancialCalendarScreen extends StatefulWidget {
  const FinancialCalendarScreen({super.key});

  @override
  State<FinancialCalendarScreen> createState() =>
      _FinancialCalendarScreenState();
}

class _FinancialCalendarScreenState extends State<FinancialCalendarScreen>
    with SingleTickerProviderStateMixin {
  int _mode = 1;

  // ── Mode 1 ──────────────────────────────
  DateTime _month = DateTime.now();
  List<Map<String, dynamic>> _m1Events = [];
  double _m1Total = 0, _m1Pending = 0, _m1Discount = 0, _m1Refund = 0;
  bool _isLoading = true;

  // ── Mode 2 ──────────────────────────────
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allEvents = [];
  final Set<String> _expanded = {};
  String _m2Filter = 'ALL';
  bool _isMode2Loading = false; // <<< dedicated loader for mode2

  // ── Table scroll ─────────────────────────
  final ScrollController _headerScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  final ScrollController _bodyScroll = ScrollController();

  late AnimationController _bgController;

  static const double _cName = 120;
  static const double _cType = 38;
  static const double _cOrig = 78;
  static const double _cDisc = 68;
  static const double _cEff = 78;
  static const double _cPlan = 62;
  static const double _cPaid = 72;
  static const double _cDue = 80;
  static const double _cPad = 14;

  double get _tableWidth =>
      _cPad +
      _cName +
      _cType +
      _cOrig +
      _cDisc +
      _cEff +
      _cPlan +
      _cPaid +
      _cDue +
      _cPad;

  // ════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    _bodyHScroll.addListener(() {
      if (_headerScroll.hasClients) _headerScroll.jumpTo(_bodyHScroll.offset);
    });
    _loadMode1();
    _fetchMode2(); // async fetch on start
  }

  @override
  void dispose() {
    _bgController.dispose();
    _headerScroll.dispose();
    _bodyHScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  // DATA — MODE 1
  // ════════════════════════════════════════

  void _loadMode1() {
    setState(() => _isLoading = true);

    final firstStr = DateTime(
      _month.year,
      _month.month,
      1,
    ).toIso8601String().split('T')[0];
    final lastStr = DateTime(
      _month.year,
      _month.month + 1,
      0,
    ).toIso8601String().split('T')[0];

    final students = CacheService.read(
      'students',
    ).where((s) => s['is_deleted'] != true).toList();
    final allEvents = CacheService.read('financial_events');

    final filtered = allEvents.where((e) {
      final d = DateTime.parse(_eventDate(e));
      return d.year == _month.year && d.month == _month.month;
    }).toList()..sort((a, b) => _eventDate(a).compareTo(_eventDate(b)));

    double collected = 0, pending = 0, discount = 0, refund = 0;

    for (final s in students) {
      final adm = s['admission_date']?.toString() ?? '';
      if (adm.compareTo(firstStr) >= 0 && adm.compareTo(lastStr) <= 0) {
        final paid = (s['amount_paid'] as num? ?? 0).toDouble();
        final fee = (s['total_fee'] as num? ?? 0).toDouble();
        final disc = (s['discount_amount'] as num? ?? 0).toDouble();
        pending += (fee - disc - paid).clamp(0.0, double.infinity);
      }
    }

    for (final e in filtered) {
      final amt = (e['amount'] as num? ?? 0).toDouble();
      switch (e['event_type']) {
        case 'REFUND_ON_DELETE':
          refund += amt;
          break;
        case 'DISCOUNT_APPLIED':
          discount += amt;
          break;
        case 'NO_REFUND_ON_DELETE':
          break;
        default:
          collected += amt;
      }
    }

    setState(() {
      _m1Events = filtered;
      _m1Total = collected - refund;
      _m1Pending = pending;
      _m1Discount = discount;
      _m1Refund = refund;
      _isLoading = false;
    });
  }

  // ════════════════════════════════════════
  // DATA — MODE 2  (DB fetch for deleted)
  // ════════════════════════════════════════

  Future<void> _fetchMode2() async {
    if (!mounted) return;
    setState(() => _isMode2Loading = true);

    // Active students from cache (sync ne is_deleted=false wale hi rakhe hain)
    final activeStudents = List<Map<String, dynamic>>.from(
      CacheService.read('students'),
    );

    // Deleted students seedha DB se fetch karo
    List<Map<String, dynamic>> deletedStudents = [];
    try {
      debugPrint('Fetching deleted students for library: $currentLibraryId');
      final result = await supabase
          .from('students')
          .select()
          .eq('library_id', currentLibraryId)
          .eq('is_deleted', true)
          .order('deleted_at', ascending: false);

      deletedStudents = List<Map<String, dynamic>>.from(result as List);
      debugPrint('Found ${deletedStudents.length} deleted students');
    } catch (e) {
      debugPrint('Error fetching deleted students: $e');
    }

    // Financial events from cache
    final allEvents = List<Map<String, dynamic>>.from(
      CacheService.read('financial_events'),
    );

    // Merge: active + deleted, sort by name
    final merged = [...activeStudents, ...deletedStudents]
      ..sort(
        (a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
      );

    if (!mounted) return;
    setState(() {
      _students = merged;
      _allEvents = allEvents;
      _isMode2Loading = false;
    });
  }

  // ════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════

  String _eventDate(Map e) {
    final note = e['note']?.toString() ?? '';
    final m = RegExp(r'admission_date:(\d{4}-\d{2}-\d{2})').firstMatch(note);
    if (m != null) return m.group(1)!;
    return DateTime.parse(
      e['created_at'],
    ).toLocal().toIso8601String().split('T')[0];
  }

  String _planFromNote(String? note) {
    if (note == null) return '—';
    final m = RegExp(r'([MAEN]+-\d+m)').firstMatch(note);
    return m?.group(1) ?? '—';
  }

  double _origFromNote(String? note) {
    if (note == null) return 0;
    final m = RegExp(r'orig:(\d+)').firstMatch(note);
    return double.tryParse(m?.group(1) ?? '0') ?? 0;
  }

  double _discFromNote(String? note) {
    if (note == null) return 0;
    final m = RegExp(r'disc:(\d+)').firstMatch(note);
    return double.tryParse(m?.group(1) ?? '0') ?? 0;
  }

  String _shortDate(String iso) {
    try {
      final d = DateTime.parse(iso);
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
      return '${d.day} ${mn[d.month]}';
    } catch (_) {
      return iso;
    }
  }

  String _mon(int m) => const [
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
  ][m];

  List<Map<String, dynamic>> _studentEvents(String? id, String name) =>
      _allEvents.where((e) {
        if (id != null && id.isNotEmpty && e['student_id'] != null) {
          return e['student_id'] == id;
        }
        return e['student_name'] == name;
      }).toList()..sort((a, b) => _eventDate(a).compareTo(_eventDate(b)));

  // ════════════════════════════════════════
  // BACKGROUND
  // ════════════════════════════════════════

  Widget _blob(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );

  Widget _animatedBg() => Positioned.fill(
    child: AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) {
        final v = _bgController.value;
        final s = math.sin(v * math.pi * 2);
        final c = math.cos(v * math.pi * 2);
        return Stack(
          children: [
            Positioned(
              top: -100 + s * 40,
              right: -100 + c * 30,
              child: _blob(500, const Color(0xFF1E293B), 0.3),
            ),
            Positioned(
              bottom: -50 + s * -60,
              left: -150 + s * 40,
              child: _blob(400, const Color(0xFF6366F1), 0.2),
            ),
            Positioned(
              top: 200 + c * 50,
              right: -50 + s * -30,
              child: _blob(350, const Color(0xFF10B981), 0.15),
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

  // ════════════════════════════════════════
  // GLASS CARD
  // ════════════════════════════════════════

  Widget _glass({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double radius = 12,
    Color? border,
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? Colors.white.withOpacity(0.08)),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 8)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
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

  // ════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(
          'Financial Calendar',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          _animatedBg(),
          SafeArea(
            child: Column(
              children: [
                _buildModeToggle(),
                if (_mode == 1) ...[
                  _buildMonthNav(),
                  _buildSummaryRow(),
                  Expanded(child: _buildMode1Body()),
                ] else ...[
                  _buildMode2Filters(),
                  Expanded(child: _buildMode2Body()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // MODE TOGGLE
  // ════════════════════════════════════════

  Widget _buildModeToggle() => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Row(
      children: [
        _modeBtn(1, 'Timeline Table', Icons.table_rows_outlined),
        _modeBtn(2, 'Student Story', Icons.person_pin_outlined),
      ],
    ),
  );

  Widget _modeBtn(int mode, String label, IconData icon) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _mode = mode);
          if (mode == 2) _fetchMode2(); // re-fetch on every switch
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF6366F1).withOpacity(0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active
                ? Border.all(color: const Color(0xFF818CF8).withOpacity(0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? const Color(0xFF818CF8) : Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // MODE 1 — TIMELINE TABLE
  // ════════════════════════════════════════

  Widget _buildMonthNav() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _navBtn(Icons.chevron_left_rounded, () {
          setState(() => _month = DateTime(_month.year, _month.month - 1));
          _loadMode1();
        }),
        SizedBox(
          width: 140,
          child: Text(
            '${_mon(_month.month)} ${_month.year}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
        _navBtn(Icons.chevron_right_rounded, () {
          setState(() => _month = DateTime(_month.year, _month.month + 1));
          _loadMode1();
        }),
      ],
    ),
  );

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Icon(icon, color: const Color(0xFF818CF8), size: 22),
    ),
  );

  Widget _buildSummaryRow() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    child: Row(
      children: [
        _sBox('Collected', _m1Total, const Color(0xFF10B981)),
        const SizedBox(width: 6),
        _sBox('Pending', _m1Pending, const Color(0xFFEF4444)),
        const SizedBox(width: 6),
        _sBox('Discount', _m1Discount, const Color(0xFFA78BFA)),
        const SizedBox(width: 6),
        _sBox('Refund', _m1Refund, const Color(0xFFF59E0B)),
      ],
    ),
  );

  Widget _sBox(String label, double val, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: c,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              '₹${val.toInt()}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: c,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _hdrRow() {
    ts(String t) => Text(
      t,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Colors.white38,
        letterSpacing: 0.5,
      ),
    );
    return Container(
      color: Colors.white.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: _cPad),
          SizedBox(width: _cName, child: ts('NAME')),
          SizedBox(
            width: _cType,
            child: Center(child: ts('TY')),
          ),
          SizedBox(
            width: _cOrig,
            child: Center(child: ts('ORIGINAL')),
          ),
          SizedBox(
            width: _cDisc,
            child: Center(child: ts('DISCOUNT')),
          ),
          SizedBox(
            width: _cEff,
            child: Center(child: ts('EFFECTIVE')),
          ),
          SizedBox(
            width: _cPlan,
            child: Center(child: ts('PLAN')),
          ),
          SizedBox(
            width: _cPaid,
            child: Align(alignment: Alignment.centerRight, child: ts('PAID')),
          ),
          SizedBox(
            width: _cDue,
            child: Align(
              alignment: Alignment.centerRight,
              child: ts('DUE / STATUS'),
            ),
          ),
          SizedBox(width: _cPad),
        ],
      ),
    );
  }

  Widget _buildMode1Body() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }
    if (_m1Events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white24,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'No activity in ${_mon(_month.month)} ${_month.year}',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in _m1Events) {
      if (e['event_type'] == 'DISCOUNT_APPLIED') continue;
      (grouped[_eventDate(e)] ??= []).add(e);
    }

    return Column(
      children: [
        SingleChildScrollView(
          controller: _headerScroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(width: _tableWidth, child: _hdrRow()),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.06)),
        Expanded(
          child: SingleChildScrollView(
            controller: _bodyHScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _tableWidth,
              child: ListView(
                controller: _bodyScroll,
                children: [
                  ...grouped.entries.map(
                    (entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.02),
                          padding: const EdgeInsets.fromLTRB(14, 7, 14, 5),
                          child: Text(
                            _shortDate(entry.key).toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6366F1),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        ...entry.value.map(_m1Row),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _m1Row(Map e) {
    final type = e['event_type']?.toString() ?? '';
    if (type == 'DISCOUNT_APPLIED') return const SizedBox.shrink();

    final note = e['note']?.toString();
    final paid = (e['amount'] as num? ?? 0).toDouble();
    final due = (e['pending_amount'] as num? ?? 0).toDouble();
    final orig = _origFromNote(note);
    final disc = _discFromNote(note);
    final eff = (orig - disc).clamp(0.0, double.infinity);
    final dispOrig = orig > 0 ? orig : (paid + due + disc);
    final dispEff = orig > 0 ? eff : (paid + due);
    final plan = _planFromNote(note);
    final name = e['student_name']?.toString() ?? '—';
    final (lbl, tc) = _typeConfig(type);
    final dot = _dotColor(type);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.04), width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: _cPad),
            SizedBox(
              width: _cName,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _cType,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tc.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    lbl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: tc,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _cOrig,
              child: Text(
                '₹${dispOrig.toInt()}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: _cDisc,
              child: disc > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '-₹${disc.toInt()}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFFC084FC),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA78BFA).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DISC',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              color: const Color(0xFFC084FC),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '—',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white24,
                      ),
                    ),
            ),
            SizedBox(
              width: _cEff,
              child: Text(
                '₹${dispEff.toInt()}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: disc > 0 ? const Color(0xFFC084FC) : Colors.white60,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              width: _cPlan,
              child: Text(
                plan,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: _cPaid,
              child: Text(
                '₹${paid.toInt()}',
                textAlign: TextAlign.right,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF34D399),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: _cDue,
              child: due > 0
                  ? Text(
                      '₹${due.toInt()}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFFFCA5A5),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '✓ Clear',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
            ),
            SizedBox(width: _cPad),
          ],
        ),
      ),
    );
  }

  (String, Color) _typeConfig(String type) => switch (type) {
    'ADMISSION_FULL' => ('ADM', Colors.blue),
    'ADMISSION_PARTIAL' => ('ADM', Colors.orange),
    'ADMISSION_PENDING' => ('ADM', Colors.red),
    'PAYMENT_RECEIVED' => ('PMT', Colors.teal),
    'RENEWAL' => ('RNW', Colors.indigo),
    'REFUND_ON_DELETE' => ('DEL↩', Colors.orange),
    'NO_REFUND_ON_DELETE' => ('DEL', const Color(0xFFEF9999)),
    _ => ('???', Colors.grey),
  };

  Color _dotColor(String type) => switch (type) {
    'ADMISSION_FULL' => Colors.green,
    'PAYMENT_RECEIVED' => Colors.teal,
    'RENEWAL' => Colors.indigo,
    'ADMISSION_PARTIAL' => Colors.orange,
    'ADMISSION_PENDING' => Colors.red,
    'DISCOUNT_APPLIED' => Colors.purple,
    'REFUND_ON_DELETE' => Colors.orange,
    'NO_REFUND_ON_DELETE' => const Color(0xFFEF9999),
    _ => Colors.grey,
  };

  // ════════════════════════════════════════
  // MODE 2 — FILTERS
  // ════════════════════════════════════════

  Widget _buildMode2Filters() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    int cAll = _students.length;
    int cPaid = 0, cPartial = 0, cPending = 0, cExpired = 0, cDeleted = 0;

    for (final s in _students) {
      final isDeleted = s['is_deleted'] == true;
      final isExpired =
          !isDeleted && (s['end_date']?.toString() ?? '').compareTo(today) < 0;
      if (isDeleted) {
        cDeleted++;
      } else if (isExpired) {
        cExpired++;
      } else {
        switch (s['payment_status']?.toString()) {
          case 'paid':
            cPaid++;
            break;
          case 'partial':
            cPartial++;
            break;
          case 'pending':
            cPending++;
            break;
        }
      }
    }

    final cnt = {
      'ALL': cAll,
      'PAID': cPaid,
      'PARTIAL': cPartial,
      'PENDING': cPending,
      'EXPIRED': cExpired,
      'DELETED': cDeleted,
    };
    final colors = <String, Color>{
      'ALL': const Color(0xFF6366F1),
      'PAID': const Color(0xFF10B981),
      'PARTIAL': const Color(0xFFF59E0B),
      'PENDING': const Color(0xFFEF4444),
      'EXPIRED': const Color(0xFF94A3B8),
      'DELETED': const Color(0xFFEF4444),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: ['ALL', 'PAID', 'PARTIAL', 'PENDING', 'EXPIRED', 'DELETED']
            .map((f) {
              final active = _m2Filter == f;
              final c = colors[f]!;
              return GestureDetector(
                onTap: () => setState(() => _m2Filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? c.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? c.withOpacity(0.5)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        f,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? c.withOpacity(0.25)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${cnt[f] ?? 0}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: active ? Colors.white : Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(),
      ),
    );
  }

  // ════════════════════════════════════════
  // MODE 2 — BODY
  // ════════════════════════════════════════

  List<Map<String, dynamic>> get _filteredStudents {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _students.where((s) {
      final isDeleted = s['is_deleted'] == true;
      final isExpired =
          !isDeleted && (s['end_date']?.toString() ?? '').compareTo(today) < 0;
      if (_m2Filter == 'ALL') return true;
      if (_m2Filter == 'DELETED') return isDeleted;
      if (isDeleted) return false;
      if (_m2Filter == 'EXPIRED') return isExpired;
      if (isExpired) return false;
      return s['payment_status']?.toString().toUpperCase() == _m2Filter;
    }).toList();
  }

  Widget _buildMode2Body() {
    // Loading state
    if (_isMode2Loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 16),
            Text(
              'Loading student records...',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text(
              'No students in this filter',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _filteredStudents.length,
      itemBuilder: (_, i) => _studentCard(_filteredStudents[i]),
    );
  }

  Widget _studentCard(Map<String, dynamic> s) {
    final id = s['id']?.toString() ?? '';
    final name = s['name']?.toString() ?? '—';
    final today = DateTime.now().toIso8601String().split('T')[0];
    final isDeleted = s['is_deleted'] == true;
    final isExpired =
        !isDeleted && (s['end_date']?.toString() ?? '').compareTo(today) < 0;
    final expanded = _expanded.contains(id);

    final totalFee = (s['total_fee'] as num? ?? 0).toDouble();
    final amtPaid = (s['amount_paid'] as num? ?? 0).toDouble();
    final disc = (s['discount_amount'] as num? ?? 0).toDouble();
    final pending = (totalFee - disc - amtPaid).clamp(0.0, double.infinity);

    final status = isDeleted
        ? 'DELETED'
        : isExpired
        ? 'EXPIRED'
        : (s['payment_status']?.toString().toUpperCase() ?? 'PENDING');

    final sc =
        <String, Color>{
          'PAID': const Color(0xFF10B981),
          'PARTIAL': const Color(0xFFF59E0B),
          'PENDING': const Color(0xFFEF4444),
          'DISCOUNTED': const Color(0xFFA78BFA),
          'EXPIRED': const Color(0xFF94A3B8),
          'DELETED': const Color(0xFFEF4444),
        }[status] ??
        Colors.grey;

    final events = _studentEvents(id, name);

    return Opacity(
      opacity: isDeleted ? 0.75 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDeleted
              ? Colors.red.withOpacity(0.06)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: expanded
                ? sc.withOpacity(0.5)
                : (isDeleted
                      ? Colors.red.withOpacity(0.25)
                      : Colors.white.withOpacity(0.08)),
            width: expanded ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // ── Card header ──
              GestureDetector(
                onTap: () => setState(() {
                  if (expanded)
                    _expanded.remove(id);
                  else
                    _expanded.add(id);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: sc.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sc.withOpacity(0.4)),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: sc,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white38,
                              size: 22,
                            ),
                          ),
                        ],
                      ),

                      // Deleted banner
                      if (isDeleted) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 13,
                                color: Color(0xFFFCA5A5),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s['deleted_at'] != null
                                    ? 'Deleted on ${_shortDate(s['deleted_at'].toString())}'
                                    : 'Student Deleted',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 12,
                        children: [
                          _chip(
                            Icons.airline_seat_recline_normal_outlined,
                            s['combination_key']?.toString() ?? '—',
                            Colors.blue,
                          ),
                          _chip(
                            Icons.schedule_outlined,
                            s['plan_months'] != null
                                ? '${s['plan_months']}mo'
                                : '—',
                            Colors.indigo,
                          ),
                          if (!isDeleted)
                            _chip(
                              Icons.calendar_today_outlined,
                              'Ends ${_shortDate(s['end_date']?.toString() ?? '')}',
                              isExpired
                                  ? const Color(0xFFFCA5A5)
                                  : Colors.white54,
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          _feeBox(
                            'Total Fee',
                            '₹${totalFee.toInt()}',
                            Colors.white60,
                          ),
                          const SizedBox(width: 8),
                          _feeBox(
                            'Paid',
                            '₹${amtPaid.toInt()}',
                            const Color(0xFF34D399),
                          ),
                          const SizedBox(width: 8),
                          _feeBox(
                            'Pending',
                            pending > 0 ? '₹${pending.toInt()}' : '✓ Cleared',
                            pending > 0
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF34D399),
                            bg: pending > 0
                                ? Colors.red.withOpacity(0.08)
                                : const Color(0xFF10B981).withOpacity(0.08),
                            bold: true,
                          ),
                        ],
                      ),

                      if (disc > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA78BFA).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFA78BFA).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '🏷  Discount: ₹${disc.toInt()}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFFC084FC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Expanded transactions ──
              if (expanded) ...[
                Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  color: Colors.white.withOpacity(0.02),
                  child: Row(
                    children: [
                      Text(
                        'Transaction History  •  ${events.length} events',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No transactions found',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 56,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    itemBuilder: (_, i) => _eventRow(events[i]),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: c.withOpacity(0.8)),
      const SizedBox(width: 4),
      Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          color: Colors.white60,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _feeBox(
    String label,
    String val,
    Color c, {
    Color? bg,
    bool bold = false,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg ?? Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              val,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
                color: c,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _eventRow(Map e) {
    final type = e['event_type']?.toString() ?? '';
    final paid = (e['amount'] as num? ?? 0).toDouble();
    final due = (e['pending_amount'] as num? ?? 0).toDouble();
    final plan = _planFromNote(e['note']?.toString());
    final date = _eventDate(e);

    final cfgs = <String, (String, IconData, Color)>{
      'ADMISSION_FULL': (
        'Admission — Fully Paid',
        Icons.person_add_outlined,
        const Color(0xFF34D399),
      ),
      'ADMISSION_PARTIAL': (
        'Admission — Partial Payment',
        Icons.person_add_outlined,
        const Color(0xFFF59E0B),
      ),
      'ADMISSION_PENDING': (
        'Admission — Full Pending',
        Icons.person_add_outlined,
        const Color(0xFFFCA5A5),
      ),
      'PAYMENT_RECEIVED': (
        'Payment Collected',
        Icons.payments_outlined,
        const Color(0xFF34D399),
      ),
      'DISCOUNT_APPLIED': (
        'Discount Applied',
        Icons.discount_outlined,
        const Color(0xFFC084FC),
      ),
      'RENEWAL': (
        'Seat Renewed',
        Icons.autorenew_outlined,
        const Color(0xFF818CF8),
      ),
      'REFUND_ON_DELETE': (
        'Deleted — Refund Given',
        Icons.person_remove_outlined,
        const Color(0xFFF59E0B),
      ),
      'NO_REFUND_ON_DELETE': (
        'Deleted — No Refund',
        Icons.person_remove_outlined,
        const Color(0xFFFCA5A5),
      ),
    };
    final (lbl, ico, clr) =
        cfgs[type] ?? (type, Icons.info_outline, Colors.grey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: clr.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: clr.withOpacity(0.3)),
            ),
            child: Icon(ico, size: 15, color: clr),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lbl,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      _shortDate(date),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: Colors.white38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    if (plan != '—') _tag(plan, const Color(0xFF818CF8)),
                    if (type == 'DISCOUNT_APPLIED')
                      _tag('Disc ₹${paid.toInt()}', const Color(0xFFC084FC)),
                    if (type != 'DISCOUNT_APPLIED' && paid > 0)
                      _tag('Paid ₹${paid.toInt()}', const Color(0xFF34D399)),
                    if (due > 0)
                      _tag('Due ₹${due.toInt()}', const Color(0xFFFCA5A5)),
                    if (due == 0 && paid > 0 && type != 'DISCOUNT_APPLIED')
                      _tag('Cleared ✓', const Color(0xFF34D399)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withOpacity(0.3)),
    ),
    child: Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: c,
      ),
    ),
  );
}
