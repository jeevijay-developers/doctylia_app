enum PlanTier {
  free,
  pro,
  premium;

  String get displayLabel => switch (this) {
    PlanTier.free || PlanTier.pro => 'Pro',
    PlanTier.premium => 'Premium',
  };
}

enum PlanStatus { trial, active, expired, cancelled }

enum TrialAccessLevel { full, grace, blocked }

abstract final class TrialAccessResolver {
  static const gracePeriod = Duration(hours: 48);

  static TrialAccessLevel resolve({
    required PlanStatus status,
    required DateTime? trialEnd,
    required DateTime now,
  }) {
    if (status == PlanStatus.cancelled) return TrialAccessLevel.blocked;
    if (status != PlanStatus.expired) return TrialAccessLevel.full;
    if (trialEnd == null) return TrialAccessLevel.blocked;
    final graceEndsAt = trialEnd.add(gracePeriod);
    return now.isBefore(graceEndsAt)
        ? TrialAccessLevel.grace
        : TrialAccessLevel.blocked;
  }
}
