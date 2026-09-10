import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/prescriptions/data/repositories/mock_prescription_repository.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/domain/repositories/prescription_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase prescriptions are deferred.');
  }
  return MockPrescriptionRepository();
});
final prescriptionsProvider =
    AsyncNotifierProvider<PrescriptionsController, PagedState<Prescription>>(
      PrescriptionsController.new,
    );
final prescriptionPatientsProvider = FutureProvider<List<PrescriptionPatient>>((
  ref,
) async {
  final repository = ref.watch(prescriptionRepositoryProvider);
  final subscription = repository.watchPatientChanges().listen(
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(subscription.cancel);
  final result = await repository.listPatients();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});

class PrescriptionsController extends AsyncNotifier<PagedState<Prescription>> {
  static const pageSize = 10;
  String _search = '';
  DateTime? _date = _today();
  DateTime? get selectedDate => _date;
  PrescriptionRepository get _repo => ref.read(prescriptionRepositoryProvider);
  @override
  Future<PagedState<Prescription>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _firstPage();
  }

  Future<PagedState<Prescription>> _firstPage() async {
    final result = await _repo.list(
      const PageRequest(limit: pageSize),
      search: _search,
      date: _date,
    );
    return result.fold(
      onSuccess: (page) => PagedState(
        items: page.items,
        nextOffset: page.nextOffset,
        hasMore: page.hasMore,
        totalCount: page.totalCount,
      ),
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_firstPage);
  Future<void> search(String value) async {
    _search = value;
    await refresh();
  }

  Future<void> filterDate(DateTime? value) async {
    _date = value == null ? null : DateTime(value.year, value.month, value.day);
    await refresh();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      PagedState(
        items: current.items,
        nextOffset: current.nextOffset,
        hasMore: current.hasMore,
        isLoadingMore: true,
        totalCount: current.totalCount,
      ),
    );
    final result = await _repo.list(
      PageRequest(offset: current.nextOffset!, limit: pageSize),
      search: _search,
      date: _date,
    );
    state = result.fold(
      onSuccess: (page) => AsyncData(
        PagedState(
          items: [...current.items, ...page.items],
          nextOffset: page.nextOffset,
          hasMore: page.hasMore,
          totalCount: page.totalCount,
        ),
      ),
      onFailure: (failure) => AsyncError(failure, StackTrace.current),
    );
  }

  Future<String?> create(PrescriptionDraft draft) async {
    final result = await _repo.create(draft);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (f) => f.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }

  Future<Result<Prescription>> createResult(PrescriptionDraft draft) async {
    final result = await _repo.create(draft);
    if (result is Success<Prescription>) await refresh();
    return result;
  }

  Future<Result<Prescription>> updatePrescription(
    String id,
    PrescriptionDraft draft,
  ) async {
    final result = await _repo.update(id, draft);
    if (result is Success<Prescription>) await refresh();
    return result;
  }

  Future<String?> delete(String id) async {
    final result = await _repo.delete(id);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (f) => f.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }

  Future<String?> deleteMany(Set<String> ids) async {
    final result = await _repo.deleteMany(ids);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
