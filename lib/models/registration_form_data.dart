class RegistrationFormData {
  // Step 1
  String libraryName = '';
  String address = '';
  String state = '';
  String district = '';
  String pincode = '';
  String phone = '';
  bool isGenderNeutral = false;

  // Step 2
  int totalSeats = 0;
  int maleSeats = 30;
  int femaleSeats = 30;
  int neutralSeats = 0;
  bool hasLockers = false;
  int totalLockers = 0;
  int maleLockers = 10;
  int femaleLockers = 10;
  int neutralLockers = 0;

  // Step 3
  List<Map<String, String>> shifts = [
    {'code': 'M', 'name': 'Morning', 'start_time': '06:00', 'end_time': '12:00'},
    {'code': 'A', 'name': 'Afternoon', 'start_time': '12:00', 'end_time': '17:00'},
    {'code': 'E', 'name': 'Evening', 'start_time': '17:00', 'end_time': '22:00'},
    {'code': 'N', 'name': 'Night', 'start_time': '22:00', 'end_time': '06:00'},
  ];

  // Step 4
  double basePrice = 500;
  List<int> enabledDurations = [1, 3, 6, 12];
  List<Map<String, dynamic>> comboPricing = [];
  Set<String> manuallyEditedCells = {}; // Format: "COMBO_KEY-MONTHS"

  // Step 5
  double lockerMonthlyFee = 0;
  List<String> eligibleCombos = [];

  // Step 6
  String ownerName = '';
  String ownerEmail = '';
  String ownerPassword = '';
  List<Map<String, String>> staffList = [];

  // Step 7
  String? selectedPlan;
  double selectedAmount = 0;

  void calculateComboPricing() {
    final comboKeys = [
      'M', 'A', 'E', 'N', 
      'MA', 'ME', 'MN', 'AE', 'AN', 'EN', 
      'MAE', 'MAN', 'MEN', 'AEN', 
      'MAEN'
    ];
    
    List<Map<String, dynamic>> newPricing = [];
    
    for (var key in comboKeys) {
      int shiftCount = key.length;
      for (var months in [1, 3, 6, 12]) {
        String cellId = "$key-$months";
        
        // Skip if manually edited
        if (manuallyEditedCells.contains(cellId)) {
          final existing = comboPricing.firstWhere((p) => p['combination_key'] == key && p['months'] == months, orElse: () => {});
          if (existing.isNotEmpty) {
            newPricing.add(existing);
            continue;
          }
        }

        double fee = 0;
        if (shiftCount == 1) {
          fee = months == 1 ? basePrice : (months == 3 ? basePrice * 2.5 : (months == 6 ? basePrice * 5 : basePrice * 10));
        } else if (shiftCount == 2) {
          fee = months == 1 ? basePrice * 1.8 : (months == 3 ? basePrice * 4.5 : (months == 6 ? basePrice * 9 : basePrice * 18));
        } else if (shiftCount == 3) {
          fee = months == 1 ? basePrice * 2.5 : (months == 3 ? basePrice * 6 : (months == 6 ? basePrice * 12 : basePrice * 24));
        } else {
          fee = months == 1 ? basePrice * 3 : (months == 3 ? basePrice * 7.5 : (months == 6 ? basePrice * 15 : basePrice * 30));
        }
        
        newPricing.add({
          'combination_key': key,
          'months': months,
          'fee': fee,
        });
      }
    }
    comboPricing = newPricing;
  }
}

final formData = RegistrationFormData();
