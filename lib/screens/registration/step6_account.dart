import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../../models/registration_form_data.dart';

class Step6Account extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step6Account({super.key, required this.onNext, required this.onBack});

  @override
  State<Step6Account> createState() => _Step6State();
}

class _Step6State extends State<Step6Account> with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _phoneController;
  final FocusNode _emailFocusNode = FocusNode();
  final List<Map<String, TextEditingController>> _staffControllers = [];
  bool? _emailExists;
  bool _isCheckingEmail = false;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: formData.ownerName);
    _emailController = TextEditingController(text: formData.ownerEmail);
    _passwordController = TextEditingController(text: formData.ownerPassword);
    _phoneController = TextEditingController(text: formData.phone);
    
    for (var staff in formData.staffList) {
       _staffControllers.add({
         'name': TextEditingController(text: staff['name']),
         'email': TextEditingController(text: staff['email']),
         'password': TextEditingController(text: staff['password']),
       });
    }

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _checkEmailAvailability();
      }
    });

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _emailFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailAvailability() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    setState(() {
      _isCheckingEmail = true;
      _emailExists = null;
    });

    try {
      final res = await http.post(
        Uri.parse(epCheckEmail),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _emailExists = data['exists'] == true;
        });
      }
    } catch (e) {
      debugPrint('Email check error: $e');
    } finally {
      setState(() => _isCheckingEmail = false);
    }
  }

  String _getPasswordStrength(String p) {
    if (p.isEmpty) return "";
    if (p.length < 6) return "Too short";
    if (!RegExp(r'[A-Z]').hasMatch(p)) return "Weak";
    if (!RegExp(r'[0-9]').hasMatch(p)) return "Fair";
    return "Strong";
  }

  Color _getStrengthColor(String strength) {
    switch (strength) {
      case "Too short": return const Color(0xFFEF4444);
      case "Weak": return const Color(0xFFF59E0B);
      case "Fair": return const Color(0xFFEAB308);
      case "Strong": return const Color(0xFF10B981);
      default: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    String strength = _getPasswordStrength(_passwordController.text);

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
                'Create Account', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter owner details to continue', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, 
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),

              // Owner Card
              _buildLabel('OWNER ACCOUNT', color: const Color(0xFF818CF8)),
              _buildCard([
                _buildTextField(_nameController, 'Full Name', 'Owner Name'),
                const SizedBox(height: 16),
                _buildTextField(
                  _emailController, 
                  'Owner Email', 
                  'Email Address', 
                  keyboardType: TextInputType.emailAddress,
                  focusNode: _emailFocusNode,
                  suffixIcon: _isCheckingEmail 
                    ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))))
                    : (_emailExists == false ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20) : null),
                  errorText: _emailExists == true ? 'Email already registered' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(_phoneController, 'Owner Phone', 'Contact Number', keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _buildTextField(
                  _passwordController, 
                  'Password', 
                  'Secure Password', 
                  obscure: _obscurePassword, 
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: Colors.white54),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                if (strength.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6, 
                          decoration: BoxDecoration(
                            color: _getStrengthColor(strength).withOpacity(0.8), 
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [BoxShadow(color: _getStrengthColor(strength).withOpacity(0.4), blurRadius: 4)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(strength, style: GoogleFonts.plusJakartaSans(color: _getStrengthColor(strength), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ]
              ]),

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
                        formData.ownerName = _nameController.text;
                        formData.ownerEmail = _emailController.text;
                        formData.ownerPassword = _passwordController.text;
                        formData.phone = _phoneController.text;
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
                        Text('Final Step', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)), 
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

  Widget _buildLabel(String text, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text, 
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12, 
          fontWeight: FontWeight.w800, 
          color: color, 
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: Colors.white.withOpacity(0.1)), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    String hint, 
    {bool obscure = false, TextInputType? keyboardType, Function(String)? onChanged, FocusNode? focusNode, Widget? suffixIcon, String? errorText}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          focusNode: focusNode,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), 
              borderSide: BorderSide(color: errorText != null ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), 
              borderSide: BorderSide(color: errorText != null ? const Color(0xFFEF4444) : const Color(0xFF6366F1), width: 2),
            ),
            errorText: errorText,
            errorStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
