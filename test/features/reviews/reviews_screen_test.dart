import 'dart:async';

import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/reviews/data/repositories/mock_review_repository.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';
import 'package:doctylia_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:doctylia_app/features/reviews/presentation/providers/review_providers.dart';
import 'package:doctylia_app/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PatientReview _review(
  String id,
  String name,
  int rating, {
  bool verified = true,
  bool visible = true,
  bool pinned = false,
}) => PatientReview(
  id: id,
  patientName: name,
  rating: rating,
  isPinned: pinned,
  isVerified: verified,
  isVisible: visible,
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  reviewText: 'Clear explanations and a calm, careful consultation.',
);

/// Honors server filters + search; [gate] holds the first list load open;
/// toggles mutate in place like the real repository.
final class _FakeRepository implements ReviewRepository {
  _FakeRepository({this.gate});

  final Completer<void>? gate;
  final items = [
    _review('a', 'Asha Five', 5, pinned: true),
    _review('b', 'Bilal Four', 4, verified: false),
    _review('c', 'Chitra Two', 2),
    _review('d', 'Dev One', 1, visible: false),
  ];

  @override
  Future<Result<PageResult<PatientReview>>> list(
    PageRequest page, {
    String search = '',
    ReviewFilter filter = ReviewFilter.all,
  }) async {
    await gate?.future;
    final term = search.trim().toLowerCase();
    final rows = items
        .where(
          (r) => term.isEmpty || r.patientName.toLowerCase().contains(term),
        )
        .where(
          (r) => switch (filter) {
            ReviewFilter.all => true,
            ReviewFilter.fiveStars => r.rating == 5,
            ReviewFilter.verified => r.isVerified,
            ReviewFilter.hidden => !r.isVisible,
          },
        )
        .toList();
    return Success(PageResult(items: rows, hasMore: false));
  }

  @override
  Future<Result<ReviewStats>> getStats() async => Success(
    ReviewStats(
      total: items.length,
      averageRating: 3,
      verified: items.where((r) => r.isVerified).length,
      pinned: items.where((r) => r.isPinned).length,
      starCounts: ReviewStats.countStars(items.map((r) => r.rating)),
    ),
  );

  @override
  Future<Result<void>> togglePinned(String id) async => _toggle(id, pin: true);

  @override
  Future<Result<void>> toggleVisible(String id) async =>
      _toggle(id, pin: false);

  Result<void> _toggle(String id, {required bool pin}) {
    final i = items.indexWhere((r) => r.id == id);
    items[i] = pin
        ? items[i].copyWith(isPinned: !items[i].isPinned)
        : items[i].copyWith(isVisible: !items[i].isVisible);
    return const Success(null);
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

Widget _app(ReviewRepository repository) => ProviderScope(
  overrides: [
    reviewRepositoryProvider.overrideWithValue(repository),
    doctorProfileProvider.overrideWithValue(null),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: ReviewsScreen()),
  ),
);

void _phone(WidgetTester tester, {double height = 2400}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(375, height);
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('countStars buckets 1–5★ and ignores out-of-range values', () {
    expect(ReviewStats.countStars([5, 5, 4, 1, 0, 6]), [1, 0, 0, 1, 2]);
  });

  testWidgets('reviews dashboard fits a narrow phone (seed data)', (
    tester,
  ) async {
    _phone(tester, height: 844);
    await tester.pumpWidget(_app(MockReviewRepository()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ananya Sharma'), findsWidgets);
    expect(find.text('Verified Patients'), findsOneWidget);
  });

  testWidgets('skeleton instead of spinners while loading', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(_app(_FakeRepository(gate: gate)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Asha Five'), findsOneWidget);
  });

  testWidgets('summary breakdown, critical tab and card moderation', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();

    // Overview: average, count, per-star shares, real metric chips.
    expect(find.text('3.0'), findsOneWidget);
    expect(find.text('Based on 4 patient reviews'), findsOneWidget);
    expect(find.text('25%'), findsNWidgets(4)); // 5★, 4★, 2★, 1★ each 1/4
    expect(find.text('0%'), findsOneWidget); // 3★
    expect(find.text('75% verified'), findsOneWidget);
    expect(find.text('1 pinned'), findsOneWidget);
    expect(find.text('All Reviews (4)'), findsOneWidget);

    // Card tiers: verified badge, relative time, rating-only fallback.
    expect(find.text('Verified Patient'), findsNWidgets(3));
    expect(find.text('2 days ago'), findsNWidgets(4));
    expect(find.text('View Details'), findsNWidgets(4));

    // Critical tab narrows to 1–2★ among the loaded reviews.
    await _tap(tester, find.text('Critical'));
    expect(find.text('Chitra Two'), findsOneWidget);
    expect(find.text('Dev One'), findsOneWidget);
    expect(find.text('Asha Five'), findsNothing);
    expect(find.text('2 critical of 4 loaded'), findsOneWidget);

    // Footer moderation runs the real toggle.
    await _tap(tester, find.text('Hidden').last);
    expect(find.text('Review is now visible on your website.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty search offers a reset', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No Reviews Found'), findsOneWidget);
    await _tap(tester, find.text('Reset filters'));
    expect(find.text('Asha Five'), findsOneWidget);
  });
}
