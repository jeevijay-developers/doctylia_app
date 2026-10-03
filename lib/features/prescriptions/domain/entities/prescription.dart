enum MedicineFood { before, after }

/// One structured medicine line, in the exact JSON shape the web stores in
/// `prescriptions.medicines` (src/lib/prescriptionMedicines.ts):
/// `{name, strength, morning, afternoon, evening, durationDays, food}` with
/// the three time-of-day flags persisted as 0/1 ("1-0-1" Rx notation).
class MedicineItem {
  const MedicineItem({
    required this.name,
    String? strength,
    String? dosage,
    this.morning = false,
    this.afternoon = false,
    this.evening = false,
    this.durationDays = 0,
    this.food = MedicineFood.after,
  }) : strength = strength ?? dosage ?? '';

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    final days = json['durationDays'];
    return MedicineItem(
      name: json['name'] is String ? json['name'] as String : '',
      strength: json['strength'] is String ? json['strength'] as String : '',
      morning: json['morning'] == 1,
      afternoon: json['afternoon'] == 1,
      evening: json['evening'] == 1,
      durationDays: days is num && days > 0
          ? days.toInt()
          // Rows saved by earlier app builds stored free text ("5 days").
          : int.tryParse(
                  RegExp(r'\d+').stringMatch('${json['duration'] ?? ''}') ?? '',
                ) ??
                0,
      food: json['food'] == 'before' ? MedicineFood.before : MedicineFood.after,
    );
  }

  final String name;
  final String strength;
  final bool morning;
  final bool afternoon;
  final bool evening;
  final int durationDays;
  final MedicineFood food;

  /// Compatibility label for older app widgets; persisted JSON uses strength.
  String get dosage => strength;

  String get foodLabel =>
      food == MedicineFood.before ? 'Before Food' : 'After Food';

  /// "1-0-1" dosage notation used on the web slip.
  String get schedule =>
      '${morning ? 1 : 0}-${afternoon ? 1 : 0}-${evening ? 1 : 0}';

  /// Web summary line: "Morning-Afternoon-Evening: 1-0-1 · 5 days · After Food".
  String get summary => [
    'Morning-Afternoon-Evening: $schedule',
    if (durationDays > 0) '$durationDays day${durationDays == 1 ? '' : 's'}',
    foodLabel,
  ].join(' · ');

  /// Patient-facing line from the web slip, using words instead of 0/1:
  /// "Morning, Evening/Night · 5 days · After Food".
  String get slipLine => [
    [
      if (morning) 'Morning',
      if (afternoon) 'Afternoon',
      if (evening) 'Evening/Night',
    ].join(', '),
    if (durationDays > 0) '$durationDays day${durationDays == 1 ? '' : 's'}',
    foodLabel,
  ].where((part) => part.isNotEmpty).join('  ·  ');

  Map<String, dynamic> toJson() => {
    'name': name,
    'strength': strength,
    'morning': morning ? 1 : 0,
    'afternoon': afternoon ? 1 : 0,
    'evening': evening ? 1 : 0,
    'durationDays': durationDays,
    'food': food.name,
  };
}

class Prescription {
  const Prescription({
    required this.id,
    required this.patientName,
    required this.date,
    required this.medicines,
    this.patientId,
    this.diagnosis,
    this.legacyMedications,
    this.notes,
    this.patientAge,
    this.patientWeight,
    this.advice,
    this.dietAdvice,
    this.lifestyleAdvice,
    this.followUpDate,
    this.followUpInstructions,
    this.visitId,
  });
  final String id;
  final String? patientId;
  final String patientName;
  final String? diagnosis;
  final List<MedicineItem> medicines;
  final String? legacyMedications;
  final String? notes;
  final DateTime date;
  final int? patientAge;
  final double? patientWeight;
  final String? advice;
  final String? dietAdvice;
  final String? lifestyleAdvice;
  final DateTime? followUpDate;
  final String? followUpInstructions;
  final String? visitId;
}

class PrescriptionDraft {
  const PrescriptionDraft({
    required this.patientName,
    required this.date,
    required this.medicines,
    this.patientId,
    this.diagnosis,
    this.notes,
    this.patientAge,
    this.patientWeight,
    this.advice,
    this.dietAdvice,
    this.lifestyleAdvice,
    this.followUpDate,
    this.followUpInstructions,
    this.visitId,
  });
  final String? patientId;
  final String patientName;
  final String? diagnosis;
  final List<MedicineItem> medicines;
  final String? notes;
  final DateTime date;
  final int? patientAge;
  final double? patientWeight;
  final String? advice;
  final String? dietAdvice;
  final String? lifestyleAdvice;
  final DateTime? followUpDate;
  final String? followUpInstructions;
  final String? visitId;
}

class PrescriptionPatient {
  const PrescriptionPatient({
    required this.id,
    required this.name,
    required this.phone,
    this.gender,
    this.age,
  });
  final String id;
  final String name;
  final String phone;
  final String? gender;
  final int? age;
}

class PrescriptionSlipDetails {
  const PrescriptionSlipDetails({
    this.patientGender,
    this.visitReason,
    this.symptoms,
    this.vitals = const {},
  });
  final String? patientGender;
  final String? visitReason;
  final String? symptoms;
  final Map<String, dynamic> vitals;
}
