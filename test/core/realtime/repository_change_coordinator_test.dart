import 'dart:async';

import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and coalesces Realtime refresh bursts', () async {
    final changes = StreamController<void>();
    final firstRefresh = Completer<void>();
    var refreshes = 0;
    final coordinator = RepositoryChangeCoordinator(
      changes: changes.stream,
      refresh: () async {
        refreshes++;
        if (refreshes == 1) await firstRefresh.future;
      },
    );

    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    changes.add(null);
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1);

    firstRefresh.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 2);

    await coordinator.dispose();
    await changes.close();
  });
}
