class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalVisits,
    this.email,
    this.age,
    this.gender,
    this.firstVisit,
    this.lastVisit,
    this.createdAt,
    this.notes,
  });
  final String id;
  final String name;
  final String phone;
  final String? email;
  final int? age;
  final String? gender;
  final DateTime? firstVisit;
  final DateTime? lastVisit;
  final DateTime? createdAt;
  final int totalVisits;
  final String? notes;

  String get statusLabel => totalVisits >= 10
      ? 'Loyal'
      : totalVisits >= 3
      ? 'Regular'
      : 'New';
}

class PatientDraft {
  const PatientDraft({
    required this.name,
    required this.phone,
    this.email,
    this.age,
    this.gender,
    this.notes,
  });
  final String name;
  final String phone;
  final String? email;
  final int? age;
  final String? gender;
  final String? notes;
}
