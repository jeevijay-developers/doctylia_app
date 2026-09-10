import 'package:doctylia_app/core/config/supabase_config.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<AccountLookup?>> restoreSession() {
    return RepositoryGuard.run(() async {
      try {
        var session = _client.auth.currentSession;
        if (session == null) return null;
        if (session.isExpired) {
          try {
            session = (await _client.auth.refreshSession()).session;
          } on AuthException catch (error) {
            if (_isInvalidStoredSession(error)) {
              await _client.auth.signOut(scope: SignOutScope.local);
              return null;
            }
            rethrow;
          }
        }
        if (session == null) return null;
        return _lookupAccount(
          userId: session.user.id,
          email: session.user.email ?? '',
        );
      } catch (error, stackTrace) {
        throw SupabaseAuthErrorMapper.map(error, stackTrace);
      }
    });
  }

  @override
  Future<Result<AccountLookup>> signIn({
    required String email,
    required String password,
  }) {
    return RepositoryGuard.run(() async {
      try {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final session = response.session;
        if (session == null) {
          throw const AuthFailure(
            'We could not start your session. Please try again.',
          );
        }
        return _lookupAccount(
          userId: session.user.id,
          email: session.user.email ?? email.trim(),
        );
      } catch (error, stackTrace) {
        if (error is AppFailure) rethrow;
        throw SupabaseAuthErrorMapper.map(error, stackTrace);
      }
    });
  }

  @override
  Future<Result<void>> signOut() {
    return RepositoryGuard.run(() async {
      try {
        await _client.auth.signOut();
      } catch (error, stackTrace) {
        throw SupabaseAuthErrorMapper.map(error, stackTrace);
      }
    });
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) {
    return RepositoryGuard.run(() async {
      try {
        await _client.auth.resetPasswordForEmail(
          email.trim(),
          redirectTo: SupabaseConfig.passwordResetRedirectUrl,
        );
      } catch (error, stackTrace) {
        throw SupabaseAuthErrorMapper.map(error, stackTrace);
      }
    });
  }

  Future<AccountLookup> _lookupAccount({
    required String userId,
    required String email,
  }) async {
    // Keep this order aligned with web useProfile.tsx: own profile first,
    // then the staff_members fallback only when no own profile exists.
    final profileJson = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (profileJson != null) {
      final profile = DoctorProfile.fromJson(profileJson);
      return AccountLookup(
        hasOwnDoctorProfile: true,
        session: DoctorSession(
          userId: userId,
          email: email,
          displayName: _displayName(profile),
          planTier: profile.planTier,
          planStatus: profile.planStatus,
          trialEnd: profile.trialEnd,
          profile: profile,
        ),
      );
    }

    final staffJson = await _client
        .from('staff_members')
        .select('status')
        .eq('id', userId)
        .maybeSingle();
    return AccountLookup(
      hasOwnDoctorProfile: false,
      staff: staffJson == null
          ? null
          : StaffLookup(status: staffJson['status'] as String),
    );
  }

  static String _displayName(DoctorProfile profile) {
    final name = profile.fullName?.trim();
    return name == null || name.isEmpty ? 'Doctor' : name;
  }

  static bool _isInvalidStoredSession(AuthException error) {
    return const {
      'session_expired',
      'session_missing',
      'session_not_found',
      'refresh_token_not_found',
      'invalid_refresh_token',
    }.contains(error.code);
  }
}

abstract final class SupabaseAuthErrorMapper {
  static AppFailure map(Object error, StackTrace stackTrace) {
    if (error is AppFailure) return error;

    if (error is AuthException) {
      final code = error.code?.toLowerCase();
      final status = error.statusCode;
      final message = error.message.toLowerCase();

      if (code == 'invalid_credentials' ||
          code == 'user_not_found' ||
          message.contains('invalid login credentials')) {
        return AuthFailure(
          'Incorrect email or password.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (code == 'email_not_confirmed' ||
          message.contains('email not confirmed')) {
        return AuthFailure(
          'Please confirm your email before logging in.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (status == '429' ||
          code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit') {
        return const RateLimitFailure();
      }
      if (error is AuthRetryableFetchException || _looksLikeNetwork(error)) {
        return NetworkFailure(cause: error, stackTrace: stackTrace);
      }
      return AuthFailure(
        'We could not log you in. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (_looksLikeNetwork(error)) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    return UnknownFailure(cause: error, stackTrace: stackTrace);
  }

  static bool _looksLikeNetwork(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('socketexception') ||
        value.contains('clientexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('network is unreachable') ||
        value.contains('connection timed out');
  }
}
