import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';

abstract interface class ReviewRepository {
  Future<Result<PageResult<PatientReview>>> list(
    PageRequest page, {
    String search = '',
    ReviewFilter filter = ReviewFilter.all,
  });
  Future<Result<ReviewStats>> getStats();
  Future<Result<void>> togglePinned(String id);
  Future<Result<void>> toggleVisible(String id);
  Stream<void> watchChanges();
}
