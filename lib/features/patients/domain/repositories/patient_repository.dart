import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/patients/domain/entities/medical_record.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';

abstract interface class PatientRepository {
  Future<Result<PageResult<Patient>>> list(
    PageRequest page, {
    String search = '',
    DateTime? registeredDate,
  });
  Future<Result<List<Patient>>> listForExport();
  Future<Result<Patient>> create(PatientDraft draft);
  Future<Result<Patient>> update(String id, PatientDraft draft);
  Future<Result<Patient>> get(String id);
  Future<Result<MedicalRecordBundle>> getMedicalRecord(String patientId);
  Future<Result<void>> delete(String id);
  Future<Result<void>> deleteMany(Set<String> ids);
  Future<Result<PageResult<MedicalRecordItem>>> listMedicalRecords(
    String patientId,
    MedicalRecordSection section,
    PageRequest page,
  );
  Future<Result<void>> saveMedicalRecord(
    String patientId,
    MedicalRecordSection section,
    Map<String, dynamic> values, {
    String? id,
  });
  Future<Result<void>> removeMedicalRecord(
    MedicalRecordSection section,
    String id,
  );
  Future<Result<void>> uploadDocument(
    String patientId,
    MedicalDocumentUpload document,
  );
  Future<Result<Uri>> getDocumentUrl(String path);
  Stream<void> watchChanges();
}
