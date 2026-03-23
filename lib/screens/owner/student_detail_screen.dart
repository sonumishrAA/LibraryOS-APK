import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';
import 'add_student_wizard.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> with SingleTickerProviderStateMixin {
  late Map _student;
  bool _isBusy = false;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _student = Map.from(widget.student);
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              left: math.sin(_bgController.value * 2 * math.pi) * 100 - 50,
              top: math.cos(_bgController.value * 2 * math.pi) * 100 - 50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withOpacity(0.15),
                    boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.2), blurRadius: 100, spreadRadius: 50)]),
              ),
            ),
            Positioned(
              right: math.cos(_bgController.value * 2 * math.pi) * 100 - 50,
              bottom: math.sin(_bgController.value * 2 * math.pi) * 100 - 50,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFEC4899).withOpacity(0.1),
                    boxShadow: [BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.2), blurRadius: 80, spreadRadius: 40)]),
              ),
            ),
          ],
        );
      },
    );
  }

  double _pendingAmount(Map s) {
    final total = (s['total_fee'] ?? 0).toDouble();
    final disc = (s['discount_amount'] ?? 0).toDouble();
    final paid = (s['amount_paid'] ?? 0).toDouble();
    return (total - disc - paid).clamp(0.0, double.infinity);
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.parse(date.toString());
    return DateFormat('dd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingAmount(_student);
    final today = DateTime.now().toIso8601String().split('T')[0];
    final isExpired = (_student['end_date'] as String).compareTo(today) < 0;
    final status = isExpired ? 'expired' : (_student['payment_status']?.toString().toLowerCase() ?? 'pending');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_student['name'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusColor(status).withOpacity(0.5)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
          SafeArea(
            child: _isBusy 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Section 1: Basic Info
                      _sectionCard('STUDENT INFO', [
                        _infoRow(Icons.chair_outlined, 'Seat', _student['seats']?['seat_number'] ?? '—'),
                        _infoRow(Icons.schedule, 'Shifts', (_student['selected_shifts'] as List?)?.join(' + ') ?? '—'),
                        _infoRow(Icons.person_outline, 'Gender', _student['gender']?.toString().toUpperCase() ?? '—'),
                        _infoRow(Icons.phone_outlined, 'Phone', _student['phone'] ?? '—'),
                        _infoRow(Icons.person_outlined, 'Father', _student['father_name'] ?? '—'),
                        _infoRow(Icons.location_on_outlined, 'Address', _student['address'] ?? '—'),
                      ]),

                      const SizedBox(height: 12),

                      // Section 2: Plan Info
                      _sectionCard('PLAN DETAILS', [
                        _infoRow(Icons.calendar_today_outlined, 'Admission', _formatDate(_student['admission_date'])),
                        _infoRow(Icons.event_outlined, 'Ends', _formatDate(_student['end_date'])),
                        _infoRow(Icons.access_time_outlined, 'Plan', '${_student['plan_months']} Month${_student['plan_months'] > 1 ? "s" : ""}'),
                      ]),

                      const SizedBox(height: 12),

                      // Section 3: Payment Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('PAYMENT SUMMARY', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                if ((_student['discount_amount'] ?? 0) > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFEC4899).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                    child: Text('DISC ₹${(_student["discount_amount"] as num).toInt()}', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF472B6), fontSize: 10, fontWeight: FontWeight.w800)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _payRow('Total Fee', (_student['total_fee'] ?? 0).toDouble(), Colors.white),
                            if ((_student['discount_amount'] ?? 0) > 0)
                              _payRow('Discount', -(_student['discount_amount'] as num).toDouble(), const Color(0xFF34D399)),
                            const Divider(color: Colors.white12, height: 24),
                            _payRow('Amount Paid', (_student['amount_paid'] ?? 0).toDouble(), const Color(0xFF34D399), bold: true),
                            _payRow('Pending Due', pending, const Color(0xFFFCA5A5), bold: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Buttons
                      if (isExpired)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('RENEW ADMISSION'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 8,
                              shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddStudentWizard(renewStudent: _student)),
                            ).then((_) => Navigator.pop(context)),
                          ),
                        )
                      else if (pending > 0)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.payments_outlined),
                            label: Text('COLLECT PAYMENT  •  ₹${pending.toInt()} due'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 8,
                              shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                            ),
                            onPressed: () => _showCollectPaymentSheet(),
                          ),
                        ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFFCA5A5)),
                          label: const Text('DELETE STUDENT', style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.redAccent.withOpacity(0.05),
                          ),
                          onPressed: () => _confirmDelete(),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _showCollectPaymentSheet() {
    double newPayment = 0;
    String paymentMode = 'cash';
    final pending = _pendingAmount(_student);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Text('Collect Payment', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Pending Amount: ₹${pending.toInt()}', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFCA5A5), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Amount Receiving (₹)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onChanged: (v) => newPayment = double.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: ['cash', 'upi', 'online', 'other'].map((m) {
                      bool isSelected = paymentMode == m;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => paymentMode = m),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF6366F1).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? const Color(0xFF818CF8) : Colors.transparent),
                            ),
                            child: Text(m.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: isSelected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (newPayment <= 0 || newPayment > pending) return;
                        Navigator.pop(ctx);
                        _collectPayment(newPayment, paymentMode);
                      },
                      child: const Text('CONFIRM PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _collectPayment(double newPayment, String mode) async {
    setState(() => _isBusy = true);
    try {
      final updatedPaid = (_student['amount_paid'] as num) + newPayment;
      final totalFee = (_student['total_fee'] as num).toDouble();
      final disc = (_student['discount_amount'] as num).toDouble();
      final newPending = (totalFee - disc - updatedPaid).clamp(0.0, double.infinity);
      final newStatus = newPending == 0 ? 'paid' : 'partial';

      // 1. UPDATE student
      final studentUpdateRes = await supabase.from('students').update({
        'amount_paid': updatedPaid,
        'payment_status': newStatus,
      }).eq('id', _student['id']).select().single();

      await CacheService.onStudentUpdated(studentUpdateRes);

      // 2. INSERT payment_record
      final paymentRes = await supabase.from('payment_records').insert({
        'library_id': currentLibraryId,
        'student_id': _student['id'],
        'amount': newPayment,
        'payment_method': mode,
        'type': 'admission',
        'received_by': supabase.auth.currentUser!.id,
      }).select().single();

      await CacheService.onPaymentRecordAdded(paymentRes);

      // 3. INSERT financial_event
      final eventRes = await supabase.from('financial_events').insert({
        'library_id': currentLibraryId,
        'student_id': _student['id'],
        'student_name': _student['name'],
        'event_type': 'PAYMENT_RECEIVED',
        'amount': newPayment,
        'pending_amount': newPending,
        'payment_mode': mode,
        'actor_role': currentRole,
        'actor_name': currentUserName,
        'note': 'Collected ₹${newPayment.toInt()}. Total paid: ₹${updatedPaid.toInt()}. ${newPending > 0 ? "₹${newPending.toInt()} still due" : "Account cleared"}',
      }).select().single();

      await CacheService.onFinancialEventAdded(eventRes);

      // 4. INSERT notification
      final notifRes = await supabase.from('notifications').insert({
        'library_id': currentLibraryId,
        'student_id': _student['id'],
        'type': 'fee_collected',
        'title': 'Fee Collected — ${_student["name"]}',
        'message': '₹${newPayment.toInt()} received. ${newPending > 0 ? "₹${newPending.toInt()} pending." : "Account cleared ✓"}',
        'is_read': false,
      }).select().single();

      await CacheService.onNotificationAdded(notifRes);

      setState(() {
        _student['amount_paid'] = updatedPaid;
        _student['payment_status'] = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('₹${newPayment.toInt()} collected successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Payment collection error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _confirmDelete() {
    bool giveRefund = false;
    double refundAmount = 0;
    final amountPaid = (_student['amount_paid'] as num).toDouble();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: AlertDialog(
              backgroundColor: const Color(0xFF0F172A).withOpacity(0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: Text('Delete ${_student["name"]}?', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Amount Paid', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13)),
                        Text('₹${amountPaid.toInt()}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Theme(
                    data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white54),
                    child: CheckboxListTile(
                      title: Text('Give Refund', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                      value: giveRefund,
                      activeColor: const Color(0xFF6366F1),
                      checkColor: Colors.white,
                      onChanged: amountPaid > 0
                          ? (v) => setDialogState(() {
                                giveRefund = v!;
                                if (!v) {
                                  refundAmount = 0;
                                } else {
                                  refundAmount = amountPaid;
                                }
                              })
                          : null,
                      subtitle: amountPaid == 0
                          ? Text('No payment received', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white38))
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  if (giveRefund) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: amountPaid.toInt().toString(),
                      decoration: InputDecoration(
                        labelText: 'Refund Amount (₹)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(color: Colors.white),
                        helperText: 'Max allowable: ₹${amountPaid.toInt()}',
                        helperStyle: const TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        isDense: true,
                      ),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final parsed = double.tryParse(v) ?? 0;
                        setDialogState(() {
                          refundAmount = parsed.clamp(0, amountPaid);
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('CANCEL', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    foregroundColor: const Color(0xFFFCA5A5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteStudent(giveRefund, refundAmount);
                  },
                  child: Text('DELETE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStudent(bool giveRefund, double refundAmount) async {
    setState(() => _isBusy = true);
    try {
      final pending = _pendingAmount(_student);

      // 1. Soft delete student
      await supabase.from('students').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', _student['id']);

      await CacheService.onStudentDeleted(_student['id']);

      // 2. DELETE seat shifts — seat free ho jaye
      await supabase.from('student_seat_shifts').delete().eq('student_id', _student['id']);

      // 3. FREE locker if assigned
      if (_student['locker_id'] != null) {
        await supabase.from('lockers').update({'status': 'free'}).eq('id', _student['locker_id']);
        await CacheService.onLockerUpdated(_student['locker_id'], 'free');
      }

      // 4. INSERT financial_event
      final eventRes = await supabase.from('financial_events').insert({
        'library_id': currentLibraryId,
        'student_id': _student['id'],
        'student_name': _student['name'],
        'event_type': giveRefund && refundAmount > 0 ? 'REFUND_ON_DELETE' : 'NO_REFUND_ON_DELETE',
        'amount': giveRefund ? refundAmount : 0,
        'pending_amount': pending,
        'payment_mode': 'cash',
        'actor_role': currentRole,
        'actor_name': currentUserName,
        'note': giveRefund && refundAmount > 0
            ? 'Student deleted. Refund ₹${refundAmount.toInt()} given.'
            : pending > 0
                ? 'Student deleted. ₹${pending.toInt()} pending waived. No refund.'
                : 'Student deleted. Account was cleared. No refund.',
      }).select().single();

      await CacheService.onFinancialEventAdded(eventRes);

      // 5. INSERT notification
      final notifRes = await supabase.from('notifications').insert({
        'library_id': currentLibraryId,
        'student_id': _student['id'],
        'type': 'new_admission',
        'title': 'Student Deleted — ${_student["name"]}',
        'message': giveRefund && refundAmount > 0 ? '${_student["name"]} removed. Refund ₹${refundAmount.toInt()} issued.' : '${_student["name"]} removed. No refund.',
        'is_read': false,
      }).select().single();

      await CacheService.onNotificationAdded(notifRes);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_student["name"]} deleted' '${giveRefund && refundAmount > 0 ? " • Refund ₹${refundAmount.toInt()}" : ""}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Student deletion error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _sectionCard(String title, List<Widget> rows) => Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04), 
      borderRadius: BorderRadius.circular(10), 
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1)),
        const SizedBox(height: 16),
        ...rows,
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.white38),
        const SizedBox(width: 12),
        Text('$label: ', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white60)),
        Expanded(child: Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
      ],
    ),
  );

  Widget _payRow(String label, double amount, Color color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13)),
        Text(
          '${amount < 0 ? "-" : ""}₹${amount.abs().toInt()}',
          style: GoogleFonts.plusJakartaSans(color: color, fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
        ),
      ],
    ),
  );

  Color _statusColor(String status) => switch (status) {
    'paid' => const Color(0xFF34D399),
    'partial' => const Color(0xFFFBBF24),
    'pending' => const Color(0xFFF87171),
    'discounted' => const Color(0xFFA78BFA),
    'expired' => const Color(0xFF94A3B8),
    _ => Colors.white54,
  };
}
