import 'package:doctylia_app/shared/entitlements/plan_status.dart';

/// The complete `profiles` row shape from the web app's generated types.ts.
class DoctorProfile {
  const DoctorProfile({
    required this.id,
    required this.consultationFee,
    required this.createdAt,
    required this.gstRegistered,
    required this.onboardingCompleted,
    required this.planStatus,
    required this.planTier,
    required this.trialStart,
    required this.updatedAt,
    this.address,
    this.city,
    this.clinicEmail,
    this.clinicName,
    this.commissionPercent,
    this.customPlanPrice,
    this.experienceYears,
    this.fullName,
    this.gstin,
    this.phone,
    this.planEnd,
    this.profilePhotoUrl,
    this.qualifications,
    this.registrationNumber,
    this.signatureUrl,
    this.slug,
    this.specialization,
    this.state,
    this.trialEnd,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      clinicEmail: json['clinic_email'] as String?,
      clinicName: json['clinic_name'] as String?,
      commissionPercent: (json['commission_percent'] as num?)?.toDouble(),
      consultationFee: (json['consultation_fee'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      customPlanPrice: (json['custom_plan_price'] as num?)?.toDouble(),
      experienceYears: json['experience_years'] as int?,
      fullName: json['full_name'] as String?,
      gstRegistered: json['gst_registered'] as bool,
      gstin: json['gstin'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool,
      phone: json['phone'] as String?,
      planEnd: _optionalDate(json['plan_end']),
      planStatus: _planStatus(json['plan_status'] as String),
      planTier: _planTier(json['plan_tier'] as String),
      profilePhotoUrl: json['profile_photo_url'] as String?,
      qualifications: json['qualifications'] as String?,
      registrationNumber: json['registration_number'] as String?,
      signatureUrl: json['signature_url'] as String?,
      slug: json['slug'] as String?,
      specialization: json['specialization'] as String?,
      state: json['state'] as String?,
      trialEnd: _optionalDate(json['trial_end']),
      trialStart: DateTime.parse(json['trial_start'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String? address;
  final String? city;
  final String? clinicEmail;
  final String? clinicName;
  final double? commissionPercent;
  final double consultationFee;
  final DateTime createdAt;
  final double? customPlanPrice;
  final int? experienceYears;
  final String? fullName;
  final bool gstRegistered;
  final String? gstin;
  final bool onboardingCompleted;
  final String? phone;
  final DateTime? planEnd;
  final PlanStatus planStatus;
  final PlanTier planTier;
  final String? profilePhotoUrl;
  final String? qualifications;
  final String? registrationNumber;
  final String? signatureUrl;
  final String? slug;
  final String? specialization;
  final String? state;
  final DateTime? trialEnd;
  final DateTime trialStart;
  final DateTime updatedAt;

  static DateTime? _optionalDate(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }

  static PlanTier _planTier(String value) => switch (value) {
    'free' => PlanTier.free,
    'pro' => PlanTier.pro,
    'premium' => PlanTier.premium,
    _ => throw FormatException('Unknown profiles.plan_tier value.'),
  };

  static PlanStatus _planStatus(String value) => switch (value) {
    'trial' => PlanStatus.trial,
    'active' => PlanStatus.active,
    'expired' => PlanStatus.expired,
    'cancelled' => PlanStatus.cancelled,
    _ => throw FormatException('Unknown profiles.plan_status value.'),
  };
}
