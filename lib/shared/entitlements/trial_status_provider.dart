import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrialStatusSnapshot {
  const TrialStatusSnapshot({
    required this.accessLevel,
    required this.planStatus,
    required this.trialEnd,
    required this.graceEndsAt,
    required this.isTrialEndingSoon,
  });

  final TrialAccessLevel accessLevel;
  final PlanStatus? planStatus;
  final DateTime? trialEnd;
  final DateTime? graceEndsAt;
  final bool isTrialEndingSoon;

  bool get isExpired => planStatus == PlanStatus.expired;
  bool get isCancelled => planStatus == PlanStatus.cancelled;
}

final trialStatusProvider = Provider<TrialStatusSnapshot>((ref) {
  final dashboard = ref.watch(dashboardProvider).value;
  final profile = ref.watch(doctorProfileProvider);
  final status = dashboard?.planStatus ?? profile?.planStatus;
  final trialEnd = dashboard?.trialEnd ?? profile?.trialEnd;
  final now = DateTime.now();
  final accessLevel = status == null
      ? TrialAccessLevel.full
      : TrialAccessResolver.resolve(
          status: status,
          trialEnd: trialEnd,
          now: now,
        );
  final remaining = trialEnd?.difference(now);
  return TrialStatusSnapshot(
    accessLevel: accessLevel,
    planStatus: status,
    trialEnd: trialEnd,
    graceEndsAt: status == PlanStatus.expired && trialEnd != null
        ? trialEnd.add(TrialAccessResolver.gracePeriod)
        : null,
    isTrialEndingSoon:
        status == PlanStatus.trial &&
        remaining != null &&
        !remaining.isNegative &&
        remaining <= const Duration(hours: 24),
  );
});
