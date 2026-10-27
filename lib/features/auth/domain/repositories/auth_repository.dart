import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';

abstract interface class AuthRepository {
  Future<Result<AccountLookup?>> restoreSession();

  /// `captchaToken` (here and below): a fresh, single-use Cloudflare
  /// Turnstile token. Supabase Auth has CAPTCHA protection enabled, so
  /// password, OTP and password-reset requests are refused without one.
  Future<Result<AccountLookup>> signIn({
    required String email,
    required String password,
    String? captchaToken,
  });

  /// Sends a one-time SMS code to an existing account's [phone] (E.164).
  Future<Result<void>> sendPhoneOtp(String phone, {String? captchaToken});

  /// Sends a signup code to [phone] (E.164), creating the account on first
  /// verification with [fullName] as `full_name` metadata (same as the web's
  /// signup mode). Verify with [verifyPhoneOtp].
  Future<Result<void>> sendSignupOtp({
    required String phone,
    required String fullName,
    String? captchaToken,
  });

  Future<Result<AccountLookup>> verifyPhoneOtp({
    required String phone,
    required String token,
  });

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email, {String? captchaToken});
}
