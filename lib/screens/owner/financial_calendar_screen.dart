import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';

class FinancialCalendarScreen extends StatefulWidget {
  const FinancialCalendarScreen({super.key});

  @override
  State<FinancialCalendarScreen> createState() => _FinancialCalendarScreenState();
}

class _FinancialCalendarScreenState extends State<FinancialCalendarScreen> {
  DateTime _month = DateTime.now();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('=== CALENDAR DEBUG ===');
    debugPrint('Library ID: $currentLibraryId');
    debugPrint('Expected:   d7802794-cc48-4ceb-ad6e-f7a57dfe934f');
    debugPrint('Initializing FinancialCalendarScreen for library ID: $currentLibraryId');
    _fetchEvents(_month);
  }

  double _pending = 0, _discount = 0, _refund = 0, _total = 0;

  void _fetchEvents(DateTime month) {
    setState(() => _isLoading = true);
    final first = DateTime(month.year, month.month, 1).toIso8601String().split('T')[0];
    final last = DateTime(month.year, month.month + 1, 0).toIso8601String().split('T')[0];

    final students = CacheService.read('students').where((s) => 
      s['admission_date'].compareTo(first) >= 0 && 
      s['admission_date'].compareTo(last) <= 0
    ).toList();

    final allEvents = CacheService.read('financial_events');

    final filteredEvents = allEvents.where((e) {
      final dateStr = _getEventDate(e);
      final d = DateTime.parse(dateStr);
      return d.year == month.year && d.month == month.month;
    }).toList();

    double collected = 0;
    double pending = 0;
    double discount = 0;
    double refund = 0;

    for (var s in students) {
      if (s['is_deleted'] != true) {
        final paid = (s['amount_paid'] as num).toDouble();
        final totalFee = (s['total_fee'] as num).toDouble();
        final disc = (s['discount_amount'] as num).toDouble();
        pending += (totalFee - disc - paid).clamp(0.0, double.infinity);
      }
    }
    
    for (var e in filteredEvents) {
      final amt = (e['amount'] as num).toDouble();
      if (e['event_type'] == 'REFUND_ON_DELETE') {
        refund += amt;
      } else if (e['event_type'] == 'DISCOUNT_APPLIED') {
        discount += amt;
      } else {
        collected += amt;
      }
    }

    setState(() {
      _events = filteredEvents;
      _pending = pending;
      _discount = discount;
      _refund = refund;
      _total = collected - refund;
      _isLoading = false;
    });
  }

  // Helper Extraction
  String _getEventDate(Map e) {
    final note = e['note']?.toString() ?? '';
    final match = RegExp(r'admission_date:(\d{4}-\d{2}-\d{2})').firstMatch(note);
    if (match != null) return match.group(1)!;
    return DateTime.parse(e['created_at']).toLocal().toIso8601String().split('T')[0];
  }

  Map<String, List<Map<String, dynamic>>> get _groupedEvents {
    final map = <String, List<Map<String, dynamic>>>{};
    final sortedEvents = List<Map<String, dynamic>>.from(_events);
    sortedEvents.sort((a, b) => _getEventDate(b).compareTo(_getEventDate(a)));

    for (final e in sortedEvents) {
      final dateStr = _getEventDate(e);
      final d = DateTime.parse(dateStr);
      final key = '${d.day} ${_mon(d.month)}';
      (map[key] ??= []).add(e);
    }
    return map;
  }

  String _extractPlan(String? note) {
    if (note == null) return '—';
    final match = RegExp(r'([MAEN]+-\d+m)').firstMatch(note);
    return match?.group(1) ?? '—';
  }

  double _extractOriginal(String? note) {
    if (note == null) return 0;
    final match = RegExp(r'orig:(\d+)').firstMatch(note);
    return double.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  double _extractDiscount(String? note) {
    if (note == null) return 0;
    final match = RegExp(r'disc:(\d+)').firstMatch(note);
    return double.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _fetchEvents(_month);
  }

  String _mon(int m) => switch (m) {
        1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr', 5 => 'May', 6 => 'Jun',
        7 => 'Jul', 8 => 'Aug', 9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec',
        _ => ''
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Financial Calendar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded, color: primaryColor), onPressed: () => _changeMonth(-1)),
                SizedBox(
                  width: 140,
                  child: Text(
                    '${_mon(_month.month)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16, color: primaryColor),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right_rounded, color: primaryColor), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),

          // 2x2 Summary Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    _summaryBox('Total', _total, Colors.green),
                    const SizedBox(width: 8),
                    _summaryBox('Pending', _pending, Colors.red),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _summaryBox('Discount', _discount, Colors.purple),
                    const SizedBox(width: 8),
                    _summaryBox('Refund', _refund, Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _buildTableHeader(),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : _events.isEmpty
                    ? Center(child: Text('No activity this month', style: GoogleFonts.plusJakartaSans(color: textMuted)))
                    : ListView(
                        children: _groupedEvents.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: const Color(0xFFF8FAFC),
                                width: double.infinity,
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ...entry.value.map((event) => _eventRow(event)),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, double value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          FittedBox(child: Text('₹${value.toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: color))),
        ],
      ),
    ),
  );

  Widget _buildTableHeader() {
    final style = GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          SizedBox(width: 45, child: Text('Date', style: style)),
          Expanded(child: Text('Name', style: style)),
          SizedBox(width: 20, child: Text('Ty', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 85, child: Text('Orig/Eff', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 50, child: Text('Plan', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 75, child: Text('Paid/Due', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _eventRow(Map e) {
    if (e['event_type'] == 'DISCOUNT_APPLIED') return const SizedBox.shrink();

    // Date from extraction (not needed anymore in row since it's in header)
    // but we can keep it for row-level detail if needed.
    // However, the header now shows the date.

    final isRefund = e['event_type'] == 'REFUND_ON_DELETE';
    final typeSymbol = isRefund ? 'D' : 'A';
    final typeColor = isRefund ? Colors.orange : Colors.blue;

    // Data Extraction
    final note = e['note']?.toString();
    final original = _extractOriginal(note);
    final discValue = _extractDiscount(note);
    final effective = original - discValue;

    final plan = _extractPlan(note);

    final paid = (e['amount'] as num).toDouble();
    final due = (e['pending_amount'] as num).toDouble();

    // Formatting Strings
    final origEff = (original == effective || original == 0)
        ? '₹${(original == 0 ? (paid + due + discValue) : original).toInt()}'
        : '₹${original.toInt()}/₹${effective.toInt()}';

    final paidDue = due > 0
        ? '₹${paid.toInt()}/₹${due.toInt()}'
        : '₹${paid.toInt()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          // Name with dot
          Expanded(
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: _dotColor(e['event_type']), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    e['student_name'] ?? 'Unknown',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Type
          SizedBox(width: 20, child: Text(typeSymbol, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: typeColor), textAlign: TextAlign.center)),

          // Orig/Eff
          SizedBox(width: 85, child: Text(origEff, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF475569), fontWeight: FontWeight.w600), textAlign: TextAlign.center)),

          // Plan
          SizedBox(width: 50, child: Text(plan, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF475569), fontWeight: FontWeight.w600), textAlign: TextAlign.center)),

          // Paid/Due
          SizedBox(width: 75, child: Text(paidDue, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: due > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.w800), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Color _dotColor(String type) => switch (type) {
        'ADMISSION_FULL' => Colors.green,
        'PAYMENT_RECEIVED' => Colors.green,
        'RENEWAL' => Colors.teal,
        'ADMISSION_PARTIAL' => Colors.blue,
        'ADMISSION_PENDING' => Colors.red,
        'DISCOUNT_APPLIED' => Colors.purple,
        'REFUND_ON_DELETE' => Colors.orange,
        _ => Colors.grey,
      };
}
