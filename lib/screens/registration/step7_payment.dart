import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../constants.dart';
import '../../models/registration_form_data.dart';
import 'registration_success.dart';

class Step7Payment extends StatefulWidget {
  final VoidCallback onBack;
  const Step7Payment({super.key, required this.onBack});

  @override
  State<Step7Payment> createState() => _Step7State();
}

class _Step7State extends State<Step7Payment> with SingleTickerProviderStateMixin {
  List<dynamic> plans = [];
  bool isLoading = true;
  bool isProcessing = false;
  late Razorpay _razorpay;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _fadeController = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 600)
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlans() async {
    try {
      final res = await http.get(Uri.parse(epPricing));
      if (res.statusCode == 200) {
        setState(() {
          plans = jsonDecode(res.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _initiatePayment() async {
    if (formData.selectedPlan == null) return;
    setState(() => isProcessing = true);

    try {
      final res = await http.post(
        Uri.parse(epCreatePaymentOrder),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'form_data': {
             'owner': {'name': formData.ownerName, 'email': formData.ownerEmail, 'password': formData.ownerPassword, 'isExisting': false},
             'library': {
               'name': formData.libraryName, 
               'address': formData.address, 
               'city': formData.district, // Mapping district to city as requested
               'state': formData.state, 
               'pincode': formData.pincode, 
               'phone': formData.phone, 
               'is_gender_neutral': formData.isGenderNeutral
             },
             'seats': {'male_seats': formData.maleSeats, 'female_seats': formData.femaleSeats, 'neutral_seats': formData.neutralSeats},
             'lockers': {'has_lockers': formData.hasLockers, 'male_lockers': formData.maleLockers, 'female_lockers': formData.femaleLockers, 'neutral_lockers': formData.neutralLockers},
             'shifts': formData.shifts,
             'combos': formData.comboPricing,
             'locker_policy': formData.hasLockers ? {'eligible_combos': formData.eligibleCombos, 'monthly_fee': formData.lockerMonthlyFee} : null,
             'staff_list': formData.staffList,
             'amount': formData.selectedAmount,
             'plan': formData.selectedPlan,
          },
          'plan': formData.selectedPlan,
        }),
      );

      final data = jsonDecode(res.body);
      
      var options = {
        'key': razorpayKeyId,
        'amount': data['amount'],
        'name': 'LibraryOS',
        'order_id': data['order_id'],
        'description': 'Library Registration - ${formData.selectedPlan}',
        'prefill': {'contact': formData.phone, 'email': formData.ownerEmail},
        'theme': {'color': '#6366F1'}
      };

      _razorpay.open(options);
    } catch (e) {
      _showError('Failed to create order');
      setState(() => isProcessing = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final res = await http.post(
        Uri.parse(epVerifyPayment),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        }),
      );

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationSuccessScreen()),
          (route) => false,
        );
      } else {
        _showError(data['error'] ?? 'Verification failed');
      }
    } catch (e) {
      _showError('Verification error');
    }
    setState(() => isProcessing = false);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showError('Payment failed: ${response.message}');
    setState(() => isProcessing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: widget.onBack,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Choose Plan', 
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28, 
                            fontWeight: FontWeight.w800, 
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a subscription to activate your library', 
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, 
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),

                        ...plans.map((p) => _buildPlanCard(p)),
                      ],
                    ),
                  ),
            ),
            if (formData.selectedPlan != null)
              _buildBottomSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(dynamic plan) {
    bool isSelected = formData.selectedPlan == plan['plan'];
    double originalPrice = plan['amount'] * 1.25;
    int savings = 20; // Example
    
    return GestureDetector(
      onTap: () => setState(() {
        formData.selectedPlan = plan['plan'];
        formData.selectedAmount = plan['amount'].toDouble();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.1), 
            width: isSelected ? 2 : 1
          ),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20)] : [],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan['plan'], 
                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '₹${originalPrice.toStringAsFixed(0)}', 
                      style: GoogleFonts.plusJakartaSans(
                        decoration: TextDecoration.lineThrough, 
                        color: Colors.white38, 
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text('Save $savings%', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${plan['amount']}', 
                  style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF818CF8))
                ),
                const SizedBox(height: 8),
                Text(
                  '${plan['duration_minutes'] ~/ 1440} Days Validity', 
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)
                ),
              ],
            ),
            if (isSelected)
              const Positioned(top: 0, right: 0, child: Icon(Icons.check_circle_rounded, color: Color(0xFF818CF8), size: 28)),
            if (plan['plan'] == '3m')
              Positioned(top: 0, right: 40, child: _badge('POPULAR', const Color(0xFFF59E0B))),
            if (plan['plan'] == '12m')
              Positioned(top: 0, right: 40, child: _badge('BEST VALUE', const Color(0xFF10B981))),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F172A).withOpacity(0.0),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SELECTED PLAN', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 1)),
              Text(formData.selectedPlan!, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isProcessing ? [] : [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isProcessing ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                  disabledBackgroundColor: Colors.white.withOpacity(0.1),
                  elevation: 0,
                ),
                child: isProcessing 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text('Verifying Payment...', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Pay ₹${formData.selectedAmount.toStringAsFixed(0)} & Activate', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
