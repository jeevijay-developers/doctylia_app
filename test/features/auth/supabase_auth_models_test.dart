import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseAuthErrorMapper', () {
    test('maps invalid credentials without exposing backend text', () {
      final failure = SupabaseAuthErrorMapper.map(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
        StackTrace.empty,
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.userMessage, 'Incorrect email or password.');
    });

    test('maps unconfirmed email, rate limiting, and no network', () {
      final unconfirmed = SupabaseAuthErrorMapper.map(
        const AuthApiException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
        StackTrace.empty,
      );
      final rateLimited = SupabaseAuthErrorMapper.map(
        const AuthApiException(
          'Rate limited',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
        StackTrace.empty,
      );
      final offline = SupabaseAuthErrorMapper.map(
        AuthRetryableFetchException(message: 'Network unavailable'),
        StackTrace.empty,
      );
      expect(
        unconfirmed.userMessage,
        'Please confirm your email before logging in.',
      );
      expect(rateLimited, isA<RateLimitFailure>());
      expect(offline, isA<NetworkFailure>());
    });
  });

  test('DoctorProfile maps the complete generated profiles row', () {
    final profile = DoctorProfile.fromJson({
      'id': 'doctor-id',
      'address': '1 Clinic Road',
      'city': 'Pune',
      'clinic_email': 'clinic@example.com',
      'clinic_name': 'Care Clinic',
      'commission_percent': 5,
      'consultation_fee': 750,
      'created_at': '2026-08-01T00:00:00Z',
      'custom_plan_price': null,
      'experience_years': 12,
      'full_name': 'Dr. Meera Shah',
      'gst_registered': true,
      'gstin': 'GSTIN',
      'onboarding_completed': true,
      'phone': '+919999999999',
      'plan_end': '2027-08-01T00:00:00Z',
      'plan_status': 'active',
      'plan_tier': 'premium',
      'profile_photo_url': 'https://example.com/photo.jpg',
      'qualifications': 'MBBS',
      'registration_number': 'REG-1',
      'signature_url': 'https://example.com/signature.jpg',
      'slug': 'dr-meera',
      'specialization': 'Dermatology',
      'state': 'Maharashtra',
      'trial_end': null,
      'trial_start': '2026-08-01T00:00:00Z',
      'updated_at': '2026-08-20T00:00:00Z',
    });

    expect(profile.id, 'doctor-id');
    expect(profile.fullName, 'Dr. Meera Shah');
    expect(profile.clinicName, 'Care Clinic');
    expect(profile.planTier, PlanTier.premium);
    expect(profile.planStatus, PlanStatus.active);
    expect(profile.consultationFee, 750);
  });
}
