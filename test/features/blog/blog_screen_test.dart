import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';
import 'package:doctylia_app/features/blog/domain/repositories/blog_repository.dart';
import 'package:doctylia_app/features/blog/presentation/providers/blog_providers.dart';
import 'package:doctylia_app/features/blog/presentation/screens/blog_screen.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_preferences_store.dart';

final _now = DateTime(2026, 10, 20);

BlogPost _post(
  String id, {
  required String title,
  required bool published,
  String? category,
  String? content,
  int daysAgo = 0,
}) => BlogPost(
  id: id,
  title: title,
  excerpt: 'Short excerpt for $title.',
  content: content,
  category: category,
  isPublished: published,
  publishedAt: published ? _now.subtract(Duration(days: daysAgo)) : null,
  createdAt: _now.subtract(Duration(days: daysAgo)),
  updatedAt: _now,
);

final _posts = [
  _post('draft', title: 'Sleep hygiene draft', published: false),
  _post(
    'heart',
    title: 'Heart health basics',
    published: true,
    category: 'Heart Health',
    content: List.filled(450, 'word').join(' '),
    daysAgo: 1,
  ),
  _post(
    'food',
    title: 'Eating well every day',
    published: true,
    category: 'Nutrition',
    daysAgo: 2,
  ),
];

typedef _Query = ({String search, String? category, bool? published});

final class _FakeRepository implements BlogRepository {
  _FakeRepository({this.gate});

  final Completer<void>? gate;
  final queries = <_Query>[];

  @override
  Future<Result<PageResult<BlogPost>>> list(
    PageRequest page, {
    String search = '',
    String? category,
    bool? published,
  }) async {
    queries.add((search: search, category: category, published: published));
    await gate?.future;
    final rows = _posts
        .where(
          (post) =>
              (category == null || post.category == category) &&
              (published == null || post.isPublished == published),
        )
        .toList(growable: false);
    return Success(PageResult(items: rows, hasMore: false));
  }

  @override
  Future<Result<BlogStats>> getStats() async =>
      const Success(BlogStats(total: 12, published: 9));

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _doctor = DoctorProfile(
  id: 'doctor',
  fullName: 'Meera Rao',
  slug: 'meera-rao',
  consultationFee: 500,
  createdAt: _now,
  gstRegistered: false,
  onboardingCompleted: true,
  planStatus: PlanStatus.active,
  planTier: PlanTier.pro,
  trialStart: _now,
  updatedAt: _now,
);

Widget _app(BlogRepository repository) => ProviderScope(
  overrides: [
    appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
    preferencesStoreProvider.overrideWithValue(FakePreferencesStore()),
    blogRepositoryProvider.overrideWithValue(repository),
    doctorProfileProvider.overrideWithValue(_doctor),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const BlogScreen()),
);

Future<void> _pump(WidgetTester tester, BlogRepository repository) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repository));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  // Cards mounted in the last frame start their entrance on a zero-delay
  // timer (flutter_animate); let it fire and the entrance finish.
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a skeleton (no spinner) until posts load', (tester) async {
    final gate = Completer<void>();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_FakeRepository(gate: gate)));
    await tester.pump();
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Heart health basics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header counts, spotlight, read time and share links', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository());
    expect(find.text('Health Journal & Insights'), findsOneWidget);
    expect(find.text('9 published · 3 drafts'), findsOneWidget);
    expect(find.text('12 articles'), findsOneWidget);

    // The newest *published* post is spotlighted, ahead of a newer draft.
    expect(find.text('SPOTLIGHT'), findsOneWidget);
    expect(find.text('Featured'), findsOneWidget);
    final heroTop = tester.getTopLeft(find.text('Heart health basics')).dy;
    expect(
      tester.getTopLeft(find.text('Sleep hygiene draft')).dy,
      greaterThan(heroTop),
    );
    // 450 words at 200 wpm, as on the web.
    expect(find.text('3 min read'), findsOneWidget);
    expect(find.text('Dr. Meera Rao'), findsNWidgets(3));
    // Only the two published posts can be shared.
    expect(find.byTooltip('Share post'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('topic pills and status tabs query the repository', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    await _tap(tester, find.text('Nutrition').first);
    expect(repository.queries.last, (
      search: '',
      category: 'Nutrition',
      published: null,
    ));
    expect(find.text('Eating well every day'), findsOneWidget);
    expect(find.text('Heart health basics'), findsNothing);

    await _tap(tester, find.text('All Topics'));
    await _tap(tester, find.text('Drafts'));
    expect(repository.queries.last.published, isFalse);
    expect(find.text('Latest draft'), findsWidgets);
    expect(find.text('Sleep hygiene draft'), findsOneWidget);
  });

  testWidgets('empty results offer a reset that clears every filter', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    await _tap(tester, find.text('Fitness'));
    expect(find.text('No Articles Found'), findsOneWidget);

    await _tap(tester, find.text('Reset filters'));
    expect(repository.queries.last, (
      search: '',
      category: null,
      published: null,
    ));
    expect(find.text('No Articles Found'), findsNothing);
    expect(find.text('Heart health basics'), findsOneWidget);
  });
}
