import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';

/// Display status derived from a prescription's dates — prescriptions have
/// no stored status/refill fields (on web or app), so this is read-only UI
/// classification. [PrescriptionSummary] counts use the same windows.
enum PrescriptionStatus {
  /// Follow-up falls within [followUpWindowBefore] days ago through
  /// [followUpWindowAfter] days ahead.
  followUpDue,

  /// Issued today, or a follow-up is still upcoming (beyond the due window).
  active,

  /// Everything else: an earlier course with no pending follow-up.
  completed,
}

/// Days after a missed follow-up during which it still shows as due.
const followUpWindowBefore = 14;

/// Days ahead of a follow-up when it starts showing as due.
const followUpWindowAfter = 3;

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

PrescriptionStatus prescriptionStatusOf(
  Prescription prescription, {
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final issued = _dateOnly(prescription.date);
  final followUp = prescription.followUpDate == null
      ? null
      : _dateOnly(prescription.followUpDate!);
  final dueFrom = today.subtract(const Duration(days: followUpWindowBefore));
  final dueTo = today.add(const Duration(days: followUpWindowAfter));
  if (followUp != null &&
      !followUp.isBefore(dueFrom) &&
      !followUp.isAfter(dueTo)) {
    return PrescriptionStatus.followUpDue;
  }
  if (!issued.isBefore(today) ||
      (followUp != null && followUp.isAfter(today))) {
    return PrescriptionStatus.active;
  }
  return PrescriptionStatus.completed;
}

/// Monday of [now]'s week, the start of "Issued this week".
DateTime startOfWeek(DateTime now) {
  final today = _dateOnly(now);
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}

/// Glance counts for the metric strip, across all of the doctor's
/// prescriptions (independent of the list's search/date filters).
class PrescriptionSummary {
  const PrescriptionSummary({
    required this.active,
    required this.followUpsDue,
    required this.issuedThisWeek,
  });

  final int active;
  final int followUpsDue;
  final int issuedThisWeek;
}
