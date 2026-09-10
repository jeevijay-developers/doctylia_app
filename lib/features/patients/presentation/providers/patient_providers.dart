import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/patients/data/repositories/mock_patient_repository.dart';
import 'package:doctylia_app/features/patients/domain/entities/medical_record.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:doctylia_app/features/patients/domain/repositories/patient_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase patients are deferred.');
  }
  return MockPatientRepository();
});
final patientsProvider =
    AsyncNotifierProvider<PatientsController, PagedState<Patient>>(
      PatientsController.new,
    );
final patientProvider = FutureProvider.family<Patient, String>((ref, id) async {
  final result = await ref.watch(patientRepositoryProvider).get(id);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});
final medicalRecordProvider =
    FutureProvider.family<MedicalRecordBundle, String>((ref, id) async {
      final result = await ref
          .watch(patientRepositoryProvider)
          .getMedicalRecord(id);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw failure,
      );
    });

class PatientsController extends AsyncNotifier<PagedState<Patient>> {
  static const pageSize = 10;
  String _search = '';
  DateTime? _registeredDate = _today();
  String get searchTerm => _search;
  DateTime? get registeredDate => _registeredDate;
  PatientRepository get _repo => ref.read(patientRepositoryProvider);
  @override
  Future<PagedState<Patient>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _firstPage();
  }

  Future<PagedState<Patient>> _firstPage() async {
    final result = await _repo.list(
      const PageRequest(limit: pageSize),
      search: _search,
      registeredDate: _registeredDate,
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
    _registeredDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    await refresh();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final result = await _repo.list(
      PageRequest(offset: current.nextOffset!, limit: pageSize),
      search: _search,
      registeredDate: _registeredDate,
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

  Future<String?> updatePatient(String id, PatientDraft draft) async {
    final result = await _repo.update(id, draft);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) {
      ref.invalidate(patientProvider(id));
      await refresh();
    }
    return error;
  }

  Future<Result<List<Patient>>> exportRows() => _repo.listForExport();

  Future<String?> create(PatientDraft draft) async {
    final result = await _repo.create(draft);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (f) => f.userMessage,
    );
    if (error == null) await refresh();
    return error;
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
