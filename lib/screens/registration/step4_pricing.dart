import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/registration_form_data.dart';

class Step4Pricing extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step4Pricing({super.key, required this.onNext, required this.onBack});

  @override
  State<Step4Pricing> createState() => _Step4State();
}

class _Step4State extends State<Step4Pricing> with SingleTickerProviderStateMixin {
  int _selectedDurationIndex = 0; // 0: 1m, 1: 3m, 2: 6m, 3: 12m
  final List<int> _durations = [1, 3, 6, 12];
  final List<String> _comboKeys = [
    'M', 'A', 'E', 'N', 
    'MA', 'ME', 'MN', 'AE', 'AN', 'EN', 
    'MAE', 'MAN', 'MEN', 'AEN', 
    'MAEN'
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    formData.calculateComboPricing();
    
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

  void _onBasePriceChanged(String v) {
    double? val = double.tryParse(v);
    if (val != null) {
      setState(() {
        formData.basePrice = val;
        formData.calculateComboPricing();
      });
    }
  }

  void _editCell(String comboKey, int months) {
    final existing = formData.comboPricing.firstWhere((p) => p['combination_key'] == comboKey && p['months'] == months);
    final controller = TextEditingController(text: existing['fee'].toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Edit Price', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  IconButton(
                    onPressed: () => Navigator.pop(context), 
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$comboKey Shift • $months Months duration', 
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              _buildLabel('Pricing Fee'),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF818CF8)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), 
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    double? val = double.tryParse(controller.text);
                    if (val != null) {
                      setState(() {
                        formData.manuallyEditedCells.add("$comboKey-$months");
                        final idx = formData.comboPricing.indexWhere((p) => p['combination_key'] == comboKey && p['months'] == months);
                        formData.comboPricing[idx]['fee'] = val;
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Update Price', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Expanded(
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
                      'Plans & Pricing', 
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28, 
                        fontWeight: FontWeight.w800, 
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set fees for different shift combos', 
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, 
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildLabel('Base Price (Single Shift / 1 Month)'),
                    _buildPriceField(),

                    const SizedBox(height: 32),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: _durations.asMap().entries.map((e) => _buildDurationChip(e.key)).toList(),
                    ),

                    const SizedBox(height: 24),
                    _buildPricingTable(),
                  ],
                ),
              ),
            ),
            
            // Sticky Footer area
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 16),
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
              child: Container(
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
                          'Confirm Pricing', 
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
            ),
          ],
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
      onChanged: _onBasePriceChanged,
      keyboardType: TextInputType.number,
      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14), 
          child: Text('₹', style: GoogleFonts.plusJakartaSans(fontSize: 20, color: const Color(0xFF818CF8), fontWeight: FontWeight.bold)),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
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

  Widget _buildDurationChip(int index) {
    bool isSelected = _selectedDurationIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedDurationIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: MediaQuery.of(context).size.width * 0.18,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.1),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
          ] : [],
        ),
        child: Center(
          child: Text(
            '${_durations[index]}m',
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? Colors.white : Colors.white54, 
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingTable() {
    int duration = _durations[_selectedDurationIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF312E81), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 2, 
                    child: Text('SHIFT COMBO', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ),
                  Expanded(
                    child: Text('FEE (₹)', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5), textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
            ..._comboKeys.map((key) {
               final data = formData.comboPricing.firstWhere((p) => p['combination_key'] == key && p['months'] == duration, orElse: () => {'fee': 0.0});
               bool isManual = formData.manuallyEditedCells.contains("$key-$duration");
               
               return InkWell(
                 onTap: () => _editCell(key, duration),
                 child: Container(
                   padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                   decoration: BoxDecoration(
                     color: isManual ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.transparent,
                     border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                   ),
                   child: Row(
                     children: [
                       Expanded(
                         flex: 2,
                         child: Text(
                           key, 
                           style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                         ),
                       ),
                       Expanded(
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.end,
                           children: [
                             Text(
                               '₹${data['fee'].toStringAsFixed(0)}', 
                               style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16),
                             ),
                             const SizedBox(width: 8),
                             Icon(Icons.edit_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
               );
            }),
          ],
        ),
      ),
    );
  }
}
