import 'dart:async';

import 'package:doctylia_app/core/logging/app_logger.dart';

/// Coalesces bursts of repository change events into serialized refreshes.
/// This prevents overlapping reads when Realtime emits several row changes
/// for one logical operation.
final class RepositoryChangeCoordinator {
  RepositoryChangeCoordinator({
    required Stream<void> changes,
    required Future<void> Function() refresh,
  }) : _refresh = refresh {
    _subscription = changes.listen(
      (_) => unawaited(_requestRefresh()),
      onError: (Object error, StackTrace stackTrace) => AppLogger.error(
        'Repository change stream failed',
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  final Future<void> Function() _refresh;
  late final StreamSubscription<void> _subscription;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _disposed = false;

  Future<void> _requestRefresh() async {
    if (_disposed) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshQueued = false;
        await _refresh();
      } while (_refreshQueued && !_disposed);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Repository change refresh failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription.cancel();
  }
}
