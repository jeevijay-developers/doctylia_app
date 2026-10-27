import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/result/result.dart';
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

  /// `captchaToken` (here and below): the Turnstile token Supabase Auth
  /// requires for password, OTP and reset requests.
  Future<void> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) {
    return _completeSignIn(
      () => _repository.signIn(
        email: email,
        password: password,
        captchaToken: captchaToken,
      ),
    );
  }

  /// Returns the failure (e.g. [PhoneNotRegisteredFailure] or
  /// [OtpCooldownFailure]), or null once the SMS is sent.
  Future<AppFailure?> sendPhoneOtp(String phone, {String? captchaToken}) async {
    final result = await _repository.sendPhoneOtp(
      phone,
      captchaToken: captchaToken,
    );
    return result.fold(onSuccess: (_) => null, onFailure: (failure) => failure);
  }

  /// Signup counterpart of [sendPhoneOtp]; null once the SMS is sent.
  Future<AppFailure?> sendSignupOtp({
    required String phone,
    required String fullName,
    String? captchaToken,
  }) async {
    final result = await _repository.sendSignupOtp(
      phone: phone,
      fullName: fullName,
      captchaToken: captchaToken,
    );
    return result.fold(onSuccess: (_) => null, onFailure: (failure) => failure);
  }

  Future<void> verifyPhoneOtp({required String phone, required String token}) {
    return _completeSignIn(
      () => _repository.verifyPhoneOtp(phone: phone, token: token),
    );
  }

  /// Clears a stale sign-in error, e.g. when switching login methods.
  void clearError() {
    final current = state.value;
    if (current == null || current.errorMessage == null) return;
    if (current.status != AuthStatus.unauthenticated) return;
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> _completeSignIn(
    Future<Result<AccountLookup>> Function() attempt,
  ) async {
    if (state.value?.isSubmitting ?? false) return;
    state = const AsyncData(AuthState.unauthenticated(isSubmitting: true));
    final result = await attempt();
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

  Future<String?> requestPasswordReset(
    String email, {
    String? captchaToken,
  }) async {
    final result = await _repository.sendPasswordReset(
      email,
      captchaToken: captchaToken,
    );
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
