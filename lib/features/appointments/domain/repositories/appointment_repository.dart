import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment_query.dart';

abstract interface class AppointmentRepository {
  Future<Result<PageResult<Appointment>>> list(
    PageRequest page,
    AppointmentQuery query,
  );
  Future<Result<AppointmentSummary>> summary(AppointmentQuery query);
  Future<Result<Appointment>> create(AppointmentDraft draft);
  Future<Result<void>> update(String id, AppointmentDraft draft);
  Future<Result<void>> updateStatus(String id, AppointmentStatus status);
  Future<Result<void>> updatePaymentStatus(
    String id,
    AppointmentPaymentStatus status,
  );
  Future<Result<void>> reschedule(String id, DateTime scheduledAt);
  Future<Result<void>> delete(String id);
  Future<Result<void>> deleteMany(List<String> ids);
  Future<Result<ZoomMeetingLinks>> generateZoomMeeting(String id);
  Stream<void> watchChanges();
}
