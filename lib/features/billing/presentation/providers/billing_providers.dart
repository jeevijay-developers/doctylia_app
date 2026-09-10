import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/realtime/repository_change_coordinator.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/billing/data/repositories/mock_billing_repository.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:doctylia_app/features/billing/domain/repositories/billing_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Supabase billing is deferred.');
  }
  return MockBillingRepository();
});

final billingSummaryProvider = FutureProvider<BillingSummary>((ref) async {
  final result = await ref.read(billingRepositoryProvider).getSummary();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});

final billingTransactionsProvider =
    AsyncNotifierProvider<
      BillingTransactionsController,
      PagedState<BillingTransaction>
    >(BillingTransactionsController.new);
final invoicesProvider =
    AsyncNotifierProvider<InvoicesController, PagedState<Invoice>>(
      InvoicesController.new,
    );

class BillingTransactionsController
    extends AsyncNotifier<PagedState<BillingTransaction>> {
  BillingQuery _query = BillingQuery.currentMonth();
  BillingRepository get _repo => ref.read(billingRepositoryProvider);
  @override
  Future<PagedState<BillingTransaction>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: () async {
        ref.invalidate(billingSummaryProvider);
        await refresh();
      },
    );
    ref.onDispose(changes.dispose);
    return _firstPage();
  }

  Future<PagedState<BillingTransaction>> _firstPage() async {
    final result = await _repo.listTransactions(const PageRequest(), _query);
    return result.fold(
      onSuccess: (page) => PagedState(
        items: page.items,
        nextOffset: page.nextOffset,
        hasMore: page.hasMore,
      ),
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_firstPage);
  Future<void> search(String value) async {
    _query = BillingQuery(
      search: value,
      paymentStatus: _query.paymentStatus,
      startDate: _query.startDate,
      endDateExclusive: _query.endDateExclusive,
    );
    await refresh();
  }

  Future<void> filter(BillingPaymentStatus? value) async {
    _query = BillingQuery(
      search: _query.search,
      paymentStatus: value,
      startDate: _query.startDate,
      endDateExclusive: _query.endDateExclusive,
    );
    await refresh();
  }

  Future<void> filterDates(DateTime? start, DateTime? endExclusive) async {
    _query = BillingQuery(
      search: _query.search,
      paymentStatus: _query.paymentStatus,
      startDate: start,
      endDateExclusive: endExclusive,
    );
    await refresh();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final result = await _repo.listTransactions(
      PageRequest(offset: current.nextOffset!),
      _query,
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

  Future<Result<List<BillingTransaction>>> export() =>
      _repo.exportTransactions(_query);
}

class InvoicesController extends AsyncNotifier<PagedState<Invoice>> {
  String _search = '';
  BillingRepository get _repo => ref.read(billingRepositoryProvider);
  @override
  Future<PagedState<Invoice>> build() {
    final changes = RepositoryChangeCoordinator(
      changes: _repo.watchChanges(),
      refresh: () async {
        ref.invalidate(billingSummaryProvider);
        await refresh();
      },
    );
    ref.onDispose(changes.dispose);
    return _firstPage();
  }

  Future<PagedState<Invoice>> _firstPage() async {
    final result = await _repo.listInvoices(
      const PageRequest(),
      search: _search,
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

  Future<void> refresh() async => state = await AsyncValue.guard(_firstPage);
  Future<void> search(String value) async {
    _search = value;
    await refresh();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final result = await _repo.listInvoices(
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
}
