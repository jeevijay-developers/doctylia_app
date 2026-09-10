import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';
import 'package:doctylia_app/features/support/domain/repositories/support_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase support is deferred.');
  }
  return MockSupportRepository();
});

final supportTicketsProvider =
    AsyncNotifierProvider<SupportController, PagedState<SupportTicket>>(
      SupportController.new,
    );

class SupportController extends AsyncNotifier<PagedState<SupportTicket>> {
  SupportRepository get _repo => ref.read(supportRepositoryProvider);
  @override
  Future<PagedState<SupportTicket>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _first();
  }

  Future<PagedState<SupportTicket>> _first() async {
    final result = await _repo.list(const PageRequest());
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

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final result = await _repo.list(PageRequest(offset: current.nextOffset!));
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

  Future<String?> create(SupportTicketDraft draft) async {
    final result = await _repo.create(draft);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }
}
