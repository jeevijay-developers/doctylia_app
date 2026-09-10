enum AppointmentStatus { pending, confirmed, completed, cancelled, noShow }

enum AppointmentPaymentStatus { pending, paid, refunded, payAtClinic }

enum AppointmentType { clinic, online }

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
  );
}
