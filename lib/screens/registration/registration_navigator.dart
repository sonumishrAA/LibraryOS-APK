import 'package:flutter/material.dart';
import 'package:libraryos/models/registration_form_data.dart';
import 'package:libraryos/login_screen.dart';
import 'package:libraryos/screens/registration/step1_library_info.dart';
import 'package:libraryos/screens/registration/step2_inventory.dart';
import 'package:libraryos/screens/registration/step3_shifts.dart';
import 'package:libraryos/screens/registration/step4_pricing.dart';
import 'package:libraryos/screens/registration/step5_locker_policy.dart';
import 'package:libraryos/screens/registration/step6_account.dart';
import 'package:libraryos/screens/registration/step7_payment.dart';

class RegistrationNavigator extends StatefulWidget {
  const RegistrationNavigator({super.key});

  @override
  State<RegistrationNavigator> createState() => _RegistrationNavigatorState();
}

class _RegistrationNavigatorState extends State<RegistrationNavigator> {
  int currentStep = 1;
  final int totalSteps = 7;

  void nextStep() {
    if (currentStep < totalSteps) {
      setState(() => currentStep++);
    }
  }

  void prevStep() {
    if (currentStep == 1) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      // Handle Step 5 skip logic on back
      if (currentStep == 6 && !formData.hasLockers) {
         setState(() => currentStep = 4);
      } else {
         setState(() => currentStep--);
      }
    }
  }

  Widget _buildStep() {
    switch (currentStep) {
      case 1: return Step1LibraryInfo(onNext: nextStep, onBack: prevStep);
      case 2: return Step2Inventory(onNext: nextStep, onBack: prevStep);
      case 3: return Step3Shifts(onNext: nextStep, onBack: prevStep);
      case 4: return Step4Pricing(onNext: () {
        if (!formData.hasLockers) {
          setState(() => currentStep = 6);
        } else {
          nextStep();
        }
      }, onBack: prevStep);
      case 5: return Step5LockerPolicy(onNext: nextStep, onBack: prevStep);
      case 6: return Step6Account(onNext: nextStep, onBack: prevStep);
      case 7: return Step7Payment(onBack: prevStep);
      default: return Step1LibraryInfo(onNext: nextStep, onBack: prevStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = currentStep / totalSteps;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step $currentStep of $totalSteps',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(3))),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        width: MediaQuery.of(context).size.width * progress,
                        decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(3)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Step Content
            Expanded(child: _buildStep()),
          ],
        ),
      ),
    );
  }
}
