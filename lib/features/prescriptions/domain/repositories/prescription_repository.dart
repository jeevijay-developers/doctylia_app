import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';

abstract interface class PrescriptionRepository {
  Future<Result<PageResult<Prescription>>> list(
    PageRequest page, {
    String search = '',
    DateTime? date,
  });
  Future<Result<Prescription>> create(PrescriptionDraft draft);
  Future<Result<Prescription>> update(String id, PrescriptionDraft draft);
  Future<Result<List<PrescriptionPatient>>> listPatients();
  Future<Result<PrescriptionSlipDetails>> getSlipDetails(
    Prescription prescription,
  );
  Future<Result<void>> delete(String id);
  Future<Result<void>> deleteMany(Set<String> ids);
  Stream<void> watchChanges();
  Stream<void> watchPatientChanges();
}
