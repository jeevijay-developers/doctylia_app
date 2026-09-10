import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/settings/data/repositories/mock_settings_repository.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase settings are deferred.');
  }
  return MockSettingsRepository();
});
final settingsProvider =
    AsyncNotifierProvider<SettingsController, SettingsSnapshot>(
      SettingsController.new,
    );

final settingsCheckoutBusyProvider =
    NotifierProvider<SettingsCheckoutBusyController, bool>(
      SettingsCheckoutBusyController.new,
    );

class SettingsCheckoutBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  void setBusy(bool value) => state = value;
}

class SettingsController extends AsyncNotifier<SettingsSnapshot> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  @override
  Future<SettingsSnapshot> build() async {
    final result = await _repo.load();
    return result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> saveProfile(DoctorProfileSettings profile) async {
    final error = await _mutate(
      () => _repo
          .saveProfile(profile)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => const Failure<DoctorProfileSettings>(
              RemoteServiceFailure(
                'The profile could not be saved in time. Please try again.',
              ),
            ),
          ),
      (current, value) => current.copyWith(profile: value),
    );
    if (error != null) return error;
    unawaited(ref.read(authControllerProvider.notifier).refreshDoctorProfile());
    ref.invalidate(dashboardProvider);
    return null;
  }

  Future<String?> savePayout(DoctorPayoutAccount account) => _mutate(
    () => _repo.savePayoutAccount(account),
    (current, value) => current.copyWith(payoutAccount: value),
  );
  Future<CheckoutOrder> createOrder(PlanTier tier) async {
    final result = await _repo.createCheckoutOrder(tier);
    return result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw failure,
    );
  }

  Future<CheckoutVerification> simulateMockPayment(CheckoutOrder order) async {
    final result = await _repo.simulateMockCheckout(order);
    return result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw failure,
    );
  }

  Future<String?> verify(
    CheckoutOrder order,
    CheckoutVerification verification,
  ) async {
    final error = await _mutate(
      () => _repo.verifyCheckout(order, verification),
      (current, value) => current.copyWith(subscription: value),
    );
    if (error != null) return error;
    final profileError = await ref
        .read(authControllerProvider.notifier)
        .refreshDoctorProfile();
    ref.invalidate(dashboardProvider);
    return profileError == null
        ? null
        : 'Payment was verified, but plan access could not refresh: $profileError';
  }

  Future<String?> cancelScheduled(String id) async {
    final error = await _mutate(
      () => _repo.cancelScheduledPlan(id),
      (current, value) => current.copyWith(subscription: value),
    );
    if (error == null) ref.invalidate(dashboardProvider);
    return error;
  }

  Future<String?> _mutate<T>(
    Future<Result<T>> Function() operation,
    SettingsSnapshot Function(SettingsSnapshot current, T value) update,
  ) async {
    final result = await operation();
    return result.fold<String?>(
      onSuccess: (value) {
        final current = state.value;
        if (current != null) state = AsyncData(update(current, value));
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }
}
