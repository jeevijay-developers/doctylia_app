import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/blog/data/repositories/mock_blog_repository.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';
import 'package:doctylia_app/features/blog/domain/repositories/blog_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase blog is deferred.');
  }
  return MockBlogRepository();
});
final blogPostsProvider =
    AsyncNotifierProvider<BlogPostsController, PagedState<BlogPost>>(
      BlogPostsController.new,
    );

class BlogPostsController extends AsyncNotifier<PagedState<BlogPost>> {
  String _search = '';
  BlogRepository get _repo => ref.read(blogRepositoryProvider);
  @override
  Future<PagedState<BlogPost>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _first();
  }

  Future<PagedState<BlogPost>> _first() async {
    final result = await _repo.list(const PageRequest(), search: _search);
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

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final result = await _repo.list(
      PageRequest(offset: current.nextOffset!),
      search: _search,
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

  Future<String?> save(BlogPostDraft draft) async {
    final result = await _repo
        .save(draft)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => const Failure<BlogPost>(
            RemoteServiceFailure(
              'Saving is taking longer than expected. Refresh the blog list before retrying.',
            ),
          ),
        );
    return result.fold(
      onSuccess: (saved) {
        final current = state.value;
        if (current == null) {
          unawaited(refresh());
          return null;
        }
        final existingIndex = current.items.indexWhere(
          (item) => item.id == saved.id,
        );
        final items = [...current.items];
        if (existingIndex < 0) {
          items.insert(0, saved);
        } else {
          items[existingIndex] = saved;
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        state = AsyncData(
          PagedState(
            items: items,
            nextOffset: current.nextOffset,
            hasMore: current.hasMore,
            totalCount: existingIndex < 0 && current.totalCount != null
                ? current.totalCount! + 1
                : current.totalCount,
          ),
        );
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  Future<String?> togglePublished(String id) =>
      _mutate(() => _repo.togglePublished(id));
  Future<String?> delete(String id) => _mutate(() => _repo.delete(id));
  Future<Result<String>> uploadCover(BlogImageUpload upload) =>
      _repo.uploadCoverImage(upload);
  Future<AiBlogDraft> generate(String topic) async {
    final result = await _repo.generateDraft(topic);
    return result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw failure,
    );
  }

  Future<String?> _mutate(Future<dynamic> Function() action) async {
    final result = await action();
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }
}
