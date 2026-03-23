import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/registration_form_data.dart';

class Step5LockerPolicy extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step5LockerPolicy({super.key, required this.onNext, required this.onBack});

  @override
  State<Step5LockerPolicy> createState() => _Step5State();
}

class _Step5State extends State<Step5LockerPolicy> with SingleTickerProviderStateMixin {
  final List<String> _comboKeys = [
    'M', 'A', 'E', 'N', 
    'MA', 'ME', 'MN', 'AE', 'AN', 'EN', 
    'MAE', 'MAN', 'MEN', 'AEN', 
    'MAEN'
  ];
  late TextEditingController _feeController;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (formData.eligibleCombos.isEmpty) {
      formData.eligibleCombos = List.from(_comboKeys);
    }
    _feeController = TextEditingController(
      text: formData.lockerMonthlyFee > 0 ? formData.lockerMonthlyFee.toStringAsFixed(0) : ''
    );
    
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
    _feeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600))),
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
                'Locker Policy', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure locker access and fees', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, 
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              _buildLabel('Monthly Locker Fee'),
              _buildPriceField(),

              const SizedBox(height: 40),
              _buildLabel('Eligible Combos'),
              Text(
                'Select combos that can avail lockers', 
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _comboKeys.map((c) => _buildChoiceChip(c)).toList(),
              ),

              const SizedBox(height: 48),
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
                    onPressed: () {
                      if (formData.lockerMonthlyFee <= 0) {
                        _showErrorSnackBar('Please enter monthly locker fee');
                        return;
                      }
                      if (formData.eligibleCombos.isEmpty) {
                        _showErrorSnackBar('Select at least one combo');
                        return;
                      }
                      widget.onNext();
                    },
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label, 
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13, 
          fontWeight: FontWeight.w700, 
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildPriceField() {
    return TextField(
      controller: _feeController,
      onChanged: (v) => formData.lockerMonthlyFee = double.tryParse(v) ?? 0,
      keyboardType: TextInputType.number,
      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14), 
          child: Text('₹', style: GoogleFonts.plusJakartaSans(fontSize: 20, color: const Color(0xFF818CF8), fontWeight: FontWeight.bold)),
        ),
        hintText: 'e.g. 500',
        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label) {
    bool isSelected = formData.eligibleCombos.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            formData.eligibleCombos.remove(label);
          } else {
            formData.eligibleCombos.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.1),
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
          ] : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
