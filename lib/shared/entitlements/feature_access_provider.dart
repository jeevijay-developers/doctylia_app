import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final featureAccessProvider = Provider<FeatureAccessSnapshot>((ref) {
  final tier = ref.watch(authControllerProvider).value?.session?.planTier;
  final premium = tier == PlanTier.premium;
  return FeatureAccessSnapshot([
    for (final key in FeatureKey.values)
      FeatureAccess(
        key: key,
        effectiveEnabled: switch (key) {
          FeatureKey.patientRecords ||
          FeatureKey.staffManagement ||
          FeatureKey.onlineConsultation => premium,
          FeatureKey.aiBlogWriter || FeatureKey.billingInvoices => tier != null,
        },
        includedByPlan: premium,
      ),
  ]);
});
