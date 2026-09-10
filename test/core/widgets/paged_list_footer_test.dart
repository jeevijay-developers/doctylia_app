import 'dart:async';

import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prevents concurrent load-more requests', (tester) async {
    final request = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListFooter(
            hasMore: true,
            onLoadMore: () {
              calls++;
              return request.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Load more'));
    await tester.pump();
    expect(find.text('Loading…'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(calls, 1);

    request.complete();
    await tester.pumpAndSettle();
    expect(find.text('Load more'), findsOneWidget);
  });
}
