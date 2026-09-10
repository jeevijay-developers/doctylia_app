import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_resolution.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final source = ref.watch(appDataSourceProvider);
  if (!source.isMock) {
    throw UnsupportedError(
      'Supabase authentication is intentionally deferred until integration.',
    );
  }
  return MockAuthRepository(ref.watch(preferencesStoreProvider));
});

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The confirmed doctor's complete `profiles` row for app-wide consumption.
final doctorProfileProvider = Provider<DoctorProfile?>((ref) {
  return ref.watch(authControllerProvider).value?.session?.profile;
});

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    final result = await _repository.restoreSession();
    return result.fold<Future<AuthState>>(
      onSuccess: (lookup) async => lookup == null
          ? const AuthState.unauthenticated()
          : _resolveAndRejectIfNeeded(lookup),
      onFailure: (failure) async => AuthState.accountError(failure.userMessage),
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.value?.isSubmitting ?? false) return;
    state = const AsyncData(AuthState.unauthenticated(isSubmitting: true));
    final result = await _repository.signIn(email: email, password: password);
    await result.fold(
      onSuccess: (lookup) async {
        state = AsyncData(await _resolveAndRejectIfNeeded(lookup));
      },
      onFailure: (failure) async {
        await _repository.signOut();
        state = AsyncData(
          AuthState.unauthenticated(errorMessage: failure.userMessage),
        );
      },
    );
  }

  Future<String?> requestPasswordReset(String email) async {
    final result = await _repository.sendPasswordReset(email);
    return result.fold(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncData(AuthState.unauthenticated());
  }

  /// Re-resolves the current persisted session so profile, plan, and all
  /// providers derived from them update without requiring an app restart.
  Future<String?> refreshDoctorProfile() async {
    final result = await _repository.restoreSession();
    return result.fold<String?>(
      onSuccess: (lookup) {
        if (lookup == null) {
          state = const AsyncData(AuthState.unauthenticated());
          return 'Your session has expired. Please log in again.';
        }
        state = AsyncData(_resolve(lookup));
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  void returnToLogin() {
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<AuthState> _resolveAndRejectIfNeeded(AccountLookup lookup) async {
    final resolved = _resolve(lookup);
    if (resolved.status == AuthStatus.staffRejected ||
        resolved.status == AuthStatus.accountError) {
      await _repository.signOut();
    }
    return resolved;
  }

  AuthState _resolve(AccountLookup lookup) {
    final resolution = AccountRoleResolver.resolve(lookup);
    return switch (resolution.type) {
      AccountResolutionType.doctor => AuthState.authenticated(
        resolution.session!,
      ),
      AccountResolutionType.staff => const AuthState.staffRejected(),
      AccountResolutionType.accountError => const AuthState.accountError(
        'We could not link this account to a doctor profile.',
      ),
    };
  }
}
