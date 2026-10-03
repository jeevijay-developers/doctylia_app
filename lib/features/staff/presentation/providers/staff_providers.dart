import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/features/staff/data/repositories/mock_staff_repository.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_member.dart';
import 'package:doctylia_app/features/staff/domain/repositories/staff_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase staff management is deferred.');
  }
  return MockStaffRepository();
});

final staffMembersProvider =
    AsyncNotifierProvider<StaffController, PagedState<StaffMember>>(
      StaffController.new,
    );

class StaffController extends AsyncNotifier<PagedState<StaffMember>> {
  String _search = '';
  StaffRepository get _repo => ref.read(staffRepositoryProvider);

  @override
  Future<PagedState<StaffMember>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _first();
  }

  Future<PagedState<StaffMember>> _first() async {
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

  Future<String?> save(StaffDraft draft) => _mutate(() => _repo.save(draft));
  Future<String?> setStatus(String id, StaffStatus status) =>
      _mutate(() => _repo.setStatus(id, status));
  Future<String?> resetPassword(String id, String value) =>
      _message(() => _repo.resetPassword(id, value));
  Future<String?> delete(String id) => _mutate(() => _repo.delete(id));

  Future<String?> _mutate<T>(Future<Result<T>> Function() operation) async {
    final result = await operation();
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }

  Future<String?> _message<T>(Future<Result<T>> Function() operation) async {
    final result = await operation();
    return result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
  }
}
