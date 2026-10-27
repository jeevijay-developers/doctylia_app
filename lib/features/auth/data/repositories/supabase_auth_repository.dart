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
    String? captchaToken,
  }) {
    return RepositoryGuard.run(() async {
      try {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
          captchaToken: captchaToken,
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
  Future<Result<void>> sendPhoneOtp(String phone, {String? captchaToken}) {
    return RepositoryGuard.run(() async {
      try {
        // Same call as the web's ProductionOtpService login mode. GoTrue
        // generates the code and hands it to the send-sms-hook edge
        // function, which delivers it through the DLT-approved MSG91
        // template. Accounts are created on the web; never sign up here.
        await _client.auth.signInWithOtp(
          phone: phone,
          shouldCreateUser: false,
          captchaToken: captchaToken,
        );
      } catch (error, stackTrace) {
        throw SupabaseAuthErrorMapper.mapPhoneOtp(error, stackTrace);
      }
    });
  }

  @override
  Future<Result<void>> sendSignupOtp({
    required String phone,
    required String fullName,
    String? captchaToken,
  }) {
    return RepositoryGuard.run(() async {
      try {
        // Mirrors the web's ProductionOtpService signup mode. The account is
        // created when the code is verified; handle_new_user() then inserts
        // the profiles row (7-day trial) and the 'doctor' role.
        await _client.auth.signInWithOtp(
          phone: phone,
          shouldCreateUser: true,
          data: {'full_name': fullName.trim()},
          captchaToken: captchaToken,
        );
      } catch (error, stackTrace) {
        throw SupabaseAuthErrorMapper.mapPhoneOtp(error, stackTrace);
      }
    });
  }

  @override
  Future<Result<AccountLookup>> verifyPhoneOtp({
    required String phone,
    required String token,
  }) {
    return RepositoryGuard.run(() async {
      try {
        final response = await _client.auth.verifyOTP(
          phone: phone,
          token: token.trim(),
          type: OtpType.sms,
        );
        final session = response.session;
        if (session == null) {
          throw const AuthFailure(
            'We could not start your session. Please try again.',
          );
        }
        return await _lookupAccount(
          userId: session.user.id,
          email: session.user.email ?? '',
        );
      } catch (error, stackTrace) {
        if (error is AppFailure) rethrow;
        throw SupabaseAuthErrorMapper.mapPhoneOtp(error, stackTrace);
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
  Future<Result<void>> sendPasswordReset(String email, {String? captchaToken}) {
    return RepositoryGuard.run(() async {
      try {
        await _client.auth.resetPasswordForEmail(
          email.trim(),
          redirectTo: SupabaseConfig.passwordResetRedirectUrl,
          captchaToken: captchaToken,
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
  /// Phone OTP send/verify errors, kept aligned with the web's
  /// productionOtpService.ts so both platforms show the same outcomes.
  static AppFailure mapPhoneOtp(Object error, StackTrace stackTrace) {
    if (error is AppFailure) return error;
    if (error is! AuthException) return map(error, stackTrace);
    if (_isCaptchaFailure(error)) return _captchaFailure(error, stackTrace);

    final retryAfter = parseRetryAfterSeconds(error.message);
    if (retryAfter != null) {
      return OtpCooldownFailure(
        retryAfter,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    final message = error.message.toLowerCase();
    if (message.contains('signups not allowed') ||
        message.contains('user not found') ||
        error.code == 'user_not_found') {
      return PhoneNotRegisteredFailure(cause: error, stackTrace: stackTrace);
    }
    final code = error.code?.toLowerCase();
    if (code == 'otp_expired' ||
        code == 'invalid_otp' ||
        message.contains('token has expired or is invalid')) {
      return AuthFailure(
        'Incorrect or expired code. Try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is AuthRetryableFetchException || _looksLikeNetwork(error)) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    if (error.statusCode == '429' ||
        code == 'over_request_rate_limit' ||
        code == 'over_sms_send_rate_limit') {
      return const RateLimitFailure();
    }
    // Anything else (e.g. the send-sms-hook's "Could not send OTP. Please
    // try again.") is already user-facing; the web shows it verbatim too.
    if (error.message.trim().isNotEmpty) {
      return AuthFailure(error.message, cause: error, stackTrace: stackTrace);
    }
    return map(error, stackTrace);
  }

  /// Supabase Auth's CAPTCHA protection rejected the request (missing,
  /// expired or already-used Turnstile token).
  static bool _isCaptchaFailure(AuthException error) =>
      error.code?.toLowerCase() == 'captcha_failed' ||
      error.message.toLowerCase().contains('captcha');

  static AppFailure _captchaFailure(Object error, StackTrace stackTrace) =>
      AuthFailure(
        'Security check failed. Please complete the verification and try '
        'again.',
        cause: error,
        stackTrace: stackTrace,
      );

  /// Extracts N from GoTrue's "...you can only request this after N seconds".
  static int? parseRetryAfterSeconds(String message) {
    final match = RegExp(
      r'after (\d+) seconds?',
      caseSensitive: false,
    ).firstMatch(message);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static AppFailure map(Object error, StackTrace stackTrace) {
    if (error is AppFailure) return error;

    if (error is AuthException) {
      if (_isCaptchaFailure(error)) return _captchaFailure(error, stackTrace);
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
      if (code == 'otp_expired' ||
          code == 'invalid_otp' ||
          message.contains('token has expired or is invalid')) {
        return AuthFailure(
          'That code is incorrect or has expired. Request a new one.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (message.contains('signups not allowed')) {
        return AuthFailure(
          'No Doctylia account is linked to this mobile number.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (code == 'phone_provider_disabled' ||
          code == 'sms_send_failed' ||
          code == 'otp_disabled') {
        return AuthFailure(
          'SMS sign-in is unavailable right now. Use email login instead.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (status == '429' ||
          code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          code == 'over_sms_send_rate_limit') {
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
