import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';

abstract interface class AuthRepository {
  Future<Result<AccountLookup?>> restoreSession();

  Future<Result<AccountLookup>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email);
}
