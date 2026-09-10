import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';
import 'package:doctylia_app/features/reviews/domain/repositories/review_repository.dart';

final class MockReviewRepository implements ReviewRepository {
  MockReviewRepository() : _items = _seed();
  final List<PatientReview> _items;
  @override
  Future<Result<PageResult<PatientReview>>> list(
    PageRequest page, {
    String search = '',
    ReviewFilter filter = ReviewFilter.all,
  }) => RepositoryGuard.run(() {
    final term = search.trim().toLowerCase();
    final rows =
        _items
            .where(
              (row) =>
                  term.isEmpty ||
                  row.patientName.toLowerCase().contains(term) ||
                  (row.reviewText ?? '').toLowerCase().contains(term),
            )
            .where(
              (row) => switch (filter) {
                ReviewFilter.all => true,
                ReviewFilter.fiveStars => row.rating == 5,
                ReviewFilter.verified => row.isVerified,
                ReviewFilter.hidden => !row.isVisible,
              },
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final end = (page.offset + page.limit + 1).clamp(0, rows.length);
    final lookahead = page.offset >= rows.length
        ? <PatientReview>[]
        : rows.sublist(page.offset, end);
    return PageResult.fromLookahead(
      rows: lookahead,
      request: page,
      totalCount: rows.length,
    );
  });
  @override
  Future<Result<ReviewStats>> getStats() => RepositoryGuard.run(
    () => ReviewStats(
      total: _items.length,
      averageRating: _items.isEmpty
          ? 0
          : _items.fold<int>(0, (sum, row) => sum + row.rating) / _items.length,
      verified: _items.where((row) => row.isVerified).length,
      pinned: _items.where((row) => row.isPinned).length,
    ),
  );
  @override
  Future<Result<void>> togglePinned(String id) =>
      RepositoryGuard.run(() => _toggle(id, pin: true));
  @override
  Future<Result<void>> toggleVisible(String id) =>
      RepositoryGuard.run(() => _toggle(id, pin: false));
  void _toggle(String id, {required bool pin}) {
    final index = _items.indexWhere((row) => row.id == id);
    if (index < 0) throw StateError('Review not found.');
    final row = _items[index];
    _items[index] = pin
        ? row.copyWith(isPinned: !row.isPinned)
        : row.copyWith(isVisible: !row.isVisible);
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

List<PatientReview> _seed() {
  final now = DateTime.now();
  const names = [
    'Ananya Sharma',
    'Rohan Mehta',
    'Meera Kapoor',
    'Kabir Singh',
    'Ishita Rao',
  ];
  const texts = [
    'The doctor listened carefully and explained everything clearly.',
    'A smooth booking experience and very thoughtful care.',
    'Professional, punctual, and genuinely helpful.',
  ];
  return List.generate(
    33,
    (index) => PatientReview(
      id: 'review-$index',
      patientName: names[index % names.length],
      rating: 3 + index % 3,
      reviewText: texts[index % texts.length],
      isPinned: index % 9 == 0,
      isVerified: index % 3 != 0,
      isVisible: index % 7 != 0,
      createdAt: now.subtract(Duration(days: index * 2)),
    ),
  );
}
