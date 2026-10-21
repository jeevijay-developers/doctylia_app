import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';

abstract interface class AuthRepository {
  Future<Result<AccountLookup?>> restoreSession();

  Future<Result<AccountLookup>> signIn({
    required String email,
    required String password,
  });

  /// Sends a one-time SMS code to an existing account's [phone] (E.164).
  Future<Result<void>> sendPhoneOtp(String phone);

  Future<Result<AccountLookup>> verifyPhoneOtp({
    required String phone,
    required String token,
  });

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email);
}
