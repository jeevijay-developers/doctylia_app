import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';

abstract interface class SettingsRepository {
  Future<Result<SettingsSnapshot>> load();
  Future<Result<DoctorProfileSettings>> saveProfile(
    DoctorProfileSettings profile,
  );
  Future<Result<DoctorPayoutAccount>> savePayoutAccount(
    DoctorPayoutAccount account,
  );
  Future<Result<CheckoutOrder>> createCheckoutOrder(PlanTier targetTier);
  Future<Result<CheckoutVerification>> simulateMockCheckout(
    CheckoutOrder order,
  );
  Future<Result<SubscriptionDetails>> verifyCheckout(
    CheckoutOrder order,
    CheckoutVerification verification,
  );
  Future<Result<SubscriptionDetails>> cancelScheduledPlan(String pendingPlanId);
}
