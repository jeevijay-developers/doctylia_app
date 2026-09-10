import 'package:doctylia_app/shared/entitlements/plan_status.dart';

enum PaymentMode { mock, live }

class DoctorProfileSettings {
  const DoctorProfileSettings({
    required this.fullName,
    required this.specialization,
    required this.qualifications,
    required this.experienceYears,
    required this.phone,
    required this.clinicName,
    required this.city,
    required this.state,
    required this.address,
    required this.consultationFee,
    required this.registrationNumber,
    required this.clinicEmail,
    required this.gstRegistered,
    required this.gstin,
  });
  final String fullName;
  final String specialization;
  final String qualifications;
  final int experienceYears;
  final String phone;
  final String clinicName;
  final String city;
  final String state;
  final String address;
  final double consultationFee;
  final String registrationNumber;
  final String clinicEmail;
  final bool gstRegistered;
  final String gstin;
}

enum PayoutMethod { bank, upi }

class DoctorPayoutAccount {
  const DoctorPayoutAccount({
    required this.method,
    required this.accountHolderName,
    this.accountNumber,
    this.ifsc,
    this.upiId,
    this.verified = false,
    this.isMock = true,
  });
  final PayoutMethod method;
  final String accountHolderName;
  final String? accountNumber;
  final String? ifsc;
  final String? upiId;
  final bool verified;
  final bool isMock;
}

class PendingPlan {
  const PendingPlan({
    required this.id,
    required this.targetTier,
    required this.activationDate,
    required this.amount,
  });
  final String id;
  final PlanTier targetTier;
  final DateTime activationDate;
  final double amount;
}

class SubscriptionDetails {
  const SubscriptionDetails({
    required this.tier,
    required this.status,
    required this.proPrice,
    required this.premiumPrice,
    required this.appointmentsUsed,
    required this.appointmentsCap,
    this.trialEnd,
    this.planEnd,
    this.pendingPlan,
  });
  final PlanTier tier;
  final PlanStatus status;
  final double proPrice;
  final double premiumPrice;
  final int appointmentsUsed;
  final int appointmentsCap;
  final DateTime? trialEnd;
  final DateTime? planEnd;
  final PendingPlan? pendingPlan;
  SubscriptionDetails copyWith({
    PlanTier? tier,
    PlanStatus? status,
    DateTime? planEnd,
    PendingPlan? pendingPlan,
    bool clearPending = false,
  }) => SubscriptionDetails(
    tier: tier ?? this.tier,
    status: status ?? this.status,
    proPrice: proPrice,
    premiumPrice: premiumPrice,
    appointmentsUsed: appointmentsUsed,
    appointmentsCap: appointmentsCap,
    trialEnd: trialEnd,
    planEnd: planEnd ?? this.planEnd,
    pendingPlan: clearPending ? null : pendingPlan ?? this.pendingPlan,
  );
}

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.profile,
    required this.subscription,
    required this.paymentMode,
    this.payoutAccount,
  });
  final DoctorProfileSettings profile;
  final SubscriptionDetails subscription;
  final PaymentMode paymentMode;
  final DoctorPayoutAccount? payoutAccount;
  SettingsSnapshot copyWith({
    DoctorProfileSettings? profile,
    SubscriptionDetails? subscription,
    PaymentMode? paymentMode,
    DoctorPayoutAccount? payoutAccount,
  }) => SettingsSnapshot(
    profile: profile ?? this.profile,
    subscription: subscription ?? this.subscription,
    paymentMode: paymentMode ?? this.paymentMode,
    payoutAccount: payoutAccount ?? this.payoutAccount,
  );
}

class CheckoutOrder {
  const CheckoutOrder({
    required this.orderId,
    required this.keyId,
    required this.paymentId,
    required this.targetTier,
    required this.amountPaise,
    required this.currency,
    required this.isMock,
  });
  final String orderId;
  final String keyId;
  final String paymentId;
  final PlanTier targetTier;
  final int amountPaise;
  final String currency;
  final bool isMock;
  double get amountRupees => amountPaise / 100;
}

class CheckoutVerification {
  const CheckoutVerification({
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
  });
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final String razorpaySignature;
}
