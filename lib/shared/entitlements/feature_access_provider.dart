import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_access_repository.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden with [SupabaseFeatureAccessRepository] at bootstrap. Null in
/// the mock flavor, where only the local plan estimate is used.
final featureAccessRepositoryProvider = Provider<FeatureAccessRepository?>(
  (ref) => null,
);

/// Server-resolved entitlements (plan default + active Superadmin
/// overrides), re-fetched on login change, plan change or override change.
final remoteFeatureAccessProvider =
    AsyncNotifierProvider<RemoteFeatureAccessController, FeatureAccessSnapshot?>(
      RemoteFeatureAccessController.new,
    );

class RemoteFeatureAccessController
    extends AsyncNotifier<FeatureAccessSnapshot?> {
  @override
  Future<FeatureAccessSnapshot?> build() async {
    final userId = ref.watch(
      authControllerProvider.select((state) => state.value?.session?.userId),
    );
    final repo = ref.watch(featureAccessRepositoryProvider);
    if (userId == null || repo == null) return null;
    final changes = RepositoryChangeCoordinator(
      changes: repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _load(repo);
  }

  Future<FeatureAccessSnapshot?> _load(FeatureAccessRepository repo) async {
    final result = await repo.load();
    return result.fold(
      onSuccess: FeatureAccessSnapshot.new,
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    final repo = ref.read(featureAccessRepositoryProvider);
    if (repo == null) return;
    state = await AsyncValue.guard(() => _load(repo));
  }
}

/// What the UI gates on. Uses the server result once loaded; until then (or
/// if it fails) mirrors the server rule locally: Premium features need
/// `plan_status = 'trial'` or `plan_tier = 'premium'`
/// (doctor_has_premium_access), Pro features are on for every doctor.
final featureAccessProvider = Provider<FeatureAccessSnapshot>((ref) {
  final remote = ref.watch(remoteFeatureAccessProvider).value;
  if (remote != null) return remote;
  final session = ref.watch(authControllerProvider).value?.session;
  final premium =
      session != null &&
      (session.planStatus == PlanStatus.trial ||
          session.planTier == PlanTier.premium);
  return FeatureAccessSnapshot([
    for (final key in FeatureKey.values)
      FeatureAccess(
        key: key,
        effectiveEnabled: switch (key) {
          FeatureKey.patientRecords ||
          FeatureKey.staffManagement ||
          FeatureKey.onlineConsultation => premium,
          FeatureKey.aiBlogWriter ||
          FeatureKey.billingInvoices => session != null,
        },
        includedByPlan: premium,
      ),
  ]);
});
