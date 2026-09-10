import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrialAccessResolver', () {
    final now = DateTime.utc(2026, 8, 22, 12);

    test('allows active and trial statuses', () {
      for (final status in [PlanStatus.active, PlanStatus.trial]) {
        expect(
          TrialAccessResolver.resolve(status: status, trialEnd: null, now: now),
          TrialAccessLevel.full,
        );
      }
    });

    test('blocks cancelled accounts immediately', () {
      expect(
        TrialAccessResolver.resolve(
          status: PlanStatus.cancelled,
          trialEnd: now.add(const Duration(days: 30)),
          now: now,
        ),
        TrialAccessLevel.blocked,
      );
    });

    test('allows expired accounts only inside the 48 hour grace period', () {
      final trialEnd = now.subtract(const Duration(hours: 47));
      expect(
        TrialAccessResolver.resolve(
          status: PlanStatus.expired,
          trialEnd: trialEnd,
          now: now,
        ),
        TrialAccessLevel.grace,
      );
      expect(
        TrialAccessResolver.resolve(
          status: PlanStatus.expired,
          trialEnd: now.subtract(const Duration(hours: 48)),
          now: now,
        ),
        TrialAccessLevel.blocked,
      );
      expect(
        TrialAccessResolver.resolve(
          status: PlanStatus.expired,
          trialEnd: null,
          now: now,
        ),
        TrialAccessLevel.blocked,
      );
    });
  });

  group('Feature access', () {
    test('uses the web repository database keys exactly', () {
      expect(FeatureKey.values.map((key) => key.databaseKey), [
        'online_consultation',
        'ai_blog_writer',
        'billing_invoices',
        'patient_records',
        'staff_management',
      ]);
      expect(PlanTier.free.displayLabel, 'Pro');
    });

    test('trusts effective_enabled and denies missing rows', () {
      final access = FeatureAccessSnapshot(const [
        FeatureAccess(
          key: FeatureKey.patientRecords,
          effectiveEnabled: true,
          includedByPlan: false,
          overrideEnabled: true,
          overrideActive: true,
        ),
        FeatureAccess(
          key: FeatureKey.staffManagement,
          effectiveEnabled: false,
          includedByPlan: true,
        ),
      ]);

      expect(access.hasFeature(FeatureKey.patientRecords), isTrue);
      expect(access.hasFeature(FeatureKey.staffManagement), isFalse);
      expect(access.hasFeature(FeatureKey.aiBlogWriter), isFalse);
    });
  });
}
