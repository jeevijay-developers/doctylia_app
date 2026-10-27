import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription_status.dart';

abstract interface class PrescriptionRepository {
  Future<Result<PageResult<Prescription>>> list(
    PageRequest page, {
    String search = '',
    DateTime? date,
  });
  Future<Result<Prescription>> create(PrescriptionDraft draft);
  Future<Result<Prescription>> update(String id, PrescriptionDraft draft);
  Future<Result<List<PrescriptionPatient>>> listPatients();

  /// Read-only counts for the metric strip, using the same date windows as
  /// [prescriptionStatusOf].
  Future<Result<PrescriptionSummary>> summary({required DateTime now});
  Future<Result<PrescriptionSlipDetails>> getSlipDetails(
    Prescription prescription,
  );
  Future<Result<void>> delete(String id);
  Future<Result<void>> deleteMany(Set<String> ids);
  Stream<void> watchChanges();
  Stream<void> watchPatientChanges();
}
