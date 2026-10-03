import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment_query.dart';
import 'package:doctylia_app/features/appointments/domain/repositories/appointment_repository.dart';

final class MockAppointmentRepository implements AppointmentRepository {
  MockAppointmentRepository() : _items = _seed();
  final List<Appointment> _items;

  @override
  Future<Result<Appointment>> create(AppointmentDraft draft) =>
      RepositoryGuard.run(() {
        if (draft.patientName.trim().isEmpty ||
            draft.patientPhone.trim().isEmpty) {
          throw ArgumentError('Patient name and phone are required.');
        }
        final item = Appointment(
          id: 'appointment-${DateTime.now().microsecondsSinceEpoch}',
          patientName: draft.patientName.trim(),
          patientPhone: draft.patientPhone.trim(),
          serviceName: draft.serviceName.trim().isEmpty
              ? 'Consultation'
              : draft.serviceName.trim(),
          scheduledAt: draft.scheduledAt,
          isWalkIn: draft.isWalkIn,
          status: AppointmentStatus.pending,
          amount: draft.amount,
          type: draft.type,
          patientAge: draft.patientAge,
          patientGender: draft.patientGender,
          patientEmail: draft.patientEmail,
          chiefComplaint: draft.chiefComplaint,
          notes: draft.notes,
          paymentStatus: draft.paymentStatus,
          tokenNumber: 'T${100 + _items.length}',
        );
        _items.add(item);
        return item;
      });

  @override
  Future<Result<void>> updateStatus(String id, AppointmentStatus status) =>
      RepositoryGuard.run(() {
        final index = _items.indexWhere((item) => item.id == id);
        if (index < 0) throw StateError('Appointment not found.');
        _items[index] = _items[index].copyWith(status: status);
      });

  @override
  Future<Result<void>> update(String id, AppointmentDraft draft) =>
      RepositoryGuard.run(() {
        final index = _items.indexWhere((item) => item.id == id);
        if (index < 0) throw StateError('Appointment not found.');
        final old = _items[index];
        _items[index] = Appointment(
          id: old.id,
          patientName: draft.patientName,
          patientPhone: draft.patientPhone,
          patientAge: draft.patientAge,
          patientGender: draft.patientGender,
          patientEmail: draft.patientEmail,
          serviceName: draft.serviceName,
          scheduledAt: draft.scheduledAt,
          isWalkIn: draft.isWalkIn,
          status: old.status,
          paymentStatus: draft.paymentStatus,
          amount: draft.amount,
          type: draft.type,
          tokenNumber: old.tokenNumber,
          chiefComplaint: draft.chiefComplaint,
          notes: draft.notes,
          rescheduleCount: old.rescheduleCount,
          zoomMeetingId: old.zoomMeetingId,
          zoomJoinUrl: old.zoomJoinUrl,
          zoomStartUrl: old.zoomStartUrl,
        );
      });

  @override
  Future<Result<void>> updatePaymentStatus(
    String id,
    AppointmentPaymentStatus status,
  ) => RepositoryGuard.run(() {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) throw StateError('Appointment not found.');
    _items[index] = _items[index].copyWith(paymentStatus: status);
  });

  @override
  Future<Result<void>> reschedule(String id, DateTime scheduledAt) =>
      RepositoryGuard.run(() {
        final index = _items.indexWhere((item) => item.id == id);
        if (index < 0) throw StateError('Appointment not found.');
        _items[index] = _items[index].copyWith(scheduledAt: scheduledAt);
      });

  @override
  Future<Result<void>> delete(String id) => RepositoryGuard.run(() {
    _items.removeWhere((item) => item.id == id);
  });

  @override
  Future<Result<void>> deleteMany(List<String> ids) => RepositoryGuard.run(() {
    _items.removeWhere((item) => ids.contains(item.id));
  });

  @override
  Future<Result<ZoomMeetingLinks>> generateZoomMeeting(String id) =>
      RepositoryGuard.run(() {
        final item = _items.firstWhere((appointment) => appointment.id == id);
        if (item.type != AppointmentType.online) {
          throw ArgumentError('Only online appointments support Zoom.');
        }
        return const ZoomMeetingLinks(
          meetingId: 'mock-meeting',
          joinUrl: 'https://zoom.us/j/mock',
          startUrl: 'https://zoom.us/s/mock',
        );
      });

  @override
  Future<Result<PageResult<Appointment>>> list(
    PageRequest page,
    AppointmentQuery query,
  ) => RepositoryGuard.run(() {
    final term = query.search.trim().toLowerCase();
    final rows = _items.where((item) {
      final searchMatch =
          term.isEmpty ||
          item.patientName.toLowerCase().contains(term) ||
          item.patientPhone.toLowerCase().contains(term) ||
          (item.patientEmail?.toLowerCase().contains(term) ?? false) ||
          item.serviceName.toLowerCase().contains(term) ||
          (item.tokenNumber?.toLowerCase().contains(term) ?? false);
      final statusMatch = item.status.matchesFilter(query.status);
      final from = query.dateFrom;
      final to = query.dateTo;
      final dateMatch =
          (from == null || !item.scheduledAt.isBefore(_dateOnly(from))) &&
          (to == null || !item.scheduledAt.isAfter(_endOfDay(to)));
      return searchMatch && statusMatch && dateMatch;
    }).toList()..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    final end = (page.offset + page.limit + 1).clamp(0, rows.length);
    final lookahead = page.offset >= rows.length
        ? <Appointment>[]
        : rows.sublist(page.offset, end);
    return PageResult.fromLookahead(
      rows: lookahead,
      request: page,
      totalCount: rows.length,
    );
  });

  @override
  Future<Result<AppointmentSummary>> summary(AppointmentQuery query) =>
      RepositoryGuard.run(() {
        final term = query.search.trim().toLowerCase();
        final rows = _items
            .where((item) {
              final searchMatch =
                  term.isEmpty ||
                  item.patientName.toLowerCase().contains(term) ||
                  item.patientPhone.toLowerCase().contains(term) ||
                  (item.patientEmail?.toLowerCase().contains(term) ?? false) ||
                  item.serviceName.toLowerCase().contains(term) ||
                  (item.tokenNumber?.toLowerCase().contains(term) ?? false);
              final from = query.dateFrom;
              final to = query.dateTo;
              final dateMatch =
                  (from == null ||
                      !item.scheduledAt.isBefore(_dateOnly(from))) &&
                  (to == null || !item.scheduledAt.isAfter(_endOfDay(to)));
              return searchMatch && dateMatch;
            })
            .toList(growable: false);
        int count(AppointmentStatus status) =>
            rows.where((item) => item.status.matchesFilter(status)).length;
        return AppointmentSummary(
          total: rows.length,
          pending: count(AppointmentStatus.pending),
          confirmed: count(AppointmentStatus.confirmed),
          completed: count(AppointmentStatus.completed),
          cancelled: count(AppointmentStatus.cancelled),
          noShow: count(AppointmentStatus.noShow),
        );
      });

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime _endOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

List<Appointment> _seed() {
  final now = DateTime.now();
  const names = [
    'Ananya Sharma',
    'Rohan Mehta',
    'Meera Kapoor',
    'Kabir Singh',
    'Ishita Rao',
  ];
  return List.generate(
    34,
    (index) => Appointment(
      id: 'appointment-$index',
      patientName: names[index % names.length],
      patientPhone: '+91987654${(1000 + index).toString()}',
      serviceName: index.isEven
          ? 'General Consultation'
          : 'Follow-up Consultation',
      scheduledAt: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: index % 8 - 2, hours: 9 + index % 8)),
      status: AppointmentStatus.values[index % AppointmentStatus.values.length],
      paymentStatus: index % 3 == 0
          ? AppointmentPaymentStatus.paid
          : AppointmentPaymentStatus.pending,
      amount: 700 + (index % 4) * 100,
      type: index % 5 == 0 ? AppointmentType.online : AppointmentType.clinic,
      tokenNumber: 'T${100 + index}',
      chiefComplaint: 'Routine consultation',
    ),
  );
}
