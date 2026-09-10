class MedicineItem {
  const MedicineItem({
    required this.name,
    String? strength,
    String? dosage,
    this.frequency = '',
    this.duration = '',
    this.timing = '',
    this.route = '',
    this.instructions = '',
  }) : strength = strength ?? dosage ?? '';

  factory MedicineItem.fromJson(Map<String, dynamic> json) => MedicineItem(
    name: json['name'] is String ? json['name'] as String : '',
    strength: json['strength'] is String ? json['strength'] as String : '',
    frequency: json['frequency'] is String ? json['frequency'] as String : '',
    duration: json['duration'] is String ? json['duration'] as String : '',
    timing: json['timing'] is String ? json['timing'] as String : '',
    route: json['route'] is String ? json['route'] as String : '',
    instructions: json['instructions'] is String
        ? json['instructions'] as String
        : '',
  );

  final String name;
  final String strength;
  final String frequency;
  final String duration;
  final String timing;
  final String route;
  final String instructions;

  /// Compatibility label for older app widgets; persisted JSON uses strength.
  String get dosage => strength;

  Map<String, dynamic> toJson() => {
    'name': name,
    'strength': strength,
    'frequency': frequency,
    'duration': duration,
    'timing': timing,
    'route': route,
    'instructions': instructions,
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
