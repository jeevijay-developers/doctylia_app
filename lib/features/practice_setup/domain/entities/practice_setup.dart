/// First-login practice setup, mirroring the web's /onboarding wizard
/// (src/pages/Onboarding.tsx). Shown once per doctor, until
/// `profiles.onboarding_completed` is true.
class PracticeSetupDetails {
  const PracticeSetupDetails({
    required this.fullName,
    required this.specialization,
    required this.qualifications,
    required this.experienceYears,
    required this.consultationFee,
    required this.clinicName,
    required this.state,
    required this.city,
    required this.phone,
    required this.address,
  });

  final String fullName;

  /// Already resolved: "Other" is replaced by the doctor's own wording.
  final String specialization;
  final String qualifications;
  final int experienceYears;
  final int consultationFee;
  final String clinicName;
  final String state;
  final String city;

  /// 10-digit Indian mobile number, no country code.
  final String phone;
  final String address;
}

/// Same list and order as the web's `specializations`.
const practiceSpecializations = [
  'General Physician',
  'Cardiologist',
  'Dermatologist',
  'Pediatrician',
  'Orthopedic',
  'Gynecologist',
  'ENT Specialist',
  'Ophthalmologist',
  'Neurologist',
  'Psychiatrist',
  'Dentist',
  'Urologist',
  'Pulmonologist',
  'Gastroenterologist',
  'Oncologist',
  'Endocrinologist',
  'Nephrologist',
  'Rheumatologist',
  'Surgeon',
  'Other',
];

/// The web's `generateSlug`: "Dr. Rahul Sharma" → "dr-rahul-sharma".
String practiceSlugFor(String fullName) {
  return fullName
      .toLowerCase()
      .replaceFirst(RegExp(r'^dr\.?\s*', caseSensitive: false), 'dr-')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceFirst(RegExp(r'-+$'), '');
}

/// Strips formatting, a leading 91 and a leading 0, like the web's step-2
/// check; returns the 10 digits or null when not a valid Indian mobile.
String? normalizeIndianMobile(String input) {
  final digits = input
      .replaceAll(RegExp(r'[^\d]'), '')
      .replaceFirst(RegExp(r'^91'), '')
      .replaceFirst(RegExp(r'^0'), '');
  return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
}
