import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';

class DoctorSession {
  const DoctorSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.planTier,
    required this.planStatus,
    this.trialEnd,
    this.profile,
  });

  final String userId;
  final String email;
  final String displayName;
  final PlanTier planTier;
  final PlanStatus planStatus;
  final DateTime? trialEnd;
  final DoctorProfile? profile;
}
