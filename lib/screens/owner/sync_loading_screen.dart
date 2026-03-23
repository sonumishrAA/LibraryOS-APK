import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../services/sync_service.dart';
import 'owner_shell.dart';
import '../../constants.dart';
import '../../globals.dart';

class SyncLoadingScreen extends StatefulWidget {
  final String libraryId;
  const SyncLoadingScreen({super.key, required this.libraryId});

  @override
  State<SyncLoadingScreen> createState() => _SyncLoadingScreenState();
}

class _SyncLoadingScreenState extends State<SyncLoadingScreen> with SingleTickerProviderStateMixin {
  String _currentStep = 'Authenticating...';
  double _progress = 0.0;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _startSync();
  }

  Future<void> _startSync() async {
    // Initial delay so the transition feels smooth
    await Future.delayed(const Duration(milliseconds: 400));
    
    if (mounted) {
      setState(() => _currentStep = 'Verifying Subscription...');
    }

    try {
      final lib = await supabase
          .from('libraries')
          .select('subscription_status, subscription_end, name, phone')
          .eq('id', widget.libraryId)
          .single();

      subscriptionStatus = lib['subscription_status'];
      subscriptionEnd = DateTime.parse(lib['subscription_end']);
      libraryName = lib['name'];
      libraryPhone = lib['phone'] ?? '';
    } catch (e) {
      debugPrint('Subscription fetch error: $e');
    }

    if (mounted) {
      setState(() => _currentStep = 'Connecting Database...');
    }

    final sync = SyncService(libraryId: widget.libraryId);

    await sync.fullSync(
      onProgress: (step, progress) {
        if (mounted) {
          setState(() {
            _currentStep = step;
            _progress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _currentStep = 'Entering LibraryOS';
        _progress = 1.0;
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const OwnerShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        )
      );
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Widget _buildBlob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
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

          return Stack(
            children: [
              Positioned(
                top: -100 + (sinVal * 40),
                right: -100 + (cosVal * 30),
                child: _buildBlob(500, const Color(0xFF1E293B), 0.2), // Slate 800
              ),
              Positioned(
                bottom: -50 + (sinVal * -60),
                left: -150 + (sinVal * 40),
                child: _buildBlob(400, const Color(0xFF6366F1), 0.15), // Indigo
              ),
              Positioned(
                 top: 200 + (cosVal * 50),
                 right: -50 + (sinVal * -30),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium 3D Glass Loader Card
                  AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, child) {
                      double pulse = (math.sin(_bgController.value * math.pi * 4) + 1) / 2;
                      return Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.2 + (0.1 * pulse)),
                              blurRadius: 40 + (20 * pulse),
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                           borderRadius: BorderRadius.circular(16),
                           child: Stack(
                              alignment: Alignment.center,
                              children: [
                                 BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                    child: Container(color: Colors.transparent),
                                 ),
                                 SizedBox(
                                    width: 80, height: 80,
                                    child: CircularProgressIndicator(
                                      value: _progress > 0 ? _progress : null,
                                      strokeWidth: 6,
                                      strokeCap: StrokeCap.round,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                    ),
                                 ),
                                 Icon(
                                    _progress >= 1.0 ? Icons.check_circle_rounded : Icons.auto_awesome_rounded, 
                                    color: Colors.white, 
                                    size: 32
                                 ),
                              ],
                           ),
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 50),
                  
                  // Animated Step Indicator
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                       return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                             position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                             child: child,
                          )
                       );
                    },
                    child: Column(
                      key: ValueKey<String>(_currentStep),
                      children: [
                        Text(
                          _currentStep,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                           decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
                           ),
                           child: Text(
                             '${(_progress * 100).toInt()}% COMPLETED',
                             style: GoogleFonts.plusJakartaSans(
                               fontSize: 12,
                               fontWeight: FontWeight.w800,
                               color: const Color(0xFF818CF8),
                               letterSpacing: 1.5
                             ),
                           ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Footer Tip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_sync_rounded, size: 18, color: Colors.white54),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Encrypting and syncing your workspace',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
