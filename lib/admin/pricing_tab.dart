import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../globals.dart';
import '../login_screen.dart';

class PricingTab extends StatefulWidget {
  const PricingTab({super.key});

  @override
  State<PricingTab> createState() => PricingTabState();
}

class PricingTabState extends State<PricingTab> {
  bool _isLoading = true;
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    fetchPlans();
  }

  Future<void> fetchPlans() async {
    setState(() => _isLoading = true);
    try {
      final jwt = await storage.read(key: 'admin_jwt');
      final res = await http.get(
        Uri.parse('$baseUrl/update-pricing'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (res.statusCode == 401) {
        await storage.delete(key: 'admin_jwt');
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
        return;
      }

      if (res.statusCode == 200) {
        setState(() {
          _plans = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getPlanName(String plan) {
    switch (plan) {
      case '1m': return '1 Month';
      case '3m': return '3 Months';
      case '6m': return '6 Months';
      case '12m': return '12 Months';
      default: return plan;
    }
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return 'No validity';
    
    int days = totalMinutes ~/ 1440;
    int remainingMinutesAfterDays = totalMinutes % 1440;
    int hours = remainingMinutesAfterDays ~/ 60;
    int minutes = remainingMinutesAfterDays % 60;

    List<String> parts = [];
    if (days > 0) parts.add('$days days');
    if (hours > 0) parts.add('$hours hrs');
    if (minutes > 0) parts.add('$minutes mins');
    
    return parts.isEmpty ? '0 mins' : parts.join(', ');
  }

  void _showEditSheet(Map<String, dynamic> planData) {
    final amountController = TextEditingController(text: planData['amount'].toString());
    final minutesController = TextEditingController(text: planData['duration_minutes'].toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: adminSurfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit ${_getPlanName(planData['plan'])}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('Amount (₹)', style: TextStyle(color: adminTextSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: adminBgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Validity (minutes)', style: TextStyle(color: adminTextSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Ref: 1 Month = 43,200 mins', style: TextStyle(color: adminAccentColor, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: adminBgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  helperText: 'Enter direct minutes value',
                  helperStyle: const TextStyle(color: adminTextSecondary, fontSize: 11),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setSheetState(() => isSaving = true);
                    final jwt = await storage.read(key: 'admin_jwt');
                    try {
                      final reqBody = {
                        'plan': planData['plan'],
                        'amount': double.parse(amountController.text).toInt(),
                        'duration_minutes': int.parse(minutesController.text),
                      };
                      final res = await http.patch(
                        Uri.parse('$baseUrl/update-pricing'),
                        headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
                        body: jsonEncode(reqBody),
                      );

                      if (res.statusCode == 200) {
                        if (mounted) Navigator.pop(context);
                        fetchPlans();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan updated'), backgroundColor: Colors.green));
                      } else {
                        setSheetState(() => isSaving = false);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res.body}'), backgroundColor: Colors.red));
                      }
                    } catch (e) {
                      setSheetState(() => isSaving = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: adminAccentColor, foregroundColor: Colors.white),
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: adminTextSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmerLoading();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subscription Plans', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Tap edit to update pricing', style: TextStyle(color: adminTextSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          ..._plans.map((plan) => _buildPlanCard(plan)),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: adminSurfaceColor,
      highlightColor: adminBorderColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorderColor),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getPlanName(plan['plan']), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('₹${plan['amount']}', style: const TextStyle(color: adminAccentColor, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(_formatDuration(plan['duration_minutes']), style: const TextStyle(color: adminTextSecondary, fontSize: 13)),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _showEditSheet(plan),
            child: const Text('Edit ✏️', style: TextStyle(color: adminAccentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
