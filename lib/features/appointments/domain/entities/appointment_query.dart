import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';

class AppointmentQuery {
  const AppointmentQuery({
    this.search = '',
    this.status,
    this.dateFrom,
    this.dateTo,
  });
  final String search;
  final AppointmentStatus? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  AppointmentQuery copyWith({
    String? search,
    AppointmentStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearStatus = false,
    bool clearDates = false,
  }) => AppointmentQuery(
    search: search ?? this.search,
    status: clearStatus ? null : status ?? this.status,
    dateFrom: clearDates ? null : dateFrom ?? this.dateFrom,
    dateTo: clearDates ? null : dateTo ?? this.dateTo,
  );
}

class AppointmentDraft {
  const AppointmentDraft({
    required this.patientName,
    required this.patientPhone,
    required this.serviceName,
    required this.scheduledAt,
    required this.amount,
    this.type = AppointmentType.clinic,
    this.patientAge,
    this.patientGender,
    this.patientEmail,
    this.chiefComplaint,
    this.notes,
    this.paymentStatus = AppointmentPaymentStatus.pending,
    this.isWalkIn = false,
  });
  final String patientName;
  final String patientPhone;
  final String serviceName;
  final DateTime scheduledAt;
  final double amount;
  final AppointmentType type;
  final int? patientAge;
  final String? patientGender;
  final String? patientEmail;
  final String? chiefComplaint;
  final String? notes;
  final AppointmentPaymentStatus paymentStatus;

  /// When true only the date of [scheduledAt] is used and no time slot is
  /// stored, matching the web "Walk-in" option.
  final bool isWalkIn;
}

class ZoomMeetingLinks {
  const ZoomMeetingLinks({
    required this.meetingId,
    required this.joinUrl,
    required this.startUrl,
  });
  final String meetingId;
  final String joinUrl;
  final String startUrl;
}
