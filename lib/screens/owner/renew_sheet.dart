import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../constants.dart';
import '../../globals.dart';

class RenewSheet extends StatefulWidget {
  const RenewSheet({super.key});

  @override
  State<RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends State<RenewSheet> {
  List<dynamic> plans = [];
  int? selectedMonths;
  bool isLoadingPlans = true;
  bool isProcessing = false;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
    _initRazorpay();
  }

  // Step 1: Plans fetch
  Future<void> _fetchPlans() async {
    try {
      final res = await http.get(Uri.parse(epPricing));
      if (res.statusCode == 200) {
        setState(() {
          plans = List<dynamic>.from(jsonDecode(res.body));
          isLoadingPlans = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      setState(() => isLoadingPlans = false);
    }
  }

  // Razorpay init
  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
  }

  // Step 2: Order create
  Future<void> _createOrder() async {
    if (selectedMonths == null) return;
    setState(() => isProcessing = true);

    try {
      final jwt = supabase.auth.currentSession!.accessToken;

      final res = await http.post(
        Uri.parse('$baseUrl/create-renewal-order'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'library_id': currentLibraryId,
          'plan_months': selectedMonths,
        }),
      );

      if (res.statusCode != 200) {
        final err = jsonDecode(res.body)['error'];
        throw Exception(err);
      }

      final data = jsonDecode(res.body);

      // Step 3: Razorpay open
      _razorpay.open({
        'key': data['key'],
        'order_id': data['order_id'],
        'amount': data['amount'],
        'currency': 'INR',
        'name': 'LibraryOS',
        'description': '$selectedMonths Month Plan',
        'prefill': {
          'contact': libraryPhone,
        },
        'theme': {'color': '#1E2D6B'},
      });

    } catch (e) {
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFB91C1C)),
      );
    }
  }

  // Step 4: Payment success
  Future<void> _onPaymentSuccess(PaymentSuccessResponse res) async {
    try {
      // verify-renewal call
      final verifyRes = await http.post(
        Uri.parse('$baseUrl/verify-renewal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_order_id': res.orderId,
          'razorpay_payment_id': res.paymentId,
          'razorpay_signature': res.signature,
          'library_id': currentLibraryId,
          'plan_months': selectedMonths,
        }),
      );

      final data = jsonDecode(verifyRes.body);

      if (verifyRes.statusCode == 200 && data['success'] == true) {
        // Global subscription update
        subscriptionStatus = 'active';
        subscriptionEnd = DateTime.parse(data['new_expiry']);

        if (mounted) {
          Navigator.pop(context); // sheet close
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription renewed!'), backgroundColor: Color(0xFF16A34A)),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Verification failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFB91C1C)),
      );
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _onPaymentError(PaymentFailureResponse res) {
    if (mounted) {
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${res.message}'), backgroundColor: const Color(0xFFB91C1C)),
      );
    }
  }

  // Helpers
  String _planName(String plan) {
    switch (plan) {
      case '1m': return '1 Month';
      case '3m': return '3 Months';
      case '6m': return '6 Months';
      case '12m': return '12 Months';
      default: return plan;
    }
  }

  int _planMonths(String plan) {
    return int.parse(plan.replaceAll('m', ''));
  }

  int _planDays(int minutes) => minutes ~/ 1440;

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Renew Subscription', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111111))),
          const SizedBox(height: 4),
          Text('Select a plan to continue', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF6B7280))),
          const SizedBox(height: 20),
          if (isLoadingPlans)
            const Center(child: CircularProgressIndicator(color: Color(0xFF1E2D6B)))
          else
            ...plans.map((plan) {
              final months = _planMonths(plan['plan']);
              final isSelected = selectedMonths == months;
              final days = _planDays(plan['duration_minutes'] as int);

              return GestureDetector(
                onTap: () => setState(() => selectedMonths = months),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF1FB) : Colors.white,
                    border: Border.all(color: isSelected ? const Color(0xFF1E2D6B) : const Color(0xFFE5E7EB), width: isSelected ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_planName(plan['plan']), style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF111111))),
                          Text('$days days validity', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF6B7280))),
                        ],
                      ),
                      const Spacer(),
                      Text('₹${plan['amount']}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1E2D6B))),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: Color(0xFF1E2D6B), size: 20),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: selectedMonths == null || isProcessing ? null : _createOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2D6B),
              disabledBackgroundColor: const Color(0xFF9CA3AF),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(selectedMonths == null ? 'Select a plan' : 'Pay & Renew', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
