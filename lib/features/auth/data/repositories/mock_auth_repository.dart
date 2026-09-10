import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';

final class MockAuthRepository implements AuthRepository {
  const MockAuthRepository(this._preferences);

  static const doctorEmail = 'doctor@gmail.com';
  static const doctorPassword = 'doctor123';
  static const _sessionKey = 'mock_doctor_session';
  static const _emailKey = 'mock_doctor_email';
  static const _doctorId = '00000000-0000-4000-8000-000000000001';

  final PreferencesStore _preferences;

  AccountLookup _doctorLookup(String email) {
    return AccountLookup(
      session: DoctorSession(
        userId: _doctorId,
        email: email,
        displayName: 'Dr. Doctor',
        planTier: PlanTier.premium,
        planStatus: PlanStatus.active,
      ),
      hasOwnDoctorProfile: true,
    );
  }

  @override
  Future<Result<AccountLookup?>> restoreSession() {
    return RepositoryGuard.run(() async {
      final hasSession = await _preferences.getBool(_sessionKey) ?? false;
      if (!hasSession) return null;
      final email = await _preferences.getString(_emailKey) ?? doctorEmail;
      return _doctorLookup(email);
    });
  }

  @override
  Future<Result<AccountLookup>> signIn({
    required String email,
    required String password,
  }) {
    return RepositoryGuard.run(() async {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail != doctorEmail || password != doctorPassword) {
        throw const AuthFailure('Incorrect email or password.');
      }
      await _preferences.setBool(_sessionKey, true);
      await _preferences.setString(_emailKey, normalizedEmail);
      return _doctorLookup(normalizedEmail);
    });
  }

  @override
  Future<Result<void>> signOut() {
    return RepositoryGuard.run(() async {
      await _preferences.remove(_sessionKey);
      await _preferences.remove(_emailKey);
    });
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) {
    return RepositoryGuard.run(() {
      final normalizedEmail = email.trim();
      final looksValid =
          normalizedEmail.contains('@') && normalizedEmail.contains('.');
      if (!looksValid) {
        throw const ValidationFailure('Enter a valid email address.');
      }
      // Mock mode intentionally sends no email.
    });
  }
}
