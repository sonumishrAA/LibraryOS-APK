import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'package:libraryos/auth/change_password_screen.dart';
import 'package:libraryos/screens/registration/registration_navigator.dart';
import 'package:libraryos/globals.dart';
import 'package:libraryos/admin/admin_shell.dart';
import 'package:libraryos/screens/owner/sync_loading_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isNavigating = false;
  
  late AnimationController _bgController;
  late AnimationController _tiltController;
  
  // 3D Parallax State
  Offset _pointerOffset = Offset.zero;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _tiltController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }
  
  @override
  void dispose() {
    _bgController.dispose();
    _tiltController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerEvent event) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    setState(() {
      _pointerOffset = event.position;
      _tiltX = (event.position.dy - centerY) / centerY; // -1 to 1
      _tiltY = (event.position.dx - centerX) / centerX; // -1 to 1
    });
  }

  void _onPointerCancel() {
    setState(() {
      _tiltX = 0;
      _tiltY = 0;
    });
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    if (_isNavigating) return;
    setState(() => _isLoading = true);

    try {
      // Admin Login Fallback
      try {
        final adminRes = await http.post(
          Uri.parse('$baseUrl/admin-login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );
        if (adminRes.statusCode == 200) {
          final adminData = jsonDecode(adminRes.body);
          if (adminData['success'] == true) {
            await storage.write(key: 'admin_jwt', value: adminData['token']);
            if (mounted) {
              _isNavigating = true;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AdminShell()), (route) => false);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Admin fallback check: $e');
      }

      // Supabase Auth
      final response = await supabase.auth.signInWithPassword(email: email, password: password);
      if (response.user == null) throw Exception('Login failed');

      await supabase.auth.signOut(scope: SignOutScope.others);

      final staffData = await supabase.from('staff').select('role, force_password_change').eq('user_id', response.user!.id).single();
      final forceChange = staffData['force_password_change'] ?? false;

      if (!mounted) return;

      if (forceChange) {
        _isNavigating = true;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()), (route) => false);
        return;
      }

      final staffInfo = await supabase.from('staff').select('name, role, library_ids').eq('user_id', response.user!.id).single();

      currentRole = staffInfo['role'];
      currentLibraryId = staffInfo['library_ids'][0];
      currentUserName = staffInfo['name'] ?? '';

      if (currentRole == 'owner' || currentRole == 'staff') {
        _isNavigating = true;
        
        // Use a fade transition to seamlessly merge into the SyncLoadingScreen
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => SyncLoadingScreen(libraryId: currentLibraryId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      } else {
        throw Exception('Access denied.');
      }
    } on AuthException catch (e) {
      _isNavigating = false;
      _showError(e.message);
    } catch (e) {
      _isNavigating = false;
      _showError(e.toString().contains('Connection failed') ? 'Connection failed. Check your internet.' : e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFEF4444), // Red 500
        content: Row(
          children: [
             const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
             const SizedBox(width: 12),
             Expanded(child: Text(message, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold))),
          ]
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final val = _bgController.value;
          final sinVal = math.sin(val * math.pi * 2);
          final cosVal = math.cos(val * math.pi * 2);
          
          final px = _tiltY * 40;
          final py = _tiltX * 40;

          return Stack(
            children: [
              Positioned(
                top: -100 + (sinVal * 40) + py,
                right: -100 + (cosVal * 30) - px,
                child: _buildBlob(500, const Color(0xFF1E293B), 0.2), // Slate 800
              ),
              Positioned(
                bottom: -50 + (sinVal * -60) + py,
                left: -150 + (sinVal * 40) + px,
                child: _buildBlob(400, const Color(0xFF6366F1), 0.15), // Indigo 500
              ),
              Positioned(
                 top: 200 + (cosVal * 50) - py,
                 right: -50 + (sinVal * -30) - px,
                 child: _buildBlob(350, const Color(0xFF10B981), 0.1), // Emerald mix
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBlob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3D Matrix calculation based on pointer position relative to center
    // Limits the rotation angle for a subtle 3D pop effect
    final double maxRotation = 0.1;
    final Matrix4 tiltMatrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // perspective
      ..rotateX(-_tiltX * maxRotation) // inverted to tilt towards pointer
      ..rotateY(_tiltY * maxRotation);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Listener(
        onPointerMove: _onPointerMove,
        onPointerHover: _onPointerMove,
        onPointerUp: (_) => _onPointerCancel(),
        onPointerCancel: (_) => _onPointerCancel(),
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Floating 3D Logo Header
                      Transform(
                        transform: tiltMatrix,
                        alignment: FractionalOffset.center,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 40, offset: Offset(-_tiltY*15, 15 - _tiltX*15)),
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 48),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // 3D Glassmorphism Card
                      Transform(
                        transform: tiltMatrix,
                        alignment: FractionalOffset.center,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2), 
                                blurRadius: 60, 
                                offset: Offset(-_tiltY*30, 30 - _tiltX*30)
                              ),
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Secure Login',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Authenticate to access your LibraryOS Dashboard',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 40),

                                  _buildTextField(
                                    controller: _emailController,
                                    hintText: 'Email ID',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 16),

                                  _buildTextField(
                                    controller: _passwordController,
                                    hintText: 'Master Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: !_isPasswordVisible,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 40),
                                  
                                  // 3D Login Button
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: _isLoading ? null : _handleLogin,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: double.infinity,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                                          boxShadow: [
                                             if (!_isLoading) BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.5), blurRadius: 25, offset: const Offset(0, 10))
                                          ]
                                        ),
                                        child: Center(
                                          child: _isLoading
                                              ? Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                     const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                                                     const SizedBox(width: 12),
                                                     Text('Authenticating...', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
                                                  ],
                                              )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('ENTER VAULT', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                                                    const SizedBox(width: 12),
                                                    const Icon(Icons.login_rounded, size: 20, color: Colors.white),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Want to join LibraryOS?', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationNavigator())),
                            child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                               decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                               child: Text('Register', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF818CF8), fontWeight: FontWeight.w900, fontSize: 13))
                            ),
                          )
                        ],
                      ),
                      
                      const SizedBox(height: 40),

                      // Footer with visual security indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 16),
                             const SizedBox(width: 10),
                             Text('AES-256 Protected Workspace', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
         color: Colors.white.withOpacity(0.04),
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 15, fontWeight: FontWeight.w600),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Icon(icon, color: Colors.white54, size: 22),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
