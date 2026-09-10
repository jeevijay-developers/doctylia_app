import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/reviews/data/repositories/mock_review_repository.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';
import 'package:doctylia_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase reviews are deferred.');
  }
  return MockReviewRepository();
});
final reviewStatsProvider = FutureProvider<ReviewStats>((ref) async {
  final result = await ref.read(reviewRepositoryProvider).getStats();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});
final reviewsProvider =
    AsyncNotifierProvider<ReviewsController, PagedState<PatientReview>>(
      ReviewsController.new,
    );

class ReviewsController extends AsyncNotifier<PagedState<PatientReview>> {
  String _search = '';
  ReviewFilter _filter = ReviewFilter.all;
  ReviewRepository get _repo => ref.read(reviewRepositoryProvider);
  @override
  Future<PagedState<PatientReview>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _first();
  }

  Future<PagedState<PatientReview>> _first() async {
    final result = await _repo.list(
      const PageRequest(),
      search: _search,
      filter: _filter,
    );
    return result.fold(
      onSuccess: (page) => PagedState(
        items: page.items,
        nextOffset: page.nextOffset,
        hasMore: page.hasMore,
      ),
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_first);
  Future<void> search(String value) async {
    _search = value;
    await refresh();
  }

  Future<void> filter(ReviewFilter value) async {
    if (_filter == value) return;
    _filter = value;
    await refresh();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final result = await _repo.list(
      PageRequest(offset: current.nextOffset!),
      search: _search,
      filter: _filter,
    );
    state = result.fold(
      onSuccess: (page) => AsyncData(
        PagedState(
          items: [...current.items, ...page.items],
          nextOffset: page.nextOffset,
          hasMore: page.hasMore,
        ),
      ),
      onFailure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }

  Future<String?> togglePin(String id) => _mutate(() => _repo.togglePinned(id));
  Future<String?> toggleVisible(String id) =>
      _mutate(() => _repo.toggleVisible(id));
  Future<String?> _mutate(Future<Result<void>> Function() action) async {
    final result = await action();
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) {
      ref.invalidate(reviewStatsProvider);
      await refresh();
    }
    return error;
  }
}
