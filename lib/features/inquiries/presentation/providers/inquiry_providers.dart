import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/features/inquiries/data/repositories/mock_inquiry_repository.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';
import 'package:doctylia_app/features/inquiries/domain/repositories/inquiry_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inquiryRepositoryProvider = Provider<InquiryRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase inquiries are deferred.');
  }
  return MockInquiryRepository();
});
final inquiryStatsProvider = FutureProvider<InquiryStats>((ref) async {
  final result = await ref.read(inquiryRepositoryProvider).getStats();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});
final inquiriesProvider =
    AsyncNotifierProvider<InquiriesController, PagedState<PatientInquiry>>(
      InquiriesController.new,
    );

class InquiriesController extends AsyncNotifier<PagedState<PatientInquiry>> {
  String _search = '';
  InquiryStatus? _status;
  InquiryRepository get _repo => ref.read(inquiryRepositoryProvider);
  @override
  Future<PagedState<PatientInquiry>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: () async {
        ref.invalidate(inquiryStatsProvider);
        await refresh();
      },
    );
    ref.onDispose(changes.dispose);
    return _first();
  }

  Future<PagedState<PatientInquiry>> _first() async {
    final result = await _repo.list(
      const PageRequest(),
      search: _search,
      status: _status,
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

  Future<void> filter(InquiryStatus? value) async {
    _status = value;
    await refresh();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final result = await _repo.list(
      PageRequest(offset: current.nextOffset!),
      search: _search,
      status: _status,
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

  Future<String?> setStatus(String id, InquiryStatus status) async {
    final result = await _repo.setStatus(id, status);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) {
      ref.invalidate(inquiryStatsProvider);
      await refresh();
    }
    return error;
  }
}
