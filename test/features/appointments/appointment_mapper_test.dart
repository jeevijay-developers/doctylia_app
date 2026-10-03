import 'package:doctylia_app/features/appointments/data/repositories/supabase_appointment_repository.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({Object? timeSlot = '10:30:00', String? status}) => {
  'id': 'a1',
  'patient_name': 'Asha',
  'patient_phone': '+919876543210',
  'service_name': 'Clinic Visit',
  'appointment_type': 'clinic',
  'date': '2026-09-11',
  'time_slot': timeSlot,
  'status': status ?? 'pending',
  'payment_status': 'pending',
  'amount': 500,
};

void main() {
  test('web walk-ins with a null time_slot map instead of failing', () {
    final item = AppointmentMapper.fromJson(_row(timeSlot: null));
    expect(item.isWalkIn, isTrue);
    expect(item.scheduledAt, DateTime(2026, 9, 11));
  });

  test('scheduled rows keep their time', () {
    final item = AppointmentMapper.fromJson(_row());
    expect(item.isWalkIn, isFalse);
    expect(item.scheduledAt, DateTime(2026, 9, 11, 10, 30));
  });

  test('unknown statuses fall back to pending like the web', () {
    final item = AppointmentMapper.fromJson(_row(status: 'rescheduled'));
    expect(item.status, AppointmentStatus.pending);
  });

  test('Pending filter includes confirmed bookings (web parity)', () {
    const pending = AppointmentStatus.pending;
    expect(AppointmentStatus.confirmed.matchesFilter(pending), isTrue);
    expect(AppointmentStatus.pending.matchesFilter(pending), isTrue);
    expect(AppointmentStatus.completed.matchesFilter(pending), isFalse);
    expect(
      AppointmentStatus.pending.matchesFilter(AppointmentStatus.confirmed),
      isFalse,
    );
  });
}
