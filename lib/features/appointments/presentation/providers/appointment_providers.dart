import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/appointments/data/repositories/mock_appointment_repository.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment_query.dart';
import 'package:doctylia_app/features/appointments/domain/repositories/appointment_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase appointments are deferred.');
  }
  return MockAppointmentRepository();
});

final appointmentsProvider =
    AsyncNotifierProvider<AppointmentsController, PagedState<Appointment>>(
      AppointmentsController.new,
    );

final appointmentQueryProvider =
    NotifierProvider<AppointmentQueryController, AppointmentQuery>(
      AppointmentQueryController.new,
    );

final appointmentSummaryProvider = FutureProvider<AppointmentSummary>((
  ref,
) async {
  final repository = ref.watch(appointmentRepositoryProvider);
  final dates = ref.watch(
    appointmentQueryProvider.select(
      (query) => (from: query.dateFrom, to: query.dateTo),
    ),
  );
  final query = AppointmentQuery(dateFrom: dates.from, dateTo: dates.to);
  final result = await repository.summary(query);
  return result.fold(
    onSuccess: (summary) => summary,
    onFailure: (failure) => throw failure,
  );
});

class AppointmentQueryController extends Notifier<AppointmentQuery> {
  @override
  AppointmentQuery build() {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    return AppointmentQuery(dateFrom: date, dateTo: date);
  }

  void setSearch(String value) => state = state.copyWith(search: value);

  void setStatus(AppointmentStatus? value) =>
      state = state.copyWith(status: value, clearStatus: value == null);

  void setDates(DateTime? from, DateTime? to) => state = state.copyWith(
    dateFrom: from,
    dateTo: to,
    clearDates: from == null && to == null,
  );
}

class AppointmentsController extends AsyncNotifier<PagedState<Appointment>> {
  static const pageSize = 10;
  AppointmentRepository get _repo => ref.read(appointmentRepositoryProvider);
  AppointmentQuery get query => ref.read(appointmentQueryProvider);

  @override
  Future<PagedState<Appointment>> build() {
    final currentQuery = ref.watch(appointmentQueryProvider);
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: refresh,
    );
    ref.onDispose(changes.dispose);
    return _firstPage(currentQuery);
  }

  Future<PagedState<Appointment>> _firstPage(AppointmentQuery query) async {
    final result = await _repo.list(const PageRequest(limit: pageSize), query);
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

  Future<void> refresh() async {
    ref.invalidate(appointmentSummaryProvider);
    state = await AsyncValue.guard(() => _firstPage(query));
  }

  Future<void> search(String value) async {
    ref.read(appointmentQueryProvider.notifier).setSearch(value);
  }

  Future<void> filterStatus(AppointmentStatus? value) async {
    ref.read(appointmentQueryProvider.notifier).setStatus(value);
  }

  Future<void> filterDates(DateTime? from, DateTime? to) async {
    ref.read(appointmentQueryProvider.notifier).setDates(from, to);
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
      query,
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

  Future<String?> updateAppointment(String id, AppointmentDraft draft) async {
    final result = await _repo.update(id, draft);
    return _refreshAfter(result);
  }

  Future<String?> updatePaymentStatus(
    String id,
    AppointmentPaymentStatus status,
  ) async {
    final result = await _repo.updatePaymentStatus(id, status);
    return _refreshAfter(result);
  }

  Future<String?> create(AppointmentDraft draft) async {
    final result = await _repo
        .create(draft)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => const Failure<Appointment>(
            RemoteServiceFailure(
              'The appointment could not be saved in time. Please try again.',
            ),
          ),
        );
    return result.fold(
      onSuccess: (appointment) {
        ref.invalidate(appointmentSummaryProvider);
        final current = state.value;
        if (current != null && _matchesQuery(appointment, query)) {
          state = AsyncData(
            PagedState(
              items: [
                appointment,
                ...current.items.where((item) => item.id != appointment.id),
              ],
              nextOffset: current.nextOffset,
              hasMore: current.hasMore,
              totalCount: (current.totalCount ?? current.items.length) + 1,
            ),
          );
        } else {
          unawaited(refresh());
        }
        return null;
      },
      onFailure: (failure) => failure.userMessage,
    );
  }

  bool _matchesQuery(Appointment item, AppointmentQuery value) {
    final term = value.search.trim().toLowerCase();
    final searchMatches =
        term.isEmpty ||
        item.patientName.toLowerCase().contains(term) ||
        item.patientPhone.toLowerCase().contains(term) ||
        (item.patientEmail?.toLowerCase().contains(term) ?? false) ||
        item.serviceName.toLowerCase().contains(term) ||
        (item.tokenNumber?.toLowerCase().contains(term) ?? false);
    final statusMatches = value.status == null || item.status == value.status;
    final date = DateTime(
      item.scheduledAt.year,
      item.scheduledAt.month,
      item.scheduledAt.day,
    );
    final from = value.dateFrom == null
        ? null
        : DateTime(
            value.dateFrom!.year,
            value.dateFrom!.month,
            value.dateFrom!.day,
          );
    final to = value.dateTo == null
        ? null
        : DateTime(value.dateTo!.year, value.dateTo!.month, value.dateTo!.day);
    final dateMatches =
        (from == null || !date.isBefore(from)) &&
        (to == null || !date.isAfter(to));
    return searchMatches && statusMatches && dateMatches;
  }

  Future<String?> updateStatus(String id, AppointmentStatus status) async {
    final result = await _repo.updateStatus(id, status);
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (f) => f.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }

  Future<String?> reschedule(String id, DateTime scheduledAt) async {
    final result = await _repo.reschedule(id, scheduledAt);
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

  Future<String?> deleteMany(List<String> ids) async {
    final result = await _repo.deleteMany(ids);
    return _refreshAfter(result);
  }

  Future<Result<ZoomMeetingLinks>> generateZoomMeeting(String id) async {
    final result = await _repo.generateZoomMeeting(id);
    if (result is Success<ZoomMeetingLinks>) await refresh();
    return result;
  }

  Future<String?> _refreshAfter(Result<void> result) async {
    final error = result.fold<String?>(
      onSuccess: (_) => null,
      onFailure: (failure) => failure.userMessage,
    );
    if (error == null) await refresh();
    return error;
  }
}
