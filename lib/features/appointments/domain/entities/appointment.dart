enum AppointmentStatus { pending, confirmed, completed, cancelled, noShow }

enum AppointmentPaymentStatus { pending, paid, refunded, payAtClinic }

enum AppointmentType { clinic, online }

extension AppointmentStatusFilter on AppointmentStatus {
  /// Whether this status is shown under the [filter] tab. Mirrors the web,
  /// where "Pending" counts both pending and confirmed (upcoming) bookings.
  bool matchesFilter(AppointmentStatus? filter) => switch (filter) {
    null => true,
    AppointmentStatus.pending =>
      this == AppointmentStatus.pending || this == AppointmentStatus.confirmed,
    _ => this == filter,
  };
}

class AppointmentSummary {
  const AppointmentSummary({
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.noShow,
  });

  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int noShow;
}

class Appointment {
  const Appointment({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.serviceName,
    required this.scheduledAt,
    required this.status,
    required this.paymentStatus,
    required this.amount,
    required this.type,
    this.patientAge,
    this.patientGender,
    this.patientEmail,
    this.tokenNumber,
    this.chiefComplaint,
    this.notes,
    this.rescheduleCount = 0,
    this.zoomMeetingId,
    this.zoomJoinUrl,
    this.zoomStartUrl,
    this.isWalkIn = false,
  });
  final String id;
  final String patientName;
  final String patientPhone;
  final int? patientAge;
  final String? patientGender;
  final String? patientEmail;
  final String serviceName;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final AppointmentPaymentStatus paymentStatus;
  final double amount;
  final AppointmentType type;
  final String? tokenNumber;
  final String? chiefComplaint;
  final String? notes;
  final int rescheduleCount;
  final String? zoomMeetingId;
  final String? zoomJoinUrl;
  final String? zoomStartUrl;

  /// Walk-ins are stored with a null `time_slot` (web parity); [scheduledAt]
  /// then holds the appointment date at midnight.
  final bool isWalkIn;

  Appointment copyWith({
    AppointmentStatus? status,
    AppointmentPaymentStatus? paymentStatus,
    DateTime? scheduledAt,
    String? zoomMeetingId,
    String? zoomJoinUrl,
    String? zoomStartUrl,
  }) => Appointment(
    id: id,
    patientName: patientName,
    patientPhone: patientPhone,
    patientAge: patientAge,
    patientGender: patientGender,
    patientEmail: patientEmail,
    serviceName: serviceName,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    amount: amount,
    type: type,
    tokenNumber: tokenNumber,
    chiefComplaint: chiefComplaint,
    notes: notes,
    rescheduleCount: scheduledAt == null
        ? rescheduleCount
        : rescheduleCount + 1,
    zoomMeetingId: zoomMeetingId ?? this.zoomMeetingId,
    zoomJoinUrl: zoomJoinUrl ?? this.zoomJoinUrl,
    zoomStartUrl: zoomStartUrl ?? this.zoomStartUrl,
    isWalkIn: scheduledAt == null && isWalkIn,
  );
}
