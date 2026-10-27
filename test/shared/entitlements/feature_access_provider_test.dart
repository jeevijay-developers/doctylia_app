import 'dart:async';

import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/state/auth_state.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_access_provider.dart';
import 'package:doctylia_app/shared/entitlements/feature_access_repository.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer container({
    required PlanTier tier,
    required PlanStatus status,
    FeatureAccessRepository? repository,
  }) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authControllerProvider.overrideWith(() => _Auth(tier, status)),
        if (repository != null)
          featureAccessRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<FeatureAccessSnapshot> settle(ProviderContainer container) async {
    await container.read(authControllerProvider.future);
    await container.read(remoteFeatureAccessProvider.future);
    return container.read(featureAccessProvider);
  }

  group('local estimate (no server data)', () {
    test('trial doctors get Premium features, like doctor_has_premium_access',
        () async {
      final access = await settle(
        container(tier: PlanTier.free, status: PlanStatus.trial),
      );
      for (final key in FeatureKey.values) {
        expect(access.hasFeature(key), isTrue, reason: key.name);
      }
    });

    test('Pro doctors get Pro features but not Premium ones', () async {
      final access = await settle(
        container(tier: PlanTier.pro, status: PlanStatus.active),
      );
      expect(access.hasFeature(FeatureKey.aiBlogWriter), isTrue);
      expect(access.hasFeature(FeatureKey.billingInvoices), isTrue);
      expect(access.hasFeature(FeatureKey.patientRecords), isFalse);
      expect(access.hasFeature(FeatureKey.staffManagement), isFalse);
      expect(access.hasFeature(FeatureKey.onlineConsultation), isFalse);
    });
  });

  group('server data (get_doctor_feature_access)', () {
    test('an admin override wins over the plan', () async {
      final repository = _FakeRepository([
        const FeatureAccess(
          key: FeatureKey.patientRecords,
          effectiveEnabled: true,
          includedByPlan: false,
          overrideEnabled: true,
          overrideActive: true,
        ),
      ]);
      final access = await settle(
        container(
          tier: PlanTier.pro,
          status: PlanStatus.active,
          repository: repository,
        ),
      );
      expect(access.hasFeature(FeatureKey.patientRecords), isTrue);
      // Rows the server did not return are denied, as on the web.
      expect(access.hasFeature(FeatureKey.aiBlogWriter), isFalse);
    });

    test('re-fetches when the plan or an override changes', () async {
      final repository = _FakeRepository([
        const FeatureAccess(
          key: FeatureKey.staffManagement,
          effectiveEnabled: true,
          includedByPlan: true,
        ),
      ]);
      final c = container(
        tier: PlanTier.premium,
        status: PlanStatus.active,
        repository: repository,
      );
      final sub = c.listen(featureAccessProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        (await settle(c)).hasFeature(FeatureKey.staffManagement),
        isTrue,
      );

      repository.rows = [
        const FeatureAccess(
          key: FeatureKey.staffManagement,
          effectiveEnabled: false,
          includedByPlan: true,
          overrideEnabled: false,
          overrideActive: true,
        ),
      ];
      repository.changes.add(null);
      await pumpEventQueue();

      expect(
        c.read(featureAccessProvider).hasFeature(FeatureKey.staffManagement),
        isFalse,
      );
      expect(repository.loads, 2);
    });

    test('falls back to the local estimate when the server call fails',
        () async {
      final c = container(
        tier: PlanTier.premium,
        status: PlanStatus.active,
        repository: _FakeRepository(null),
      );
      await c.read(authControllerProvider.future);
      await expectLater(
        c.read(remoteFeatureAccessProvider.future),
        throwsA(isA<Object>()),
      );
      final access = c.read(featureAccessProvider);
      expect(access.hasFeature(FeatureKey.patientRecords), isTrue);
      expect(access.hasFeature(FeatureKey.aiBlogWriter), isTrue);
    });
  });
}

final class _FakeRepository implements FeatureAccessRepository {
  _FakeRepository(this.rows);

  List<FeatureAccess>? rows;
  int loads = 0;
  final changes = StreamController<void>.broadcast();

  @override
  Future<Result<List<FeatureAccess>>> load() async {
    loads++;
    final current = rows;
    if (current == null) throw StateError('network down');
    return Success(current);
  }

  @override
  Stream<void> watchChanges() => changes.stream;
}

class _Auth extends AuthController {
  _Auth(this.tier, this.status);

  final PlanTier tier;
  final PlanStatus status;

  @override
  Future<AuthState> build() async => AuthState.authenticated(
    DoctorSession(
      userId: 'doctor-1',
      email: '',
      displayName: 'Dr. Test',
      planTier: tier,
      planStatus: status,
    ),
  );
}
