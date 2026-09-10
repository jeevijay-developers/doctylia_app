import 'package:doctylia_app/features/appointments/data/repositories/supabase_appointment_repository.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the real appointments enum and Zoom columns', () {
    final appointment = AppointmentMapper.fromJson({
      'id': 'appointment-id',
      'patient_name': 'Ananya',
      'patient_phone': '+919999999999',
      'patient_age': 31,
      'patient_gender': 'female',
      'patient_email': 'ananya@example.com',
      'service_name': 'Online consultation',
      'appointment_type': 'online',
      'date': '2026-08-31',
      'time_slot': '10:30:00',
      'status': 'no_show',
      'payment_status': 'pay_at_clinic',
      'amount': 700,
      'token_number': 'T123',
      'chief_complaint': 'Fever',
      'notes': null,
      'reschedule_count': 1,
      'zoom_meeting_id': '123456',
      'zoom_join_url': 'https://zoom.us/j/123456',
      'zoom_start_url': 'https://zoom.us/s/123456',
    });

    expect(appointment.status, AppointmentStatus.noShow);
    expect(appointment.paymentStatus, AppointmentPaymentStatus.payAtClinic);
    expect(appointment.type, AppointmentType.online);
    expect(appointment.zoomMeetingId, '123456');
    expect(appointment.zoomStartUrl, isNotNull);
  });
}
