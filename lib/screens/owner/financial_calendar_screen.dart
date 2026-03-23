import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';

class FinancialCalendarScreen extends StatefulWidget {
  const FinancialCalendarScreen({super.key});

  @override
  State<FinancialCalendarScreen> createState() =>
      _FinancialCalendarScreenState();
}

class _FinancialCalendarScreenState extends State<FinancialCalendarScreen> {
  int _mode = 1; // 1 = Timeline Table, 2 = Student Story

  // ── Mode 1 state ──
  DateTime _month = DateTime.now();
  List<Map<String, dynamic>> _m1Events = [];
  double _m1Total = 0, _m1Pending = 0, _m1Discount = 0, _m1Refund = 0;
  bool _isLoading = true;

  // ── Mode 2 state ──
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allEvents = [];
  final Set<String> _expanded = {};
  String _m2Filter = 'ALL';

  // ── scroll controllers ──
  // _headerScroll  → horizontal header (driven by body)
  // _bodyHScroll   → horizontal body scroll (drives header)
  // _bodyScroll    → vertical ListView inside body
  final ScrollController _headerScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  final ScrollController _bodyScroll = ScrollController();

  // Column widths (mode 1)
  static const double _cName = 120;
  static const double _cType = 38;
  static const double _cOrig = 78;
  static const double _cDisc = 68;
  static const double _cEff = 78;
  static const double _cPlan = 62;
  static const double _cPaid = 72;
  static const double _cDue = 80;
  static const double _cPad = 14;

  // total table width helper
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

  @override
  void initState() {
    super.initState();
    // keep header in sync with body horizontal scroll
    _bodyHScroll.addListener(() {
      if (_headerScroll.hasClients) {
        _headerScroll.jumpTo(_bodyHScroll.offset);
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyHScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  void _loadAll() {
    _loadMode1();
    _loadMode2();
  }

  // ════════════════════════════════════════════════════
  // DATA — MODE 1
  // ════════════════════════════════════════════════════
  void _loadMode1() {
    setState(() => _isLoading = true);

    final first = DateTime(
      _month.year,
      _month.month,
      1,
    ).toIso8601String().split('T')[0];
    final last = DateTime(
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
      if (adm.compareTo(first) >= 0 && adm.compareTo(last) <= 0) {
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

  // ════════════════════════════════════════════════════
  // DATA — MODE 2
  // ════════════════════════════════════════════════════
  void _loadMode2() {
    // Deleted students bhi dikhane hain — record hona chahiye
    final students = CacheService.read('students').toList()
      ..sort(
        (a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
      );
    setState(() {
      _students = students;
      _allEvents = CacheService.read('financial_events');
    });
  }

  // ════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════
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
        if (id != null && e['student_id'] != null) return e['student_id'] == id;
        return e['student_name'] == name;
      }).toList()..sort((a, b) => _eventDate(a).compareTo(_eventDate(b)));

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Financial Calendar',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildModeToggle(),
          if (_mode == 1) ...[
            _buildMonthNav(),
            _buildSummaryRow(),
            // header + body are now both inside _buildMode1Body
            Expanded(child: _buildMode1Body()),
          ] else ...[
            _buildMode2Filters(),
            Expanded(child: _buildMode2Body()),
          ],
        ],
      ),
    );
  }

  // ── MODE TOGGLE ──
  Widget _buildModeToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _modeBtn(1, 'Timeline Table', Icons.table_rows_outlined),
          _modeBtn(2, 'Student Story', Icons.person_pin_outlined),
        ],
      ),
    );
  }

  Widget _modeBtn(int mode, String label, IconData icon) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active
                ? [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? primaryColor : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // MODE 1 — TIMELINE TABLE
  // ════════════════════════════════════════════════════

  Widget _buildMonthNav() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            setState(() => _month = DateTime(_month.year, _month.month - 1));
            _loadMode1();
          },
          icon: const Icon(Icons.chevron_left_rounded, color: primaryColor),
        ),
        SizedBox(
          width: 130,
          child: Text(
            '${_mon(_month.month)} ${_month.year}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: primaryColor,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() => _month = DateTime(_month.year, _month.month + 1));
            _loadMode1();
          },
          icon: const Icon(Icons.chevron_right_rounded, color: primaryColor),
        ),
      ],
    ),
  );

  Widget _buildSummaryRow() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Row(
      children: [
        _sBox('Collected', _m1Total, Colors.green),
        const SizedBox(width: 6),
        _sBox('Pending', _m1Pending, Colors.red),
        const SizedBox(width: 6),
        _sBox('Discount', _m1Discount, Colors.purple),
        const SizedBox(width: 6),
        _sBox('Refund', _m1Refund, Colors.orange),
      ],
    ),
  );

  Widget _sBox(String label, double val, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
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

  // ── TABLE HEADER ROW ──
  Widget _hdrRow() {
    ts(String t) => Text(
      t,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  // ── MODE 1 BODY — embeds sticky header + scrollable rows ──
  Widget _buildMode1Body() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }
    if (_m1Events.isEmpty) {
      return Center(
        child: Text(
          'No activity in ${_mon(_month.month)} ${_month.year}',
          style: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 13),
        ),
      );
    }

    // Group by logical date (skip standalone DISCOUNT_APPLIED rows)
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in _m1Events) {
      if (e['event_type'] == 'DISCOUNT_APPLIED') continue;
      (grouped[_eventDate(e)] ??= []).add(e);
    }

    return Column(
      children: [
        // ── Sticky header — driven by _bodyHScroll ──
        SingleChildScrollView(
          controller: _headerScroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(width: _tableWidth, child: _hdrRow()),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // ── Scrollable body — horizontal + vertical ──
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
                        // date section header
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.fromLTRB(14, 7, 14, 5),
                          child: Text(
                            _shortDate(entry.key).toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...entry.value.map((e) => _m1Row(e)),
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

  // ── SINGLE TABLE ROW ──
  Widget _m1Row(Map e) {
    final type = e['event_type']?.toString() ?? '';
    if (type == 'DISCOUNT_APPLIED') return const SizedBox.shrink();

    final note = e['note']?.toString();
    final paid = (e['amount'] as num? ?? 0).toDouble();
    final due = (e['pending_amount'] as num? ?? 0).toDouble();
    final orig = _origFromNote(note);
    final disc = _discFromNote(note);
    final eff = (orig - disc).clamp(0.0, double.infinity);
    final displayOrig = orig > 0 ? orig : (paid + due + disc);
    final displayEff = orig > 0 ? eff : (paid + due);
    final plan = _planFromNote(note);
    final name = e['student_name']?.toString() ?? '—';

    final (typeLabel, typeColor) = _typeConfig(type);
    final dotColor = _dotColor(type);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(width: _cPad),

            // NAME
            SizedBox(
              width: _cName,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
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
                        color: const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // TYPE chip
            SizedBox(
              width: _cType,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    typeLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: typeColor,
                    ),
                  ),
                ),
              ),
            ),

            // ORIGINAL
            SizedBox(
              width: _cOrig,
              child: Text(
                '₹${displayOrig.toInt()}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // DISCOUNT
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
                            color: Colors.purple.shade700,
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
                            color: Colors.purple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DISC',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              color: Colors.purple.shade400,
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
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
            ),

            // EFFECTIVE
            SizedBox(
              width: _cEff,
              child: Text(
                '₹${displayEff.toInt()}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: disc > 0
                      ? Colors.purple.shade700
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // PLAN
            SizedBox(
              width: _cPlan,
              child: Text(
                plan,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // PAID
            SizedBox(
              width: _cPaid,
              child: Text(
                '₹${paid.toInt()}',
                textAlign: TextAlign.right,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // DUE / STATUS
            SizedBox(
              width: _cDue,
              child: due > 0
                  ? Text(
                      '₹${due.toInt()}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.red.shade600,
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
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          '✓ Clear',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: Colors.green.shade700,
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

  (String label, Color color) _typeConfig(String type) => switch (type) {
    'ADMISSION_FULL' => ('ADM', Colors.blue),
    'ADMISSION_PARTIAL' => ('ADM', Colors.orange),
    'ADMISSION_PENDING' => ('ADM', Colors.red),
    'PAYMENT_RECEIVED' => ('PMT', Colors.teal),
    'RENEWAL' => ('RNW', Colors.indigo),
    'REFUND_ON_DELETE' => ('DEL↩', Colors.orange),
    'NO_REFUND_ON_DELETE' => ('DEL', Colors.red.shade300),
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
    'NO_REFUND_ON_DELETE' => Colors.red.shade300,
    _ => Colors.grey,
  };

  // ════════════════════════════════════════════════════
  // MODE 2 — STUDENT STORY
  // ════════════════════════════════════════════════════

  Widget _buildMode2Filters() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final cnt = <String, int>{
      'ALL': _students.length,
      'PAID': _students
          .where(
            (s) =>
                s['is_deleted'] != true &&
                s['payment_status'] == 'paid' &&
                (s['end_date']?.toString() ?? '').compareTo(today) >= 0,
          )
          .length,
      'PARTIAL': _students
          .where(
            (s) =>
                s['is_deleted'] != true &&
                s['payment_status'] == 'partial' &&
                (s['end_date']?.toString() ?? '').compareTo(today) >= 0,
          )
          .length,
      'PENDING': _students
          .where(
            (s) =>
                s['is_deleted'] != true &&
                s['payment_status'] == 'pending' &&
                (s['end_date']?.toString() ?? '').compareTo(today) >= 0,
          )
          .length,
      'EXPIRED': _students
          .where(
            (s) =>
                s['is_deleted'] != true &&
                (s['end_date']?.toString() ?? '').compareTo(today) < 0,
          )
          .length,
      'DELETED': _students.where((s) => s['is_deleted'] == true).length,
    };

    final colors = <String, Color>{
      'ALL': primaryColor,
      'PAID': Colors.green,
      'PARTIAL': Colors.orange,
      'PENDING': Colors.red,
      'EXPIRED': Colors.grey,
      'DELETED': const Color(0xFF991B1B),
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
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? c.withOpacity(0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? c.withOpacity(0.4) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        f,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? c : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: active ? c.withOpacity(0.2) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${cnt[f] ?? 0}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: active ? c : Colors.grey,
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

  List<Map<String, dynamic>> get _filteredStudents {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _students.where((s) {
      final isDeleted = s['is_deleted'] == true;
      final expired =
          !isDeleted && (s['end_date']?.toString() ?? '').compareTo(today) < 0;
      if (_m2Filter == 'ALL') return true;
      if (_m2Filter == 'DELETED') return isDeleted;
      if (isDeleted)
        return false; // deleted wale sirf DELETED filter mein dikhein
      if (_m2Filter == 'EXPIRED') return expired;
      if (expired) return false;
      return s['payment_status']?.toString().toUpperCase() == _m2Filter;
    }).toList();
  }

  Widget _buildMode2Body() {
    if (_filteredStudents.isEmpty) {
      return Center(
        child: Text(
          'No students',
          style: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 13),
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

    final statusColors = <String, Color>{
      'PAID': Colors.green,
      'PARTIAL': Colors.orange,
      'PENDING': Colors.red,
      'DISCOUNTED': Colors.purple,
      'EXPIRED': Colors.grey,
      'DELETED': const Color(0xFF991B1B),
    };
    final sc = statusColors[status] ?? Colors.grey;

    final events = _studentEvents(id.isEmpty ? null : id, name);

    return Opacity(
      opacity: isDeleted ? 0.72 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDeleted ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDeleted
                ? const Color(0xFFFFCDD2)
                : expanded
                ? sc.withOpacity(0.4)
                : const Color(0xFFE2E8F0),
            width: expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                if (expanded)
                  _expanded.remove(id);
                else
                  _expanded.add(id);
              }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.04),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(13),
                    topRight: const Radius.circular(13),
                    bottomLeft: Radius.circular(expanded ? 0 : 13),
                    bottomRight: Radius.circular(expanded ? 0 : 13),
                  ),
                ),
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
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: sc.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sc.withOpacity(0.35)),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
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
                            color: Colors.grey.shade400,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isDeleted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDA4AF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 13,
                              color: Color(0xFF991B1B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s['deleted_at'] != null
                                  ? 'Deleted on ${_shortDate(s['deleted_at'].toString())}'
                                  : 'Student Deleted',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 10,
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
                        _chip(
                          Icons.calendar_today_outlined,
                          'Ends ${_shortDate(s['end_date']?.toString() ?? '')}',
                          isExpired ? Colors.red : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _feeBox(
                          'Total Fee',
                          '₹${totalFee.toInt()}',
                          const Color(0xFF475569),
                        ),
                        const SizedBox(width: 8),
                        _feeBox(
                          'Paid',
                          '₹${amtPaid.toInt()}',
                          Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        _feeBox(
                          'Pending',
                          pending > 0 ? '₹${pending.toInt()}' : '✓ Cleared',
                          pending > 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          bg: pending > 0
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          bold: true,
                        ),
                      ],
                    ),
                    if (disc > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.shade100),
                        ),
                        child: Text(
                          '🏷  Discount Applied: ₹${disc.toInt()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Container(height: 1, color: const Color(0xFFE2E8F0)),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Text(
                      'Transaction History  •  ${events.length} events',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
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
                      color: textMuted,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Color(0xFFF1F5F9),
                    indent: 56,
                  ),
                  itemBuilder: (_, i) =>
                      _eventRow(events[i], isLast: i == events.length - 1),
                ),
            ],
          ],
        ),
      ), // end Opacity
    );
  }

  Widget _chip(IconData icon, String text, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: c.withOpacity(0.7)),
      const SizedBox(width: 4),
      Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          color: Colors.grey.shade600,
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
        color: bg ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
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

  Widget _eventRow(Map e, {bool isLast = false}) {
    final type = e['event_type']?.toString() ?? '';
    final paid = (e['amount'] as num? ?? 0).toDouble();
    final due = (e['pending_amount'] as num? ?? 0).toDouble();
    final note = e['note']?.toString() ?? '';
    final plan = _planFromNote(note);
    final date = _eventDate(e);

    final configs = <String, (String, IconData, Color)>{
      'ADMISSION_FULL': (
        'Admission — Fully Paid',
        Icons.person_add_outlined,
        Colors.green,
      ),
      'ADMISSION_PARTIAL': (
        'Admission — Partial Payment',
        Icons.person_add_outlined,
        Colors.orange,
      ),
      'ADMISSION_PENDING': (
        'Admission — Full Pending',
        Icons.person_add_outlined,
        Colors.red,
      ),
      'PAYMENT_RECEIVED': (
        'Payment Collected',
        Icons.payments_outlined,
        Colors.teal,
      ),
      'DISCOUNT_APPLIED': (
        'Discount Applied',
        Icons.discount_outlined,
        Colors.purple,
      ),
      'RENEWAL': ('Seat Renewed', Icons.autorenew_outlined, Colors.indigo),
      'REFUND_ON_DELETE': (
        'Student Deleted — Refund Given',
        Icons.person_remove_outlined,
        Colors.orange,
      ),
      'NO_REFUND_ON_DELETE': (
        'Student Deleted — No Refund',
        Icons.person_remove_outlined,
        Colors.red.shade400,
      ),
    };
    final (label, icon, color) =
        configs[type] ?? (type, Icons.info_outline, Colors.grey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 15, color: color),
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
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Text(
                      _shortDate(date),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: Colors.grey.shade400,
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
                    if (plan != '—') _tag(plan, Colors.blue),
                    if (type == 'DISCOUNT_APPLIED')
                      _tag('Disc ₹${paid.toInt()}', Colors.purple),
                    if (type != 'DISCOUNT_APPLIED' && paid > 0)
                      _tag('Paid ₹${paid.toInt()}', Colors.green.shade700),
                    if (due > 0)
                      _tag('Due ₹${due.toInt()}', Colors.red.shade600),
                    if (due == 0 && paid > 0 && type != 'DISCOUNT_APPLIED')
                      _tag('Account Cleared ✓', Colors.green.shade700),
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
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withOpacity(0.25)),
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
