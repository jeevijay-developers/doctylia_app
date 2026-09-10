import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/reviews/data/repositories/mock_review_repository.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reviews paginate and stats use all rows', () async {
    final repo = MockReviewRepository();
    final page = (await repo.list(const PageRequest()) as Success).value;
    final stats = (await repo.getStats() as Success).value as ReviewStats;
    expect(page.items, hasLength(20));
    expect(page.hasMore, isTrue);
    expect(stats.total, 33);
    expect(stats.averageRating, inInclusiveRange(1, 5));
  });
  test('review pin and visibility mutations persist', () async {
    final repo = MockReviewRepository();
    final page = (await repo.list(const PageRequest()) as Success).value;
    final row = page.items.first as PatientReview;
    await repo.togglePinned(row.id);
    await repo.toggleVisible(row.id);
    final updated =
        ((await repo.list(const PageRequest()) as Success).value.items
                .firstWhere((item) => item.id == row.id))
            as PatientReview;
    expect(updated.isPinned, !row.isPinned);
    expect(updated.isVisible, !row.isVisible);
  });

  test('review filters are applied before pagination', () async {
    final repo = MockReviewRepository();
    final fiveStars =
        (await repo.list(const PageRequest(), filter: ReviewFilter.fiveStars)
                as Success)
            .value;
    final verified =
        (await repo.list(const PageRequest(), filter: ReviewFilter.verified)
                as Success)
            .value;
    final hidden =
        (await repo.list(const PageRequest(), filter: ReviewFilter.hidden)
                as Success)
            .value;

    final fiveStarRows = (fiveStars.items as List).cast<PatientReview>();
    final verifiedRows = (verified.items as List).cast<PatientReview>();
    final hiddenRows = (hidden.items as List).cast<PatientReview>();

    expect(fiveStarRows.every((row) => row.rating == 5), isTrue);
    expect(verifiedRows.every((row) => row.isVerified), isTrue);
    expect(hiddenRows.every((row) => !row.isVisible), isTrue);
  });
}
