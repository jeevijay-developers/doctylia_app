import 'package:doctylia_app/features/dashboard/data/repositories/supabase_dashboard_repository.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every appointment status used by the web dashboard', () {
    DashboardAppointment appointment(String status) {
      return DashboardAppointmentMapper.fromJson({
        'id': 'appointment-id',
        'patient_name': 'Patient',
        'service_name': 'Consultation',
        'appointment_type': 'clinic',
        'date': '2026-08-29',
        'time_slot': '10:30:00',
        'status': status,
      });
    }

    expect(appointment('pending').status, DashboardAppointmentStatus.pending);
    expect(
      appointment('confirmed').status,
      DashboardAppointmentStatus.confirmed,
    );
    expect(
      appointment('completed').status,
      DashboardAppointmentStatus.completed,
    );
    expect(
      appointment('cancelled').status,
      DashboardAppointmentStatus.cancelled,
    );
    expect(appointment('no_show').status, DashboardAppointmentStatus.noShow);
  });

  test('keeps a legacy appointment with no time from breaking dashboard', () {
    final appointment = DashboardAppointmentMapper.fromJson({
      'id': 'legacy-appointment',
      'patient_name': 'Patient',
      'service_name': 'Consultation',
      'appointment_type': 'clinic',
      'date': '2026-09-01',
      'time_slot': null,
      'status': 'pending',
    });

    expect(appointment.timeSlot, isNull);
    expect(appointment.patientName, 'Patient');
    expect(appointment.scheduledAt, DateTime(2026, 9));
  });

  test('today schedule matches the web dashboard outstanding statuses', () {
    expect(DashboardAppointmentMapper.isOutstandingStatus('pending'), isTrue);
    expect(DashboardAppointmentMapper.isOutstandingStatus('confirmed'), isTrue);
    expect(
      DashboardAppointmentMapper.isOutstandingStatus('completed'),
      isFalse,
    );
    expect(
      DashboardAppointmentMapper.isOutstandingStatus('cancelled'),
      isFalse,
    );
    expect(DashboardAppointmentMapper.isOutstandingStatus('no_show'), isFalse);
  });
}
