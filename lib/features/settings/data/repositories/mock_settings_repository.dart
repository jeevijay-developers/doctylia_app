import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';

final class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository() : _snapshot = _seed();
  SettingsSnapshot _snapshot;

  @override
  Future<Result<SettingsSnapshot>> load() =>
      RepositoryGuard.run(() => _snapshot);

  @override
  Future<Result<DoctorProfileSettings>> saveProfile(
    DoctorProfileSettings profile,
  ) => RepositoryGuard.run(() {
    _snapshot = _snapshot.copyWith(profile: profile);
    return profile;
  });

  @override
  Future<Result<DoctorPayoutAccount>> savePayoutAccount(
    DoctorPayoutAccount account,
  ) => RepositoryGuard.run(() {
    _snapshot = _snapshot.copyWith(payoutAccount: account);
    return account;
  });

  @override
  Future<Result<CheckoutOrder>> createCheckoutOrder(PlanTier targetTier) =>
      RepositoryGuard.run(() {
        if (targetTier == PlanTier.free) {
          throw ArgumentError('A paid tier is required.');
        }
        final subscription = _snapshot.subscription;
        final price = targetTier == PlanTier.premium
            ? subscription.premiumPrice
            : subscription.proPrice;
        final token = DateTime.now().microsecondsSinceEpoch;
        return CheckoutOrder(
          orderId: 'order_mock_$token',
          keyId: 'mock_key',
          paymentId: 'payment_mock_$token',
          targetTier: targetTier,
          amountPaise: (price * 100).round(),
          currency: 'INR',
          isMock: true,
        );
      });

  @override
  Future<Result<CheckoutVerification>> simulateMockCheckout(
    CheckoutOrder order,
  ) => RepositoryGuard.run(
    () => CheckoutVerification(
      razorpayOrderId: order.orderId,
      razorpayPaymentId: 'pay_mock_success',
      razorpaySignature: 'mock_verified_signature',
    ),
  );

  @override
  Future<Result<SubscriptionDetails>> verifyCheckout(
    CheckoutOrder order,
    CheckoutVerification verification,
  ) => RepositoryGuard.run(() {
    if (verification.razorpayOrderId != order.orderId ||
        verification.razorpayPaymentId.isEmpty ||
        verification.razorpaySignature.isEmpty) {
      throw ArgumentError('Payment verification failed.');
    }
    final current = _snapshot.subscription;
    final SubscriptionDetails updated;
    if (current.status == PlanStatus.active && current.planEnd != null) {
      updated = current.copyWith(
        pendingPlan: PendingPlan(
          id: 'pending-${order.paymentId}',
          targetTier: order.targetTier,
          activationDate: current.planEnd!,
          amount: order.amountRupees,
        ),
      );
    } else {
      updated = current.copyWith(
        tier: order.targetTier,
        status: PlanStatus.active,
        planEnd: DateTime.now().add(const Duration(days: 30)),
        clearPending: true,
      );
    }
    _snapshot = _snapshot.copyWith(subscription: updated);
    return updated;
  });

  @override
  Future<Result<SubscriptionDetails>> cancelScheduledPlan(
    String pendingPlanId,
  ) => RepositoryGuard.run(() {
    final pending = _snapshot.subscription.pendingPlan;
    if (pending == null || pending.id != pendingPlanId) {
      throw StateError('Scheduled plan not found.');
    }
    final updated = _snapshot.subscription.copyWith(clearPending: true);
    _snapshot = _snapshot.copyWith(subscription: updated);
    return updated;
  });
}

SettingsSnapshot _seed() => SettingsSnapshot(
  paymentMode: PaymentMode.mock,
  profile: const DoctorProfileSettings(
    fullName: 'Dr. Doctor',
    specialization: 'General Physician',
    qualifications: 'MBBS, MD',
    experienceYears: 8,
    phone: '+91 98765 43210',
    clinicName: 'Doctylia Care Clinic',
    city: 'Mumbai',
    state: 'Maharashtra',
    address: '12 Health Avenue, Andheri West',
    consultationFee: 700,
    registrationNumber: 'MCI-12345',
    clinicEmail: 'clinic@doctylia.in',
    gstRegistered: true,
    gstin: '27ABCDE1234F1Z5',
  ),
  subscription: SubscriptionDetails(
    tier: PlanTier.premium,
    status: PlanStatus.active,
    proPrice: 1499,
    premiumPrice: 3999,
    appointmentsUsed: 38,
    appointmentsCap: 0,
    planEnd: DateTime.now().add(const Duration(days: 18)),
  ),
  payoutAccount: const DoctorPayoutAccount(
    method: PayoutMethod.upi,
    accountHolderName: 'Dr. Doctor',
    upiId: 'doctor@upi',
    verified: false,
    isMock: true,
  ),
);
