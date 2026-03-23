import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/registration_form_data.dart';

class Step3Shifts extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step3Shifts({super.key, required this.onNext, required this.onBack});

  @override
  State<Step3Shifts> createState() => _Step3State();
}

class _Step3State extends State<Step3Shifts> with SingleTickerProviderStateMixin {
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

  Future<void> _selectTime(int index, bool isStart) async {
    final currentStr = isStart ? formData.shifts[index]['start_time']! : formData.shifts[index]['end_time']!;
    final parts = currentStr.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            primaryColor: const Color(0xFF6366F1),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isStart) {
          formData.shifts[index]['start_time'] = formatted;
        } else {
          formData.shifts[index]['end_time'] = formatted;
        }
      });
    }
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final tod = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final ampm = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')} $ampm';
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
                'Shift Timings', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Define your operational hours', 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, 
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              ...formData.shifts.asMap().entries.map((entry) => _buildShiftCard(entry.key, entry.value)),

              const SizedBox(height: 48),

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

  Widget _buildShiftCard(int index, Map<String, String> shift) {
    final Map<String, dynamic> metadata = {
      'Morning': {'emoji': '🌅', 'color': Colors.orangeAccent},
      'Afternoon': {'emoji': '☀️', 'color': Colors.amber},
      'Evening': {'emoji': '🌆', 'color': Colors.deepOrangeAccent},
      'Night': {'emoji': '🌙', 'color': Colors.indigoAccent},
    };

    final meta = metadata[shift['name']]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: const [
           BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: meta['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(meta['emoji'], style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Text(
                shift['name']!, 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, 
                  fontWeight: FontWeight.w700, 
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildTimeBox('Starts at', shift['start_time']!, () => _selectTime(index, true))),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeBox('Ends at', shift['end_time']!, () => _selectTime(index, false))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String label, String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text(
                  _formatTime(time), 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, 
                    fontWeight: FontWeight.w700, 
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
