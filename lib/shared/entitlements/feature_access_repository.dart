import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class FeatureAccessRepository {
  Future<Result<List<FeatureAccess>>> load();

  /// Fires when the doctor's plan or Superadmin feature overrides change.
  Stream<void> watchChanges();
}

/// Same source as the web's useFeatureAccess: `get_doctor_feature_access`
/// layers active Superadmin overrides (doctor_feature_overrides) on top of
/// the plan default, so both platforms unlock exactly the same features.
final class SupabaseFeatureAccessRepository implements FeatureAccessRepository {
  SupabaseFeatureAccessRepository(this._client);

  final SupabaseClient _client;
  static var _watcherSequence = 0;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<List<FeatureAccess>>> load() => RepositoryGuard.run(() async {
    final rows = await _client.rpc(
      'get_doctor_feature_access',
      params: {'_doctor_id': _doctorId},
    );
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        if (_key(row['feature_key']) case final key?)
          FeatureAccess(
            key: key,
            effectiveEnabled: row['effective_enabled'] == true,
            includedByPlan: row['included_by_plan'] == true,
            overrideEnabled: row['override_enabled'] as bool?,
            overrideActive: row['override_active'] == true,
          ),
    ];
  });

  @override
  Stream<void> watchChanges() {
    final doctorId = _doctorId;
    final controller = StreamController<void>();
    final channel = _client.channel(
      'mobile-feature-access-$doctorId-${_watcherSequence++}',
    );
    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'doctor_feature_overrides',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'doctor_id',
          value: doctorId,
        ),
        callback: (_) => controller.add(null),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: doctorId,
        ),
        callback: (_) => controller.add(null),
      )
      ..subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  static FeatureKey? _key(Object? value) {
    for (final key in FeatureKey.values) {
      if (key.databaseKey == value) return key;
    }
    return null;
  }
}
