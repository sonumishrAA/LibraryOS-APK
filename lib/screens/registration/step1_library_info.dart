import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/registration_form_data.dart';
import 'package:libraryos/utils/india_data.dart';

class Step1LibraryInfo extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step1LibraryInfo({super.key, required this.onNext, required this.onBack});

  @override
  State<Step1LibraryInfo> createState() => _Step1State();
}

class _Step1State extends State<Step1LibraryInfo> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;
  String? _selectedState = formData.state.isEmpty ? null : formData.state;
  String? _selectedDistrict = formData.district.isEmpty ? null : formData.district;
  
  late AnimationController _fadeController;
  final Map<String, List<String>> _stateDistricts = indianStatesDistricts;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: formData.libraryName);
    _addressController = TextEditingController(text: formData.address);
    _pincodeController = TextEditingController(text: formData.pincode);
    
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A), // Match homescreen background
      child: FadeTransition(
        opacity: _fadeController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Library Details', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Tell us about your library to set up your smart dashboard.', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white54, height: 1.5)),
                const SizedBox(height: 40),
                
                _buildLabel('Library Name'),
                _buildTextField(_nameController, 'Enter library name'),
                
                const SizedBox(height: 24),
                _buildLabel('Address'),
                _buildTextField(_addressController, 'Full address'),
                
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('State'),
                          _buildStateDropdown(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('District'),
                          _buildDistrictDropdown(),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Pincode'),
                          TextFormField(
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length != 6) return 'Must be 6 digits';
                              if (!RegExp(r'^\d+$').hasMatch(v)) return 'Numbers only';
                              return null;
                            },
                            decoration: _inputDecoration('6-digit code'),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        formData.libraryName = _nameController.text;
                        formData.address = _addressController.text;
                        formData.state = _selectedState ?? '';
                        formData.district = _selectedDistrict ?? '';
                        formData.pincode = _pincodeController.text;
                        widget.onNext();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFF6366F1).withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5)),
    );
  }
  
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      counterText: '',
      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 15),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
      validator: (v) => v!.isEmpty ? 'Required' : null,
      decoration: _inputDecoration(hint),
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), 
        border: Border.all(color: Colors.white.withOpacity(0.1)), 
        borderRadius: BorderRadius.circular(16)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
          hint: Text('Select State', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14)),
          isExpanded: true,
          onChanged: (v) {
            setState(() {
              _selectedState = v;
              _selectedDistrict = null;
            });
          },
          items: _stateDistricts.keys.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white)))).toList(),
        ),
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    List<String> districts = _selectedState != null ? _stateDistricts[_selectedState]! : [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), 
        border: Border.all(color: Colors.white.withOpacity(0.1)), 
        borderRadius: BorderRadius.circular(16)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDistrict,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
          hint: Text('Select District', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 14)),
          isExpanded: true,
          onChanged: (v) => setState(() => _selectedDistrict = v),
          items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white)))).toList(),
        ),
      ),
    );
  }
}
