import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/reviews/data/repositories/mock_review_repository.dart';
import 'package:doctylia_app/features/reviews/presentation/providers/review_providers.dart';
import 'package:doctylia_app/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reviews dashboard fits a narrow phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
          doctorProfileProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: Scaffold(body: ReviewsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('5 Stars \u2605'), findsOneWidget);
    expect(find.text('Verified Only'), findsOneWidget);
    expect(find.text('Ananya Sharma'), findsOneWidget);
  });
}
