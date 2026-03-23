import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/registration_form_data.dart';

class Step2Inventory extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step2Inventory({super.key, required this.onNext, required this.onBack});

  @override
  State<Step2Inventory> createState() => _Step2State();
}

class _Step2State extends State<Step2Inventory> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
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
                'Seats & Lockers', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure your capacity', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, 
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              Row(
                children: [
                   Expanded(child: _buildCounterField('Male Seats', formData.maleSeats, (v) => setState(() => formData.maleSeats = v))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCounterField('Female Seats', formData.femaleSeats, (v) => setState(() => formData.femaleSeats = v))),
                ],
              ),

              const SizedBox(height: 32),
              _buildLockerSection(),

              const SizedBox(height: 56),

              // Enhanced Premium Next Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
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
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue', 
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, 
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounterField(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, 
            fontWeight: FontWeight.w700, 
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border.all(color: Colors.white.withOpacity(0.1)), 
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            initialValue: value == 0 ? '' : value.toString(),
            keyboardType: TextInputType.number,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, 
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            onChanged: (v) {
              final n = int.tryParse(v) ?? 0;
              onChanged(n);
            },
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontWeight: FontWeight.normal),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockerSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: formData.hasLockers ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: formData.hasLockers ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.white.withOpacity(0.1), 
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Has Lockers?', 
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, 
                        fontWeight: FontWeight.w700, 
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Premium facility for students', 
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: formData.hasLockers,
                activeColor: const Color(0xFF6366F1),
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                inactiveThumbColor: Colors.white54,
                onChanged: (v) => setState(() => formData.hasLockers = v),
              ),
            ],
          ),
        ),
        AnimatedContainer(
           duration: const Duration(milliseconds: 400),
           curve: Curves.fastOutSlowIn,
          height: formData.hasLockers ? 120 : 0,
          decoration: const BoxDecoration(),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                children: [
                  Expanded(child: _buildCounterField('Male Lockers', formData.maleLockers, (v) => setState(() => formData.maleLockers = v))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCounterField('Female Lockers', formData.femaleLockers, (v) => setState(() => formData.femaleLockers = v))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
