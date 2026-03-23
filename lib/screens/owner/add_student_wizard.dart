import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../constants.dart';
import '../../globals.dart';
import '../../services/cache_service.dart';

class AddStudentWizard extends StatefulWidget {
  final Map? renewStudent;
  const AddStudentWizard({super.key, this.renewStudent});

  @override
  State<AddStudentWizard> createState() => _AddStudentWizardState();
}

class _AddStudentWizardState extends State<AddStudentWizard>
    with SingleTickerProviderStateMixin {
  bool get isRenew => widget.renewStudent != null;
  int _currentStep = 0;
  bool _isBusy = false;
  bool _isDataLoading = true;

  // Data from DB
  List<dynamic> _allSeats = [];
  List<dynamic> _allLockers = [];
  Map<String, dynamic>? _lockerPolicy;
  List<dynamic> _comboPricing = [];
  bool _isGenderNeutral = false;

  // Step 1: Info
  final _nameController = TextEditingController();
  final _fatherController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedGender = 'M';

  // Step 2: Seat
  List<String> _selectedShifts = [];
  String? _selectedSeatId;
  String _comboKey = '';
  List<dynamic> _occupiedShifts = [];
  String? _selectedLockerId;

  // Step 3: Plan & Dates
  int _selectedMonths = 1;
  DateTime _admissionDate = DateTime.now();
  late DateTime _endDate;
  double _baseFee = 0;
  double _lockerFeeTotal = 0;
  double _totalFee = 0;
  double _amountPaid = 0;
  double _discountAmount = 0;
  bool _hasDiscount = false;
  bool _isFullPending = false;
  bool _isFullPaid = false;
  String _paymentMode = 'cash';
  final _amountPaidController = TextEditingController();
  final _discountController = TextEditingController();

  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    _recalcEndDate();
    if (isRenew) {
      _currentStep = 1;
      _prefillRenewData();
    }
    _fetchInitialData();
  }

  void _prefillRenewData() {
    final s = widget.renewStudent!;
    _nameController.text = s['name'] ?? '';
    _fatherController.text = s['father_name'] ?? '';
    _addressController.text = s['address'] ?? '';
    _phoneController.text = s['phone'] ?? '';
    _selectedGender = s['gender'] ?? 'M';
    _selectedShifts = List<String>.from(s['selected_shifts'] ?? []);
    _selectedSeatId = s['seat_id'];
    _comboKey = s['combination_key'] ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nameController.dispose();
    _fatherController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _amountPaidController.dispose();
    _discountController.dispose();
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
                child: _buildBlob(500, const Color(0xFF1E293B), 0.3),
              ),
              Positioned(
                bottom: -50 + (sinVal * -60),
                left: -150 + (sinVal * 40),
                child: _buildBlob(400, const Color(0xFF6366F1), 0.2),
              ),
              Positioned(
                top: 200 + (cosVal * 50),
                right: -50 + (sinVal * -30),
                child: _buildBlob(350, const Color(0xFF10B981), 0.15),
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

  Future<void> _fetchInitialData() async {
    setState(() => _isDataLoading = true);
    try {
      final seatsResult = await supabase
          .from('seats')
          .select('id, seat_number, gender')
          .eq('library_id', currentLibraryId)
          .eq('is_active', true);
      _allSeats = List<Map<String, dynamic>>.from(seatsResult);

      final seatIds = _allSeats.map((s) => s['id'] as String).toList();
      if (seatIds.isNotEmpty) {
        final occupiedResult = await supabase
            .from('student_seat_shifts')
            .select(
              'seat_id, shift_code, student_id, students!inner(is_deleted)',
            )
            .inFilter('seat_id', seatIds)
            .eq('students.is_deleted', false);
        _occupiedShifts = List<Map<String, dynamic>>.from(occupiedResult);
      } else {
        _occupiedShifts = [];
      }

      _allSeats.sort((a, b) {
        final numA =
            int.tryParse(
              a['seat_number'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        final numB =
            int.tryParse(
              b['seat_number'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        return numA.compareTo(numB);
      });

      final others = await Future.wait<dynamic>([
        supabase
            .from('lockers')
            .select('id, locker_number, gender, status')
            .eq('library_id', currentLibraryId),
        supabase
            .from('locker_policies')
            .select('eligible_combos, monthly_fee')
            .eq('library_id', currentLibraryId)
            .maybeSingle(),
        supabase
            .from('combo_plans')
            .select('id, combination_key, months, fee')
            .eq('library_id', currentLibraryId),
        supabase
            .from('libraries')
            .select('is_gender_neutral')
            .eq('id', currentLibraryId)
            .single(),
      ]);

      if (mounted) {
        setState(() {
          _allLockers = others[0] as List;
          _lockerPolicy = others[1] as Map<String, dynamic>?;
          _comboPricing = others[2] as List;
          _isGenderNeutral = (others[3] as Map)['is_gender_neutral'] ?? false;
          _isDataLoading = false;

          if (_comboKey.isNotEmpty) {
            _updatePricing();
          }
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  // ── KEY FIX: update baseFee from comboPricing whenever month or combo changes ──
  void _updatePricing() {
    final plan = _comboPricing.firstWhereOrNull(
      (p) =>
          p['combination_key'] == _comboKey && p['months'] == _selectedMonths,
    );
    setState(() {
      _baseFee = plan != null ? (plan['fee'] ?? 0).toDouble() : 0;
      _calculateTotal();
    });
  }

  void _onShiftToggle(String code) {
    setState(() {
      if (_selectedShifts.contains(code)) {
        _selectedShifts.remove(code);
      } else {
        _selectedShifts.add(code);
      }
      final order = ['M', 'A', 'E', 'N'];
      final sorted = _selectedShifts.toList()
        ..sort((a, b) => order.indexOf(a) - order.indexOf(b));
      _comboKey = sorted.join();
      _selectedSeatId = null;
      _selectedLockerId = null;
      _updatePricing();
    });
  }

  Future<void> _pickAdmissionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _admissionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1A237E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _admissionDate = picked;
        _recalcEndDate();
      });
    }
  }

  void _recalcEndDate() {
    setState(() {
      _endDate = DateTime(
        _admissionDate.year,
        _admissionDate.month + _selectedMonths,
        _admissionDate.day,
      );
    });
  }

  void _calculateTotal() {
    _lockerFeeTotal = _selectedLockerId != null
        ? ((_lockerPolicy?['monthly_fee'] as num? ?? 200).toDouble() *
              _selectedMonths)
        : 0.0;
    _totalFee = _baseFee + _lockerFeeTotal;
    if (_isFullPaid) {
      _amountPaid = _effectiveAmount;
    }
    _amountPaidController.text = _amountPaid.toInt().toString();
  }

  double get _effectiveAmount =>
      (_totalFee - _discountAmount).clamp(0, double.infinity);
  double get _balanceDue =>
      (_effectiveAmount - _amountPaid).clamp(0, double.infinity);

  String get _dbStatus {
    if (_balanceDue == 0 && (_amountPaid > 0 || _discountAmount >= _totalFee))
      return 'paid';
    if (_amountPaid == 0 && _discountAmount == 0) return 'pending';
    if (_amountPaid == 0 && _discountAmount > 0 && _balanceDue > 0)
      return 'discounted';
    return 'partial';
  }

  String get _displayStatus =>
      (_dbStatus == 'paid' && _discountAmount > 0) ? 'paid*' : _dbStatus;

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return iso;
    }
  }

  String _buildNote() {
    return '${_comboKey}-${_selectedMonths}m | '
        'orig:${_totalFee.toInt()} | '
        'disc:${_discountAmount.toInt()} | '
        'admission_date:${_admissionDate.toIso8601String().split('T')[0]} | '
        '${isRenew ? "Renewal" : "New admission"}';
  }

  String _buildNotifMessage() =>
      'Shifts: ${_selectedShifts.join("+")} | '
      '${_selectedMonths}m | Seat ${_allSeats.firstWhereOrNull((s) => s['id'] == _selectedSeatId)?['seat_number'] ?? ""} | '
      'Total ₹${_totalFee.toInt()} | '
      'Paid ₹${_amountPaid.toInt()} | '
      '${_balanceDue > 0 ? "Pending ₹${_balanceDue.toInt()}" : "Cleared"} | '
      'By $currentUserName ($currentRole)';

  List<Map<String, dynamic>> get _displaySeats {
    return List<Map<String, dynamic>>.from(
      _allSeats.where((seat) {
        if (!_isGenderNeutral) {
          if (seat['gender'] != 'neutral' && seat['gender'] != _selectedGender)
            return false;
        }
        return true;
      }),
    );
  }

  bool _canSelectSeat(String seatId) {
    if (_selectedShifts.isEmpty) return false;
    return _selectedShifts.every((shift) => !_isShiftOccupied(seatId, shift));
  }

  bool _isShiftOccupied(String seatId, String shift) {
    return _occupiedShifts.any((o) {
      if (o['seat_id'] != seatId || o['shift_code'] != shift) return false;
      if (isRenew && o['student_id'] == widget.renewStudent?['id'])
        return false;
      return true;
    });
  }

  Future<void> _submit() async {
    if (_isBusy) return;
    if (isRenew) {
      await _submitRenewal();
    } else {
      await _submitNewAdmission();
    }
  }

  Future<void> _submitNewAdmission() async {
    setState(() => _isBusy = true);
    try {
      final admissionDateStr = _admissionDate.toIso8601String().split('T')[0];
      final endDateStr = _endDate.toIso8601String().split('T')[0];
      final status = _dbStatus;

      final studentRes = await supabase
          .from('students')
          .insert({
            'library_id': currentLibraryId,
            'name': _nameController.text.trim(),
            'father_name': _fatherController.text.trim().isEmpty
                ? null
                : _fatherController.text.trim(),
            'address': _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'gender': _selectedGender,
            'seat_id': _selectedSeatId,
            'locker_id': _selectedLockerId,
            'combination_key': _comboKey,
            'shift_display': _comboKey,
            'selected_shifts': _selectedShifts.toList(),
            'admission_date': admissionDateStr,
            'end_date': endDateStr,
            'plan_months': _selectedMonths,
            'total_fee': _totalFee,
            'monthly_rate': _totalFee / _selectedMonths,
            'amount_paid': _amountPaid,
            'discount_amount': _discountAmount,
            'payment_status': status,
          })
          .select()
          .single();

      await CacheService.onStudentAdded(studentRes);
      final studentId = studentRes['id'];

      await supabase
          .from('student_seat_shifts')
          .insert(
            _selectedShifts
                .map(
                  (s) => {
                    'student_id': studentId,
                    'seat_id': _selectedSeatId,
                    'shift_code': s,
                    'end_date': endDateStr,
                  },
                )
                .toList(),
          );

      await CacheService.onSeatShiftsAdded(
        _selectedShifts
            .map(
              (s) => {
                'student_id': studentId,
                'seat_id': _selectedSeatId,
                'shift_code': s,
                'end_date': endDateStr,
              },
            )
            .toList(),
      );

      if (_selectedLockerId != null) {
        await supabase
            .from('lockers')
            .update({'status': 'occupied'})
            .eq('id', _selectedLockerId!);
        await CacheService.onLockerUpdated(_selectedLockerId!, 'occupied');
      }

      if (_amountPaid > 0) {
        final paymentRes = await supabase
            .from('payment_records')
            .insert({
              'library_id': currentLibraryId,
              'student_id': studentId,
              'amount': _amountPaid,
              'payment_method': _paymentMode,
              'type': 'admission',
              'received_by': supabase.auth.currentUser!.id,
            })
            .select()
            .single();
        await CacheService.onPaymentRecordAdded(paymentRes);
      }

      String eventType = 'ADMISSION_PENDING';
      if (status == 'paid')
        eventType = 'ADMISSION_FULL';
      else if (status == 'partial')
        eventType = 'ADMISSION_PARTIAL';

      final eventRes = await supabase
          .from('financial_events')
          .insert({
            'library_id': currentLibraryId,
            'student_id': studentId,
            'student_name': _nameController.text,
            'event_type': eventType,
            'amount': _amountPaid,
            'pending_amount': _balanceDue,
            'payment_mode': _paymentMode,
            'actor_role': currentRole,
            'actor_name': currentUserName,
            'note': _buildNote(),
          })
          .select()
          .single();
      await CacheService.onFinancialEventAdded(eventRes);

      if (_discountAmount > 0) {
        final discRes = await supabase
            .from('financial_events')
            .insert({
              'library_id': currentLibraryId,
              'student_id': studentId,
              'student_name': _nameController.text,
              'event_type': 'DISCOUNT_APPLIED',
              'amount': _discountAmount,
              'pending_amount': _balanceDue,
              'payment_mode': _paymentMode,
              'actor_role': currentRole,
              'actor_name': currentUserName,
              'note':
                  'Discount ₹${_discountAmount.toInt()} applied at admission',
            })
            .select()
            .single();
        await CacheService.onFinancialEventAdded(discRes);
      }

      final notifRes = await supabase
          .from('notifications')
          .insert({
            'library_id': currentLibraryId,
            'student_id': studentId,
            'type': 'new_admission',
            'title': 'New Admission — ${_nameController.text}',
            'message': _buildNotifMessage(),
            'is_read': false,
          })
          .select()
          .single();
      await CacheService.onNotificationAdded(notifRes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student admitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to admit student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitRenewal() async {
    setState(() => _isBusy = true);
    try {
      final studentId = widget.renewStudent!['id'];
      final admissionDateStr = _admissionDate.toIso8601String().split('T')[0];
      final endDateStr = _endDate.toIso8601String().split('T')[0];
      final status = _dbStatus;

      final updated = await supabase
          .from('students')
          .update({
            'seat_id': _selectedSeatId,
            'combination_key': _comboKey,
            'shift_display': _comboKey,
            'selected_shifts': _selectedShifts,
            'admission_date': admissionDateStr,
            'end_date': endDateStr,
            'plan_months': _selectedMonths,
            'total_fee': _totalFee,
            'monthly_rate': _totalFee / _selectedMonths,
            'amount_paid': _amountPaid,
            'discount_amount': _discountAmount,
            'payment_status': status,
            'is_deleted': false,
          })
          .eq('id', studentId)
          .select()
          .single();

      await supabase
          .from('student_seat_shifts')
          .delete()
          .eq('student_id', studentId);

      final newShifts = _selectedShifts
          .map(
            (s) => {
              'student_id': studentId,
              'seat_id': _selectedSeatId,
              'shift_code': s,
              'end_date': endDateStr,
            },
          )
          .toList();
      await supabase.from('student_seat_shifts').insert(newShifts);

      if (_amountPaid > 0) {
        final paymentRes = await supabase
            .from('payment_records')
            .insert({
              'library_id': currentLibraryId,
              'student_id': studentId,
              'amount': _amountPaid,
              'payment_method': _paymentMode,
              'type': 'renewal',
              'received_by': supabase.auth.currentUser!.id,
            })
            .select()
            .single();
        await CacheService.onPaymentRecordAdded(paymentRes);
      }

      String eventType = 'ADMISSION_PENDING';
      if (status == 'paid')
        eventType = 'ADMISSION_FULL';
      else if (status == 'partial')
        eventType = 'ADMISSION_PARTIAL';

      final eventRes = await supabase
          .from('financial_events')
          .insert({
            'library_id': currentLibraryId,
            'student_id': studentId,
            'student_name': _nameController.text,
            'event_type': eventType,
            'amount': _amountPaid,
            'pending_amount': _balanceDue,
            'payment_mode': _paymentMode,
            'actor_role': currentRole,
            'actor_name': currentUserName,
            'note': _buildNote(),
          })
          .select()
          .single();
      await CacheService.onFinancialEventAdded(eventRes);

      if (_discountAmount > 0) {
        final discRes = await supabase
            .from('financial_events')
            .insert({
              'library_id': currentLibraryId,
              'student_id': studentId,
              'student_name': _nameController.text,
              'event_type': 'DISCOUNT_APPLIED',
              'amount': _discountAmount,
              'pending_amount': _balanceDue,
              'payment_mode': _paymentMode,
              'actor_role': currentRole,
              'actor_name': currentUserName,
              'note':
                  'Discount ₹${_discountAmount.toInt()} applied at renewal | admission_date:$admissionDateStr',
            })
            .select()
            .single();
        await CacheService.onFinancialEventAdded(discRes);
      }

      final notifRes = await supabase
          .from('notifications')
          .insert({
            'library_id': currentLibraryId,
            'student_id': studentId,
            'type': 'student_renewed',
            'title': 'Renewal — ${_nameController.text}',
            'message': _buildNotifMessage(),
            'is_read': false,
          })
          .select()
          .single();
      await CacheService.onNotificationAdded(notifRes);

      await CacheService.onStudentUpdated(updated);
      await CacheService.onSeatShiftsDeleted(studentId);
      await CacheService.onSeatShiftsAdded(newShifts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admission renewed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Renewal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to renew admission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isRenew ? 'Renew Admission' : 'New Admission',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: _isDataLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : Column(
                    children: [
                      _buildProgressHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          physics: const BouncingScrollPhysics(),
                          child: _buildStepContent(),
                        ),
                      ),
                      _buildBottomActions(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepDot(1, _currentStep >= 0, disabled: isRenew),
          _stepLine(0),
          _stepDot(2, _currentStep >= 1),
          _stepLine(1),
          _stepDot(3, _currentStep >= 2),
        ],
      ),
    );
  }

  Widget _stepDot(int step, bool active, {bool disabled = false}) {
    final glow = active
        ? [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ]
        : null;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: disabled
            ? Colors.white.withOpacity(0.05)
            : active
            ? const Color(0xFF6366F1)
            : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        boxShadow: glow,
        border: Border.all(
          color: disabled
              ? Colors.transparent
              : active
              ? const Color(0xFF818CF8)
              : Colors.white.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: disabled
                ? Colors.white24
                : active
                ? Colors.white
                : Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _stepLine(int afterStep) {
    bool active = _currentStep > afterStep;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: active ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildStepContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Builder(
            builder: (ctx) {
              switch (_currentStep) {
                case 0:
                  return _buildStep1();
                case 1:
                  return _buildStep2();
                case 2:
                  return _buildStep3();
                default:
                  return const SizedBox();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoField('Student Name*', _nameController, Icons.person_outline),
        _infoField(
          'Father Name',
          _fatherController,
          Icons.family_restroom_outlined,
        ),
        _infoField('Address', _addressController, Icons.location_on_outlined),
        _infoField(
          'Phone*',
          _phoneController,
          Icons.phone_outlined,
          keyboard: TextInputType.phone,
          maxLength: 10,
        ),
        const SizedBox(height: 24),
        Text(
          'GENDER*',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _genderChip('male', Icons.male),
            const SizedBox(width: 12),
            _genderChip('female', Icons.female),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final bool isEligibleForLocker =
        _lockerPolicy != null &&
        (List<String>.from(
          _lockerPolicy!['eligible_combos'] ?? [],
        ).contains(_comboKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT SHIFTS*',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['M', 'A', 'E', 'N'].map((s) => _shiftChip(s)).toList(),
        ),
        const SizedBox(height: 32),
        Text(
          'SEAT ASSIGNMENT*',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildSeatSelector(),
        if (isEligibleForLocker) ...[
          const SizedBox(height: 32),
          Text(
            'LOCKER ASSIGNMENT',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildLockerSelector(),
        ],
      ],
    );
  }

  Widget _buildStep3() {
    // Available months from combo pricing for this combo
    final availableMonths =
        _comboPricing
            .where((c) => c['combination_key'] == _comboKey)
            .map<int>((c) => c['months'] as int)
            .toSet()
            .toList()
          ..sort();

    // Auto-select first month if current selection not available
    if (availableMonths.isNotEmpty &&
        !availableMonths.contains(_selectedMonths)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedMonths = availableMonths.first;
          _updatePricing();
          _recalcEndDate();
        });
      });
    }

    _calculateTotal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLAN DURATION*',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        availableMonths.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'No plans configured for combo "$_comboKey". Please add plans in Settings → Plans & Pricing.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.red.shade300,
                    fontSize: 13,
                  ),
                ),
              )
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: availableMonths.map((m) => _monthChip(m)).toList(),
              ),
        const SizedBox(height: 32),
        Text(
          'ADMISSION DATE*',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickAdmissionDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.04),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDate(_admissionDate.toIso8601String()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF818CF8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admission',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  Text(
                    _formatDate(_admissionDate.toIso8601String()),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, size: 16, color: Colors.white38),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'End Date',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  Text(
                    _formatDate(_endDate.toIso8601String()),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'FEE SUMMARY',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeeCard(),
        const SizedBox(height: 32),
        Row(
          children: [
            Checkbox(
              value: _hasDiscount,
              onChanged: (v) => setState(() {
                _hasDiscount = v ?? false;
                if (!_hasDiscount) {
                  _discountAmount = 0;
                  _discountController.clear();
                  if (_isFullPaid) _amountPaid = _effectiveAmount;
                  _amountPaidController.text = _amountPaid.toStringAsFixed(0);
                }
              }),
              activeColor: const Color(0xFF6366F1),
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            Text(
              'ADD DISCOUNT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF818CF8),
              ),
            ),
          ],
        ),
        if (_hasDiscount) ...[
          const SizedBox(height: 8),
          _infoField(
            'DISCOUNT (₹)',
            _discountController,
            Icons.tag_rounded,
            keyboard: TextInputType.number,
            onChanged: (v) {
              final val = double.tryParse(v) ?? 0;
              if (val > _totalFee) {
                _discountController.text = _totalFee.toStringAsFixed(0);
                _discountController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _discountController.text.length),
                );
              }
              setState(() {
                _discountAmount =
                    double.tryParse(_discountController.text) ?? 0;
                if (_isFullPaid)
                  _amountPaid = _effectiveAmount;
                else if (_isFullPending)
                  _amountPaid = 0;
                _amountPaidController.text = _amountPaid.toStringAsFixed(0);
              });
            },
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EFFECTIVE AMOUNT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34D399),
                  ),
                ),
                Text(
                  '₹${_effectiveAmount.toInt()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        _infoField(
          'AMOUNT PAID (₹)',
          _amountPaidController,
          Icons.currency_rupee_rounded,
          keyboard: TextInputType.number,
          enabled: !_isFullPaid && !_isFullPending,
          onChanged: (v) {
            final val = double.tryParse(v) ?? 0;
            if (val > _effectiveAmount) {
              _amountPaidController.text = _effectiveAmount.toStringAsFixed(0);
              _amountPaidController.selection = TextSelection.fromPosition(
                TextPosition(offset: _amountPaidController.text.length),
              );
            }
            setState(
              () => _amountPaid =
                  double.tryParse(_amountPaidController.text) ?? 0,
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Checkbox(
                    value: _isFullPending,
                    onChanged: (v) => setState(() {
                      _isFullPending = v ?? false;
                      if (_isFullPending) {
                        _isFullPaid = false;
                        _amountPaid = 0;
                        _amountPaidController.text = '0';
                      }
                    }),
                    activeColor: const Color(0xFFEF4444),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  Text(
                    'FULL PENDING',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Checkbox(
                    value: _isFullPaid,
                    onChanged: (v) => setState(() {
                      _isFullPaid = v ?? false;
                      if (_isFullPaid) {
                        _isFullPending = false;
                        _amountPaid = _effectiveAmount;
                        _amountPaidController.text = _amountPaid
                            .toStringAsFixed(0);
                      }
                    }),
                    activeColor: const Color(0xFF10B981),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  Text(
                    'FULL PAID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _statusColor().withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _displayStatus.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _statusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'BALANCE DUE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_balanceDue.toInt()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _balanceDue > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'PAYMENT MODE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentModeToggle(),
      ],
    );
  }

  Color _statusColor() {
    switch (_dbStatus) {
      case 'paid':
        return const Color(0xFF10B981);
      case 'discounted':
        return const Color(0xFF8B5CF6);
      case 'partial':
        return const Color(0xFF3B82F6);
      case 'pending':
        return const Color(0xFFEF4444);
      default:
        return Colors.white54;
    }
  }

  Widget _infoField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int? maxLength,
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            maxLength: maxLength,
            onChanged: onChanged,
            enabled: enabled,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: enabled ? Colors.white : Colors.white38,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: Colors.white54),
              filled: true,
              fillColor: enabled
                  ? Colors.white.withOpacity(0.04)
                  : Colors.white.withOpacity(0.02),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.02)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderChip(String g, IconData icon) {
    bool active = _selectedGender == g;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = g),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF6366F1).withOpacity(0.2)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFF818CF8)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? Colors.white : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                g.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: active ? Colors.white : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftChip(String s) {
    bool active = _selectedShifts.contains(s);
    return GestureDetector(
      onTap: () => _onShiftToggle(s),
      child: Container(
        width: 65,
        height: 65,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6366F1).withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF818CF8)
                : Colors.white.withOpacity(0.08),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          s,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildSeatSelector() {
    final seat = _allSeats.firstWhereOrNull((s) => s['id'] == _selectedSeatId);
    return InkWell(
      onTap: () => _showSeatPicker(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.airline_seat_recline_normal_rounded,
              color: Colors.white54,
            ),
            const SizedBox(width: 12),
            Text(
              seat == null ? 'Select a seat' : 'Seat ${seat['seat_number']}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: seat == null ? Colors.white54 : Colors.white,
              ),
            ),
            const Spacer(),
            if (isRenew &&
                _selectedSeatId != null &&
                _selectedSeatId == widget.renewStudent?['seat_id'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'prev',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
              ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  void _showSeatPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Seat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_displaySeats.where((s) => _canSelectSeat(s['id'])).length} available',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                  Expanded(
                    child: _displaySeats.isEmpty
                        ? Center(
                            child: Text(
                              'No seats available for the selected gender',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _displaySeats.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 80,
                              color: Colors.white.withOpacity(0.05),
                            ),
                            itemBuilder: (_, i) => _seatTile(_displaySeats[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seatTile(Map seat) {
    final seatId = seat['id'] as String;
    final isSelected = _selectedSeatId == seatId;
    final canSelect = _canSelectSeat(seatId);
    const shifts = ['M', 'A', 'E', 'N'];

    return InkWell(
      onTap: canSelect
          ? () {
              setState(() => _selectedSeatId = seatId);
              Navigator.pop(context);
            }
          : null,
      child: Opacity(
        opacity: canSelect ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : null,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : canSelect
                      ? Colors.white.withOpacity(0.08)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF818CF8)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    seat['seat_number'].toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : canSelect
                          ? Colors.white
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: shifts.map((s) {
                  final occupied = _isShiftOccupied(seatId, s);
                  final userSelected = _selectedShifts.contains(s);
                  final bgColor = occupied
                      ? Colors.red.withOpacity(0.15)
                      : userSelected
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05);
                  final borderColor = occupied
                      ? Colors.red.withOpacity(0.4)
                      : userSelected
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : Colors.white.withOpacity(0.1);
                  final textColor = occupied
                      ? const Color(0xFFFCA5A5)
                      : userSelected
                      ? const Color(0xFF34D399)
                      : Colors.white54;
                  return Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        s,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (isRenew && seatId == widget.renewStudent?['seat_id']) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '(PREVIOUS)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF818CF8),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF818CF8),
                  size: 24,
                )
              else if (!canSelect)
                Icon(Icons.block, color: Colors.red.withOpacity(0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockerSelector() {
    final available = _allLockers
        .where(
          (l) =>
              l['status'] == 'free' &&
              (_isGenderNeutral ||
                  l['gender'] == 'neutral' ||
                  l['gender'] == _selectedGender),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLockerId,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          hint: const Text(
            'Assign a locker',
            style: TextStyle(color: Colors.white54),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          onChanged: (v) => setState(() {
            _selectedLockerId = v;
            _calculateTotal();
          }),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...available.map(
              (l) => DropdownMenuItem(
                value: l['id'].toString(),
                child: Text('Locker ${l['locker_number']}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── KEY FIX: month chip now calls _updatePricing + _recalcEndDate ──
  Widget _monthChip(int m) {
    bool active = _selectedMonths == m;

    // Find fee for this month+combo
    final plan = _comboPricing.firstWhereOrNull(
      (p) => p['combination_key'] == _comboKey && p['months'] == m,
    );
    final fee = plan != null ? (plan['fee'] ?? 0).toDouble() : 0.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMonths = m;
        });
        _updatePricing(); // updates _baseFee from comboPricing
        _recalcEndDate(); // updates _endDate
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6366F1).withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? const Color(0xFF818CF8)
                : Colors.white.withOpacity(0.08),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$m MONTH${m > 1 ? 'S' : ''}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: active ? Colors.white : Colors.white54,
              ),
            ),
            if (fee > 0) ...[
              const SizedBox(height: 3),
              Text(
                '₹${fee.toInt()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? const Color(0xFF818CF8) : Colors.white38,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeeCard() {
    _calculateTotal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        children: [
          _feeRow('Seat Plan ($_comboKey × ${_selectedMonths}m)', _baseFee),
          if (_selectedLockerId != null)
            _feeRow('Locker (${_selectedMonths}m)', _lockerFeeTotal),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL FEE',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '₹${_totalFee.toInt()}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, double val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            '₹${val.toInt()}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeToggle() {
    return Row(
      children: ['cash', 'upi', 'online', 'other'].map((m) {
        bool active = _paymentMode == m;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _paymentMode = m),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF6366F1).withOpacity(0.2)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? const Color(0xFF818CF8)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                m.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActions() {
    bool isLastStep = _currentStep == 2;
    bool canProceed = false;

    if (_currentStep == 0) {
      canProceed =
          _nameController.text.isNotEmpty &&
          _phoneController.text.length == 10 &&
          _selectedGender.isNotEmpty;
    }
    if (_currentStep == 1) {
      canProceed =
          _selectedShifts.isNotEmpty &&
          _selectedSeatId != null &&
          _canSelectSeat(_selectedSeatId!);
    }
    if (_currentStep == 2) canProceed = true;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              if (_currentStep > (isRenew ? 1 : 0))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep--),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('BACK'),
                  ),
                ),
              if (_currentStep > (isRenew ? 1 : 0)) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: canProceed
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: !canProceed || _isBusy
                        ? null
                        : (isLastStep
                              ? _submit
                              : () => setState(() => _currentStep++)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isLastStep ? 'SUBMIT ADMISSION' : 'NEXT',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
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
}
