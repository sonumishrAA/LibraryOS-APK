import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants.dart';
import '../../globals.dart';
import 'package:intl/intl.dart';
import '../../services/cache_service.dart';

class StudentDetailSheet extends StatefulWidget {
  final dynamic student;
  final VoidCallback onUpdate;
  const StudentDetailSheet({required this.student, required this.onUpdate});

  @override
  State<StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<StudentDetailSheet> {
  bool _isLoading = true;
  List<dynamic> _payments = [];
  List<dynamic> _shifts = [];

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final results = await Future.wait([
        supabase.from('financial_events').select('*').eq('student_id', widget.student['id']).order('created_at', ascending: false),
        supabase.from('student_seat_shifts').select('shifts(*)').eq('student_id', widget.student['id']),
      ]);
      _payments = results[0] as List;
      _shifts = results[1] as List;
    } catch (e) {
      debugPrint('Error fetching student details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final isExpired = DateTime.parse(s['end_date']).isBefore(DateTime.now());

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          _buildDragHandle(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(s, isExpired),
                  const SizedBox(height: 32),
                  _buildInfoGrid(s),
                  const SizedBox(height: 32),
                  _buildShiftsSection(),
                  const SizedBox(height: 32),
                  _buildPaymentHistory(),
                  const SizedBox(height: 48),
                  _buildActionButtons(s),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
    );
  }

  Widget _buildProfileHeader(dynamic s, bool isExpired) {
    return Row(
      children: [
        CircleAvatar(radius: 32, backgroundColor: primaryColor.withOpacity(0.1), child: Text(s['name'][0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor))),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s['name'], style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(s['phone'] ?? 'No Phone', style: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (isExpired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                  child: Text('MEMBERSHIP EXPIRED', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444))),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(dynamic s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _infoCard('SEAT NO.', s['seats']?['seat_number'] ?? 'N/A', Icons.airline_seat_recline_normal),
        _infoCard('LOCKER', s['locker_id'] != null ? 'ASSIGNED' : 'NONE', Icons.lock_outline),
        _infoCard('EXPIRY DATE', DateFormat('dd MMM yyyy').format(DateTime.parse(s['end_date'])), Icons.calendar_today),
        _infoCard('PENDING FEE', '₹ ${s['total_fee'] - s['paid_amount']}', Icons.payments_outlined),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w800, color: textMuted)),
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACTIVE SHIFTS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _shifts.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF1E2D6B).withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E2D6B).withOpacity(0.1))),
            child: Text(s['shifts']['name'], style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E2D6B))),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAYMENT HISTORY', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        if (_isLoading) const Center(child: CircularProgressIndicator())
        else if (_payments.isEmpty) Text('No payment records found', style: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 13))
        else ..._payments.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['category'] ?? 'Payment', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(p['created_at'])), style: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 11)),
                ],
              ),
              Text('₹ ${p['amount']}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF16A34A))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildActionButtons(dynamic s) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.history, size: 18),
            label: const Text('RENEW MEMBERSHIP'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2D6B), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('EDIT INFO'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _deleteStudent(s),
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                label: const Text('DELETE', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Colors.red)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _deleteStudent(dynamic s) async {
    bool giveRefund = false;
    double refundAmount = 0;
    final amountPaid = (s['amount_paid'] as num? ?? 0).toDouble();
    final totalFee = (s['total_fee'] as num? ?? 0).toDouble();
    final discount = (s['discount_amount'] as num? ?? 0).toDouble();
    final pending = (totalFee - discount - amountPaid).clamp(0.0, double.infinity);

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Delete ${s["name"]}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amount Paid', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text('₹${amountPaid.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Give Refund', style: TextStyle(fontSize: 14)),
                value: giveRefund,
                onChanged: amountPaid > 0
                    ? (v) => setDialogState(() {
                          giveRefund = v!;
                          if (!v) refundAmount = 0;
                          else refundAmount = amountPaid;
                        })
                    : null,
                subtitle: amountPaid == 0
                    ? const Text('No payment received', style: TextStyle(fontSize: 11, color: Colors.grey))
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (giveRefund) ...[
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: amountPaid.toInt().toString(),
                  decoration: InputDecoration(
                    labelText: 'Refund Amount (₹)',
                    prefixText: '₹ ',
                    helperText: 'Max: ₹${amountPaid.toInt()}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, {'giveRefund': giveRefund, 'refundAmount': refundAmount}),
              child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        setState(() => _isLoading = true);
        final bool shouldRefund = result['giveRefund'] ?? false;
        final double refund = result['refundAmount'] ?? 0;

        // 1. Soft delete
        await supabase.from('students').update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        }).eq('id', s['id']);

        // 2. Cache
        await CacheService.onStudentDeleted(s['id']);

        // 3. Delete shifts
        await supabase.from('student_seat_shifts').delete().eq('student_id', s['id']);

        // 4. Free locker
        if (s['locker_id'] != null) {
          await supabase.from('lockers').update({'status': 'free'}).eq('id', s['locker_id']);
          await CacheService.onLockerUpdated(s['locker_id'], 'free');
        }

        // 5. Financial event
        final eventRes = await supabase.from('financial_events').insert({
          'library_id': currentLibraryId,
          'student_id': s['id'],
          'student_name': s['name'],
          'event_type': shouldRefund && refund > 0 ? 'REFUND_ON_DELETE' : 'NO_REFUND_ON_DELETE',
          'amount': shouldRefund ? refund : 0,
          'pending_amount': pending,
          'payment_mode': 'cash',
          'actor_role': currentRole,
          'actor_name': currentUserName,
          'note': shouldRefund && refund > 0
              ? 'Student deleted. Refund ₹${refund.toInt()} given.'
              : pending > 0
                  ? 'Student deleted. ₹${pending.toInt()} pending waived.'
                  : 'Student deleted. No refund.',
        }).select().single();
        await CacheService.onFinancialEventAdded(eventRes);

        // 6. Notification
        final notifRes = await supabase.from('notifications').insert({
          'library_id': currentLibraryId,
          'student_id': s['id'],
          'type': 'new_admission',
          'title': 'Student Deleted — ${s["name"]}',
          'message': shouldRefund && refund > 0 ? '${s["name"]} removed. Refund ₹${refund.toInt()} issued.' : '${s["name"]} removed.',
          'is_read': false,
        }).select().single();
        await CacheService.onNotificationAdded(notifRes);

        if (mounted) {
          Navigator.pop(context);
          widget.onUpdate();
        }
      } catch (e) {
        debugPrint('Error deleting student: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
