import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/settings/data/repositories/mock_settings_repository.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout verification schedules changes for active plans', () async {
    final repo = MockSettingsRepository();
    final order =
        (await repo.createCheckoutOrder(PlanTier.pro) as Success).value
            as CheckoutOrder;
    expect(order.isMock, isTrue);
    final subscription =
        (await repo.verifyCheckout(
                      order,
                      CheckoutVerification(
                        razorpayPaymentId: 'pay_test',
                        razorpayOrderId: order.orderId,
                        razorpaySignature: 'signature',
                      ),
                    )
                    as Success)
                .value
            as SubscriptionDetails;
    expect(subscription.tier, PlanTier.premium);
    expect(subscription.pendingPlan?.targetTier, PlanTier.pro);
  });

  test(
    'scheduled plan can be cancelled without changing current tier',
    () async {
      final repo = MockSettingsRepository();
      final order =
          (await repo.createCheckoutOrder(PlanTier.pro) as Success).value
              as CheckoutOrder;
      final scheduled =
          (await repo.verifyCheckout(
                        order,
                        CheckoutVerification(
                          razorpayPaymentId: 'pay_test',
                          razorpayOrderId: order.orderId,
                          razorpaySignature: 'signature',
                        ),
                      )
                      as Success)
                  .value
              as SubscriptionDetails;
      final cancelled =
          (await repo.cancelScheduledPlan(scheduled.pendingPlan!.id) as Success)
                  .value
              as SubscriptionDetails;
      expect(cancelled.pendingPlan, isNull);
      expect(cancelled.tier, PlanTier.premium);
    },
  );
}
