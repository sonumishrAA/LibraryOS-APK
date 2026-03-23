import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'login_screen.dart';
import 'package:libraryos/screens/registration/registration_navigator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _continuousController;
  Timer? _autoTimer;
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _cards = [
    {
      'hook': 'Live Seat Map & Occupancy',
      'sub': 'View vacant vs filled seats, active students, and expiry dates at a glance.',
      'color': const Color(0xFF6366F1), // Indigo
      'color2': const Color(0xFF4F46E5),
    },
    {
      'hook': 'Smart Financial Calendar',
      'sub': 'Track revenue streams, monitor daily collections, and forecast your library earnings.',
      'color': const Color(0xFF10B981), // Emerald
      'color2': const Color(0xFF059669),
    },
    {
      'hook': 'Student Expiry Tracking',
      'sub': 'Know exactly which student\'s seat is expiring and in how many days. Never miss a renewal.',
      'color': const Color(0xFFF43F5E), // Rose
      'color2': const Color(0xFFE11D48),
    },
    {
      'hook': 'Inventory & Policy Control',
      'sub': 'Change seat inventory, locker policies, and pricing with instant notifications for all changes.',
      'color': const Color(0xFFF59E0B), // Amber
      'color2': const Color(0xFFD97706),
    },
  ];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat(reverse: true);
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _continuousController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    
    _startAutoTimer();
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _cards.length;
        });
      }
    });
  }

  void _nextCard() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _cards.length;
    });
    _startAutoTimer();
  }

  void _prevCard() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _cards.length) % _cards.length;
    });
    _startAutoTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _bgController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
    _continuousController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          
          SafeArea(
            child: Column(
              children: [
                _buildPremiumTopBar(),
                
                Expanded(
                  child: GestureDetector(
                    onPanEnd: (details) {
                      if (details.velocity.pixelsPerSecond.dx > 300 || details.velocity.pixelsPerSecond.dy > 300) {
                        _prevCard();
                      } else if (details.velocity.pixelsPerSecond.dx < -300 || details.velocity.pixelsPerSecond.dy < -300) {
                        _nextCard();
                      }
                    },
                    child: _buildInPlaceFeatureCard(),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: _buildPageIndicator(),
                ),
                
                _buildModernBottomCTA(),
              ],
            ),
          ),
        ],
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
                child: _buildBlob(500, const Color(0xFF1E293B), 0.2),
              ),
              Positioned(
                top: 200 + (cosVal * 50),
                left: -150 + (sinVal * 40),
                child: _buildBlob(400, const Color(0xFF4F46E5), 0.15),
              ),
              Positioned(
                bottom: -50 + (sinVal * -60),
                right: -100 + (cosVal * -50),
                child: _buildBlob(450, const Color(0xFF312E81), 0.15),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }

  Widget _buildInPlaceFeatureCard() {
    final card = _cards[_currentIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final val = _floatController.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: card['color'].withOpacity(0.1 + (0.05 * val)),
                  blurRadius: 60 + (20 * val),
                  offset: Offset(0, 20 + (10 * val)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -50,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      width: 250, height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: card['color'].withOpacity(0.15),
                      ),
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(color: Colors.transparent),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.05),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey<int>(_currentIndex),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 4,
                            child: AnimatedBuilder(
                              animation: _continuousController,
                              builder: (context, child) {
                                return Center(
                                  child: _buildCardVisual(_currentIndex, _continuousController.value, card),
                                );
                              }
                            ),
                          ),
                          
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: card['color'].withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: card['color'].withOpacity(0.5))
                                  ),
                                  child: Text('FEATURE 0${_currentIndex+1}', style: GoogleFonts.plusJakartaSans(color: card['color'], fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  card['hook'],
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  card['sub'],
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
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
            ),
          );
        }
      ),
    );
  }

  Widget _buildCardVisual(int index, double cVal, Map<String, dynamic> card) {
    switch (index) {
      case 0: return _buildSeatMapVisual(cVal, card);
      case 1: return _buildFinancialCalendarVisual(cVal, card);
      case 2: return _buildExpiryTrackingVisual(cVal, card);
      case 3: return _buildControlPanelVisual(cVal, card);
      default: return const SizedBox();
    }
  }

  Widget _buildSeatMapVisual(double cVal, Map<String, dynamic> card) {
    final matrix = Matrix4.identity()
       ..setEntry(3, 2, 0.001)
       ..rotateX(0.8)
       ..rotateZ(0.5);

    return Transform.scale(
      scale: 0.85,
      child: Transform(
        transform: matrix,
        alignment: FractionalOffset.center,
        child: Wrap(
           spacing: 12, runSpacing: 12,
           alignment: WrapAlignment.center,
           children: List.generate(9, (i) {
              double pulse = (math.sin(cVal * 2 * math.pi + i) + 1) / 2;
              bool isTaken = i == 2 || i == 5 || i == 7;
              bool isExpiring = i == 2;
              Color baseColor = isTaken ? (isExpiring ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)) : card['color'];
              return Container(
                 width: 45, height: 45,
                 decoration: BoxDecoration(
                   color: baseColor.withOpacity(0.3 + 0.5 * pulse),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: baseColor, width: 2),
                   boxShadow: [
                      BoxShadow(color: baseColor.withOpacity(pulse * 0.6), blurRadius: 15 * pulse)
                   ]
                 ),
                 child: Center(
                   child: isTaken 
                     ? (isExpiring 
                         ? const Icon(Icons.timer_outlined, color: Colors.white, size: 20) 
                         : const Icon(Icons.person, color: Colors.white54, size: 20))
                     : const Icon(Icons.event_seat_rounded, color: Colors.white, size: 20)
                 ),
              );
           }),
        ),
      ),
    );
  }

  Widget _buildFinancialCalendarVisual(double cVal, Map<String, dynamic> card) {
    return Transform.scale(
      scale: 0.85,
      child: Stack(
         clipBehavior: Clip.none,
         alignment: Alignment.center,
         children: [
            Container(
              width: 170, height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: card['color'].withOpacity(0.2), blurRadius: 40)],
              ),
              child: Column(
                children: [
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: card['color'].withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: card['color'].withOpacity(0.3))),
                    ),
                    child: Center(child: Text("Mar 2026", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(24, (i) {
                          double pulse = i % 5 == 0 ? (math.sin(cVal * 2 * math.pi + i) + 1) / 2 : 0;
                          return Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: i % 7 == 0 ? Colors.white.withOpacity(0.02) : (i % 5 == 0 ? card['color'].withOpacity(0.4 + 0.6 * pulse) : Colors.white.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      )
                    )
                  )
                ]
              )
            ),
            Positioned(
              bottom: -20,
              right: -20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 10))]
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Text('+12,500', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                )
              )
            )
         ]
      ),
    );
  }

  Widget _buildExpiryTrackingVisual(double cVal, Map<String, dynamic> card) {
    return Transform.scale(
      scale: 0.85,
      child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           _buildStudentRow('Rahul Kumar', 'Expires in 2 days', 0.95, cVal, card['color']),
           const SizedBox(height: 12),
           _buildStudentRow('Priya Singh', 'Expires tomorrow', 1.05, cVal + 0.3, const Color(0xFFF59E0B)),
           const SizedBox(height: 12),
           _buildStudentRow('Amit Patel', 'Expired yesterday', 1.0, cVal + 0.6, const Color(0xFFEF4444)),
         ],
       ),
    );
  }

  Widget _buildStudentRow(String name, String sub, double scale, double cVal, Color color) {
    double slide = 5 * math.sin(cVal * math.pi * 2);
    return Transform.scale(
      scale: scale,
      child: Transform.translate(
        offset: Offset(slide, 0),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
          ),
          child: Row(
            children: [
               Container(
                 width: 32, height: 32,
                 decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                 child: Icon(Icons.person, color: color, size: 16),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(name, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 2),
                     Text(sub, style: GoogleFonts.plusJakartaSans(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                   ],
                 ),
               ),
               const SizedBox(width: 8),
               Icon(Icons.warning_amber_rounded, color: color, size: 18),
            ]
          )
        ),
      ),
    );
  }

  Widget _buildControlPanelVisual(double cVal, Map<String, dynamic> card) {
    double pulse = (math.sin(cVal * math.pi * 2) + 1) / 2;
    return Transform.scale(
      scale: 0.9,
      child: Stack(
         clipBehavior: Clip.none,
         alignment: Alignment.center,
         children: [
           Container(
             width: 180, height: 160,
             padding: const EdgeInsets.all(18),
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.05),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Colors.white.withOpacity(0.1)),
               boxShadow: [BoxShadow(color: card['color'].withOpacity(0.15), blurRadius: 30)],
             ),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.spaceAround,
               children: [
                 _buildSettingToggle('Seat Inventory', true, card['color']),
                 _buildSettingToggle('Locker Policy', false, card['color']),
                 _buildSettingToggle('Pricing Tiers', true, card['color']),
               ],
             ),
           ),
           Positioned(
             top: -20, right: -20,
             child: Transform.translate(
               offset: Offset(0, -6 * pulse),
               child: Container(
                 padding: const EdgeInsets.all(14),
                 decoration: BoxDecoration(
                   color: card['color'],
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(color: card['color'].withOpacity(0.6), blurRadius: 20 * pulse, offset: const Offset(0, 10))
                   ]
                 ),
                 child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
               ),
             ),
           ),
         ]
      ),
    );
  }

  Widget _buildSettingToggle(String title, bool isOn, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w700)),
        Container(
          width: 36, height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isOn ? color : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Align(
            alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildModernBottomCTA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final val = _floatController.value;
              return Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4 + (0.3 * val)), 
                      blurRadius: 20 + (10 * val), 
                      offset: const Offset(0, 8)
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationNavigator())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('REGISTER YOUR LIBRARY', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              );
            }
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Text('ALREADY AN OWNER? LOGIN', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_cards.length, (index) {
        bool isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isActive ? 1.0 : 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildPremiumTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.local_library, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Text(
            'LibraryOS',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              'v2.0 PRO',
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
