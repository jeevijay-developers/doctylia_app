import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final source = ref.watch(appDataSourceProvider);
  if (!source.isMock) {
    throw UnsupportedError(
      'Supabase dashboard integration is intentionally deferred.',
    );
  }
  return const MockDashboardRepository();
});

final dashboardProvider =
    AsyncNotifierProvider<DashboardController, DashboardSnapshot>(
      DashboardController.new,
    );

class DashboardController extends AsyncNotifier<DashboardSnapshot> {
  static const _loadTimeout = Duration(seconds: 15);

  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);

  String get _doctorId {
    final session = ref.read(authControllerProvider).value?.session;
    if (session == null) throw StateError('A doctor session is required.');
    return session.userId;
  }

  @override
  Future<DashboardSnapshot> build() async {
    final doctorId = _doctorId;
    final changes = RepositoryChangeCoordinator(
      changes: _repository.watchDashboardChanges(doctorId),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _load(doctorId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(_doctorId));
  }

  Future<DashboardSnapshot> _load(String doctorId) async {
    final result = await _repository
        .loadDashboard(doctorId)
        .timeout(
          _loadTimeout,
          onTimeout: () {
            final error = TimeoutException(
              'Dashboard loading exceeded ${_loadTimeout.inSeconds} seconds.',
              _loadTimeout,
            );
            throw NetworkFailure(cause: error, stackTrace: StackTrace.current);
          },
        );
    return result.fold(
      onSuccess: (snapshot) => snapshot,
      onFailure: (failure) => throw failure,
    );
  }
}
