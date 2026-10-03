import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/appointments/data/repositories/mock_appointment_repository.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paginates appointment rows with lookahead', () async {
    final repo = MockAppointmentRepository();
    final first =
        (await repo.list(const PageRequest(), const AppointmentQuery())
                as Success)
            .value;
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    expect(first.nextOffset, 20);
    final second =
        (await repo.list(
                  const PageRequest(offset: 20),
                  const AppointmentQuery(),
                )
                as Success)
            .value;
    expect(second.items, hasLength(14));
    expect(second.hasMore, isFalse);
  });

  test('filters and mutates appointments', () async {
    final repo = MockAppointmentRepository();
    final filtered =
        (await repo.list(
                  const PageRequest(),
                  const AppointmentQuery(status: AppointmentStatus.completed),
                )
                as Success)
            .value;
    expect(
      filtered.items,
      everyElement(
        predicate<Appointment>((a) => a.status == AppointmentStatus.completed),
      ),
    );
    final item = filtered.items.first;
    await repo.updateStatus(item.id, AppointmentStatus.cancelled);
    final cancelled =
        (await repo.list(
                  const PageRequest(),
                  const AppointmentQuery(status: AppointmentStatus.cancelled),
                )
                as Success)
            .value;
    expect(cancelled.items.any((a) => a.id == item.id), isTrue);
  });

  test('summary mirrors web counts and ignores the selected status', () async {
    final repo = MockAppointmentRepository();
    final result = await repo.summary(
      const AppointmentQuery(status: AppointmentStatus.completed),
    );
    final summary = (result as Success<AppointmentSummary>).value;

    expect(summary.total, 34);
    // Web parity: "Pending" already includes confirmed bookings.
    expect(summary.pending, greaterThanOrEqualTo(summary.confirmed));
    expect(
      summary.pending + summary.completed + summary.cancelled + summary.noShow,
      summary.total,
    );
  });

  test('search includes the web phone and token fields', () async {
    final repo = MockAppointmentRepository();
    final byPhone =
        (await repo.list(
                  const PageRequest(),
                  const AppointmentQuery(search: '9876541000'),
                )
                as Success)
            .value;
    final byToken =
        (await repo.list(
                  const PageRequest(),
                  const AppointmentQuery(search: 'T100'),
                )
                as Success)
            .value;

    expect(byPhone.items.single.patientName, 'Ananya Sharma');
    expect(byToken.items.single.tokenNumber, 'T100');
  });
}
