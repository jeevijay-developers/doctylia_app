class MedicalCondition {
  const MedicalCondition(
    this.name,
    this.status, {
    this.diagnosedOn,
    this.notes,
  });
  final String name;
  final String status;
  final DateTime? diagnosedOn;
  final String? notes;
}

class PatientMedication {
  const PatientMedication(
    this.name, {
    this.dosage,
    this.frequency,
    this.status = 'active',
  });
  final String name;
  final String? dosage;
  final String? frequency;
  final String status;
}

class PatientAllergy {
  const PatientAllergy(this.name, this.severity, {this.reaction});
  final String name;
  final String severity;
  final String? reaction;
}

class PatientVisit {
  const PatientVisit(
    this.id,
    this.date, {
    this.reason,
    this.diagnosis,
    this.notes,
  });
  final String id;
  final DateTime date;
  final String? reason;
  final String? diagnosis;
  final String? notes;
}

class MedicalDocument {
  const MedicalDocument(this.id, this.name, this.type, this.date);
  final String id;
  final String name;
  final String type;
  final DateTime date;
}

class CheckupReminder {
  const CheckupReminder(this.id, this.nextCheckup, this.frequency, this.status);
  final String id;
  final DateTime nextCheckup;
  final String frequency;
  final String status;
}

class MedicalRecordBundle {
  const MedicalRecordBundle({
    required this.conditions,
    required this.medications,
    required this.allergies,
    required this.visits,
    required this.documents,
    required this.reminders,
    this.surgeries = const [],
    this.familyHistory = const [],
    this.vitals = const [],
  });
  final List<MedicalCondition> conditions;
  final List<PatientMedication> medications;
  final List<PatientAllergy> allergies;
  final List<PatientVisit> visits;
  final List<MedicalDocument> documents;
  final List<CheckupReminder> reminders;
  final List<MedicalRecordItem> surgeries;
  final List<MedicalRecordItem> familyHistory;
  final List<MedicalRecordItem> vitals;
}

enum MedicalRecordSection {
  conditions,
  surgeries,
  familyHistory,
  medications,
  allergies,
  visits,
  documents,
  vitals,
  reminders,
}

class MedicalRecordItem {
  const MedicalRecordItem({
    required this.id,
    required this.section,
    required this.values,
  });
  final String id;
  final MedicalRecordSection section;
  final Map<String, dynamic> values;
}

class MedicalDocumentUpload {
  const MedicalDocumentUpload({
    required this.name,
    required this.type,
    required this.date,
    required this.fileName,
    required this.bytes,
    this.mimeType,
    this.notes,
    this.visitId,
  });
  final String name;
  final String type;
  final DateTime date;
  final String fileName;
  final List<int> bytes;
  final String? mimeType;
  final String? notes;
  final String? visitId;
}
