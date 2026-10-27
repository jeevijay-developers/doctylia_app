import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/platform/csv_cell.dart';
import 'package:doctylia_app/core/platform/shared_file_cache.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:doctylia_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:doctylia_app/features/billing/presentation/widgets/invoice_sheet.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:share_plus/share_plus.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _compactMoney = NumberFormat.compactCurrency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// A pending online payment whose appointment date has passed. Billing has
/// no due dates, so "overdue" is derived on the device from this signal.
bool _isOverdue(BillingTransaction value) {
  if (value.paymentStatus != BillingPaymentStatus.pending) return false;
  final today = DateUtils.dateOnly(DateTime.now());
  return DateUtils.dateOnly(value.date).isBefore(today);
}

enum _BillingView { transactions, invoices }

/// Transaction status pills. All but [overdue] map 1:1 to the existing
/// server-side payment-status filter; [overdue] loads pending payments and
/// narrows them on the device.
enum _TxTab {
  all('All', null),
  paid('Paid', BillingPaymentStatus.paid),
  pending('Pending', BillingPaymentStatus.pending),
  overdue('Overdue', BillingPaymentStatus.pending),
  payAtClinic('Pay at Clinic', BillingPaymentStatus.payAtClinic),
  refunded('Refunded', BillingPaymentStatus.refunded);

  const _TxTab(this.label, this.serverStatus);

  final String label;
  final BillingPaymentStatus? serverStatus;
}

enum _DatePreset { thisMonth, last30, custom, all }

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeatureGate(
    feature: FeatureKey.billingInvoices,
    lockedChild: _LockedBilling(),
    child: _BillingContent(),
  );
}

class _BillingContent extends ConsumerStatefulWidget {
  const _BillingContent();

  @override
  ConsumerState<_BillingContent> createState() => _BillingContentState();
}

class _BillingContentState extends ConsumerState<_BillingContent> {
  _BillingView _view = _BillingView.transactions;
  _TxTab _tab = _TxTab.all;

  // Transactions date filter. The provider starts on the current month.
  _DatePreset _preset = _DatePreset.thisMonth;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTimeRange? _customRange;

  final _txSearch = TextEditingController();
  final _invoiceSearch = TextEditingController();
  Timer? _debounce;
  bool _exporting = false;

  /// Card entrances already played for the current results, per view.
  final Set<String> _animatedTx = {};
  final Set<String> _animatedInvoices = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _txSearch.dispose();
    _invoiceSearch.dispose();
    super.dispose();
  }

  TextEditingController get _search =>
      _view == _BillingView.transactions ? _txSearch : _invoiceSearch;

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    final view = _view;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (view == _BillingView.transactions) {
        ref.read(billingTransactionsProvider.notifier).search(value);
      } else {
        ref.read(invoicesProvider.notifier).search(value);
      }
    });
  }

  void _clearSearch() {
    _search.clear();
    _onSearchChanged('');
  }

  void _setView(_BillingView view) {
    if (view == _view) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _view = view;
      _animatedTx.clear();
      _animatedInvoices.clear();
    });
  }

  void _setTab(_TxTab tab) {
    if (tab == _tab) return;
    final serverChanged = tab.serverStatus != _tab.serverStatus;
    setState(() {
      _tab = tab;
      _animatedTx.clear();
    });
    if (serverChanged) {
      ref.read(billingTransactionsProvider.notifier).filter(tab.serverStatus);
    }
  }

  /// Summary tile tap: jump to the matching list.
  void _openStatus(_TxTab tab) {
    _setView(_BillingView.transactions);
    _setTab(tab);
  }

  Future<void> _setPreset(_DatePreset preset) async {
    if (preset == _DatePreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 5, 12, 31),
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: DateUtils.dateOnly(now.subtract(const Duration(days: 6))),
              end: DateUtils.dateOnly(now),
            ),
      );
      if (picked == null || !mounted) return;
      _customRange = picked;
    }
    setState(() {
      _preset = preset;
      if (preset == _DatePreset.thisMonth) {
        _month = DateTime(DateTime.now().year, DateTime.now().month);
      }
    });
    _applyDates();
  }

  void _stepMonth(int amount) {
    setState(() {
      _preset = _DatePreset.thisMonth;
      _month = DateTime(_month.year, _month.month + amount);
    });
    _applyDates();
  }

  void _applyDates() {
    final today = DateUtils.dateOnly(DateTime.now());
    final (DateTime? start, DateTime? end) = switch (_preset) {
      _DatePreset.thisMonth => (
        _month,
        DateTime(_month.year, _month.month + 1),
      ),
      _DatePreset.last30 => (
        today.subtract(const Duration(days: 29)),
        today.add(const Duration(days: 1)),
      ),
      _DatePreset.custom => (
        DateUtils.dateOnly(_customRange!.start),
        DateUtils.dateOnly(_customRange!.end).add(const Duration(days: 1)),
      ),
      _DatePreset.all => (null, null),
    };
    setState(_animatedTx.clear);
    ref.read(billingTransactionsProvider.notifier).filterDates(start, end);
  }

  /// "Reset filters": clear search and status, widen to all dates.
  void _resetFilters() {
    if (_search.text.isNotEmpty) _clearSearch();
    if (_view == _BillingView.transactions) {
      _setTab(_TxTab.all);
      if (_preset != _DatePreset.all) _setPreset(_DatePreset.all);
    }
  }

  String get _dateLabel => switch (_preset) {
    _DatePreset.thisMonth => DateFormat('MMMM yyyy').format(_month),
    _DatePreset.last30 => 'Last 30 days',
    _DatePreset.custom =>
      '${DateFormat('d MMM').format(_customRange!.start)} – '
          '${DateFormat('d MMM yyyy').format(_customRange!.end)}',
    _DatePreset.all => 'All dates',
  };

  Future<void> _refresh() async {
    ref.invalidate(billingSummaryProvider);
    if (_view == _BillingView.transactions) {
      await ref.read(billingTransactionsProvider.notifier).refresh();
    } else {
      await ref.read(invoicesProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(billingSummaryProvider);
    final transactions = ref.watch(billingTransactionsProvider);
    final invoices = ref.watch(invoicesProvider);
    // A new query is loading: its results should cascade in again.
    if (transactions.isLoading && !transactions.isRefreshing) {
      _animatedTx.clear();
    }
    if (invoices.isLoading && !invoices.isRefreshing) {
      _animatedInvoices.clear();
    }
    final isTx = _view == _BillingView.transactions;

    return DashboardShadcnScope(
      child: AppMotion(
        enabled: true,
        child: Column(
          children: [
            _Toolbar(
              view: _view,
              onViewChanged: _setView,
              searchController: _search,
              searchHint: isTx
                  ? 'Search patient or service'
                  : 'Search invoice #, patient or service',
              onSearchChanged: _onSearchChanged,
              onClearSearch: _clearSearch,
              exporting: _exporting,
              onExport: isTx ? _exportCsv : null,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _StatGrid(
                        summary: summary,
                        onOpenInvoices: () => _setView(_BillingView.invoices),
                        onOpenStatus: _openStatus,
                      ),
                    ),
                    if (isTx) ...[
                      SliverToBoxAdapter(
                        child: _DateFilterRow(
                          label: _dateLabel,
                          preset: _preset,
                          onPreset: _setPreset,
                          onPrevious: () => _stepMonth(-1),
                          onNext: () => _stepMonth(1),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _StatusTabs(selected: _tab, onChanged: _setTab),
                      ),
                      ..._transactionSlivers(transactions),
                    ] else
                      ..._invoiceSlivers(invoices),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Transactions ──────────────────────────────────────────────────────
  List<Widget> _transactionSlivers(
    AsyncValue<PagedState<BillingTransaction>> state,
  ) => state.when(
    loading: () => const [
      SliverToBoxAdapter(child: _ListSkeleton(invoices: false)),
    ],
    error: (error, _) => [
      SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(
          message: error is AppFailure
              ? error.userMessage
              : 'Could not load transactions.',
          onRetry: () =>
              ref.read(billingTransactionsProvider.notifier).refresh(),
        ),
      ),
    ],
    data: (page) {
      final visible = _tab == _TxTab.overdue
          ? page.items.where(_isOverdue).toList(growable: false)
          : page.items;
      final filtered =
          _txSearch.text.trim().isNotEmpty ||
          _tab != _TxTab.all ||
          _preset != _DatePreset.all;
      if (visible.isEmpty) {
        final narrowedOnly = page.items.isNotEmpty;
        return [
          SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.credit_card_off_rounded,
              title: narrowedOnly
                  ? 'No overdue payments'
                  : 'No Transactions Found',
              message: narrowedOnly
                  ? (page.hasMore
                        ? 'None of the loaded pending payments are past '
                              'their appointment date. Load more, or view all.'
                        : 'Every pending payment is still before its '
                              'appointment date.')
                  : filtered
                  ? 'No payments match this search, status or date range.'
                  : 'Payments appear here as patients book and pay.',
              actionLabel: narrowedOnly
                  ? 'Show all'
                  : filtered
                  ? 'Reset filters'
                  : null,
              onAction: narrowedOnly
                  ? () => _setTab(_TxTab.all)
                  : _resetFilters,
              secondaryLabel: narrowedOnly && page.hasMore ? 'Load more' : null,
              onSecondary: () =>
                  ref.read(billingTransactionsProvider.notifier).loadMore(),
            ),
          ),
        ];
      }
      return [
        SliverToBoxAdapter(
          child: _ResultsRow(
            text: _tab == _TxTab.overdue
                ? '${visible.length} overdue of ${page.items.length} loaded'
                : '${visible.length}${page.hasMore ? '+' : ''} '
                      '${visible.length == 1 ? 'transaction' : 'transactions'}',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          sliver: SliverList.separated(
            itemCount: visible.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => index == visible.length
                ? PagedListFooter(
                    hasMore: page.hasMore,
                    onLoadMore: () => ref
                        .read(billingTransactionsProvider.notifier)
                        .loadMore(),
                  )
                : _entrance(
                    _animatedTx,
                    visible[index].id,
                    index,
                    _TransactionCard(transaction: visible[index]),
                  ),
          ),
        ),
      ];
    },
  );

  // ── Invoices ──────────────────────────────────────────────────────────
  List<Widget> _invoiceSlivers(AsyncValue<PagedState<Invoice>> state) =>
      state.when(
        loading: () => const [
          SliverToBoxAdapter(child: _ListSkeleton(invoices: true)),
        ],
        error: (error, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppErrorView(
              message: error is AppFailure
                  ? error.userMessage
                  : 'Could not load invoices.',
              onRetry: () => ref.read(invoicesProvider.notifier).refresh(),
            ),
          ),
        ],
        data: (page) {
          if (page.items.isEmpty) {
            final filtered = _invoiceSearch.text.trim().isNotEmpty;
            return [
              SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No Invoices Found',
                  message: filtered
                      ? 'No invoice matches this search.'
                      : 'Invoices appear after a payment is marked paid.',
                  actionLabel: filtered ? 'Reset filters' : null,
                  onAction: _resetFilters,
                ),
              ),
            ];
          }
          return [
            SliverToBoxAdapter(
              child: _ResultsRow(
                text:
                    '${page.items.length}${page.hasMore ? '+' : ''} '
                    '${page.items.length == 1 ? 'invoice' : 'invoices'}',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              sliver: SliverList.separated(
                itemCount: page.items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => index == page.items.length
                    ? PagedListFooter(
                        hasMore: page.hasMore,
                        onLoadMore: () =>
                            ref.read(invoicesProvider.notifier).loadMore(),
                      )
                    : _entrance(
                        _animatedInvoices,
                        page.items[index].id,
                        index,
                        _InvoiceCard(invoice: page.items[index]),
                      ),
              ),
            ),
          ];
        },
      );

  /// Cards cascade in (40ms apart) the first time each result shows; cards
  /// already shown don't replay when scrolled back into view.
  Widget _entrance(Set<String> played, String id, int index, Widget card) =>
      AppEntrance(
        key: ValueKey(id),
        index: index < 8 ? index : 0,
        step: const Duration(milliseconds: 40),
        offset: const Offset(0, 0.08),
        enabled: played.add(id),
        child: card,
      );

  // ── CSV export (unchanged behavior) ───────────────────────────────────
  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final result = await ref
        .read(billingTransactionsProvider.notifier)
        .export();
    if (!mounted) return;
    await result.fold(
      onSuccess: (rows) async {
        if (rows.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions to export.')),
          );
          return;
        }
        final profile = ref.read(doctorProfileProvider);
        final safeName = (profile?.fullName ?? 'doctor')
            .replaceAll(RegExp('[^a-zA-Z0-9]+'), '-')
            .toLowerCase();
        final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await SharedFileCache.shareText(
          fileName: 'doctylia-transactions-$safeName-$date.csv',
          content: '﻿${_transactionsCsv(rows)}',
          mimeType: 'text/csv',
          subject: 'Doctylia transactions export',
        );
      },
      onFailure: (failure) async => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
    if (mounted) setState(() => _exporting = false);
  }

  String _transactionsCsv(List<BillingTransaction> rows) {
    const headers = [
      'Patient Name',
      'Service',
      'Date',
      'Amount (INR)',
      'Payment Status',
      'Appointment Status',
      'Mock',
    ];
    final output = <List<Object?>>[
      headers,
      for (final row in rows)
        [
          row.patientName,
          row.serviceName,
          DateFormat('yyyy-MM-dd').format(row.date),
          row.amount,
          _paymentStatusValue(row.paymentStatus),
          row.appointmentStatus,
          row.isMock ? 'yes' : 'no',
        ],
    ];
    return output.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  static String _csvCell(Object? value) {
    final text = csvSafeText('${value ?? ''}');
    return RegExp('[",\\n]').hasMatch(text)
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  static String _paymentStatusValue(BillingPaymentStatus value) =>
      switch (value) {
        BillingPaymentStatus.paid => 'paid',
        BillingPaymentStatus.pending => 'pending',
        BillingPaymentStatus.refunded => 'refunded',
        BillingPaymentStatus.payAtClinic => 'pay_at_clinic',
      };
}

// ── Toolbar: view switch + search ────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.view,
    required this.onViewChanged,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.exporting,
    required this.onExport,
  });

  final _BillingView view;
  final ValueChanged<_BillingView> onViewChanged;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool exporting;

  /// Null hides the export action (Invoices view).
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: DashboardTokens.border(context)),
      ),
    ),
    child: Column(
      children: [
        _ViewSwitch(view: view, onChanged: onViewChanged),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                // A fresh field per view, so each keeps its own text.
                key: ValueKey(view),
                controller: searchController,
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: searchHint,
                  hintStyle: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: AppColors.subtleText(context),
                  ),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                  filled: true,
                  fillColor: AppColors.secondarySurface(
                    context,
                  ).withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: _border(DashboardTokens.border(context)),
                  focusedBorder: _border(AppColors.primary, width: 1.4),
                ),
              ),
            ),
            if (onExport != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: 'Export CSV',
                child: shadcn.IconButton.outline(
                  onPressed: exporting ? null : onExport,
                  icon: Icon(
                    exporting
                        ? Icons.hourglass_top_rounded
                        : Icons.file_download_outlined,
                    size: 20,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Two-segment switch whose raised pill slides between Transactions and
/// Invoices.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.view, required this.onChanged});

  final _BillingView view;
  final ValueChanged<_BillingView> onChanged;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context),
        borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: view == _BillingView.transactions
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: DashboardTokens.shadow(context),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (value, label, icon) in [
                (
                  _BillingView.transactions,
                  'Transactions',
                  Icons.credit_card_rounded,
                ),
                (_BillingView.invoices, 'Invoices', Icons.receipt_long_rounded),
              ])
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: view == value,
                    child: InkWell(
                      onTap: () => onChanged(value),
                      borderRadius: BorderRadius.circular(9),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          // From the theme so the app font family carries
                          // through (a bare TextStyle would replace it).
                          style: Theme.of(context).textTheme.labelLarge!
                              .copyWith(
                                fontSize: 13,
                                fontWeight: view == value
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: view == value
                                    ? AppColors.onSurface(context)
                                    : AppColors.mutedText(context),
                              ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: view == value
                                    ? AppColors.primary600
                                    : AppColors.mutedText(context),
                              ),
                              const SizedBox(width: 7),
                              // Shrinks rather than overflowing with large
                              // accessibility text.
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Executive glance grid ────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.summary,
    required this.onOpenInvoices,
    required this.onOpenStatus,
  });

  final AsyncValue<BillingSummary> summary;
  final VoidCallback onOpenInvoices;
  final ValueChanged<_TxTab> onOpenStatus;

  static const _placeholder = BillingSummary(
    todayRevenue: 1200,
    weekRevenue: 8400,
    monthRevenue: 32000,
    paidCount: 10,
    pendingCount: 2,
    payAtClinicCount: 3,
    refundedCount: 1,
  );

  @override
  Widget build(BuildContext context) {
    final value = summary.value;
    if (value == null && summary.hasError) return const SizedBox.shrink();
    final grid = _grid(context, value ?? _placeholder);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: value == null ? _skeleton(context, grid) : grid,
    );
  }

  Widget _grid(BuildContext context, BillingSummary s) => Column(
    children: [
      AppEntrance(
        index: 0,
        step: const Duration(milliseconds: 60),
        child: _CollectedCard(summary: s, onTap: onOpenInvoices),
      ),
      const SizedBox(height: AppSpacing.xs),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatTile(
              order: 1,
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
              value: s.pendingCount,
              label: 'Pending',
              caption: 'Awaiting payment',
              onTap: () => onOpenStatus(_TxTab.pending),
            ),
            const SizedBox(width: AppSpacing.xs),
            _StatTile(
              order: 2,
              icon: Icons.storefront_rounded,
              color: AppColors.primary600,
              value: s.payAtClinicCount,
              label: 'Pay at Clinic',
              caption: 'Collect at visit',
              onTap: () => onOpenStatus(_TxTab.payAtClinic),
            ),
            const SizedBox(width: AppSpacing.xs),
            _StatTile(
              order: 3,
              icon: Icons.undo_rounded,
              color: AppColors.mutedText(context),
              value: s.refundedCount,
              label: 'Refunded',
              caption: 'Returned in full',
              onTap: () => onOpenStatus(_TxTab.refunded),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CollectedCard extends StatelessWidget {
  const _CollectedCard({required this.summary, required this.onTap});

  final BillingSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DashboardSurface(
    onTap: onTap,
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    child: Row(
      children: [
        const DashboardIconTile(
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.success,
          size: 42,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COLLECTED THIS MONTH',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardTokens.eyebrow(context),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AppCountUp(
                  value: summary.monthRevenue,
                  format: (v) => _money.format(v.round()),
                  delay: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _MiniStat(
                    label: 'Today',
                    value: _compactMoney.format(summary.todayRevenue),
                  ),
                  _MiniStat(
                    label: 'This week',
                    value: _compactMoney.format(summary.weekRevenue),
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: AppColors.subtleText(context)),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface(context),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text.rich(
      TextSpan(
        text: '$label  ',
        style: TextStyle(color: AppColors.mutedText(context)),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 11),
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.order,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final int order;
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AppEntrance(
      index: order,
      step: const Duration(milliseconds: 60),
      child: DashboardSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DashboardIconTile(icon: icon, color: color, size: 28),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppCountUp(
              value: value.toDouble(),
              format: (v) => '${v.round()}',
              delay: Duration(milliseconds: 150 + 60 * order),
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.subtleText(context),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Transaction filters ──────────────────────────────────────────────────

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow({
    required this.label,
    required this.preset,
    required this.onPreset,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final _DatePreset preset;
  final ValueChanged<_DatePreset> onPreset;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final stepping = preset == _DatePreset.thisMonth;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Flexible(
            child: PopupMenuButton<_DatePreset>(
              tooltip: 'Date range',
              onSelected: onPreset,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _DatePreset.thisMonth,
                  child: Text('This Month'),
                ),
                PopupMenuItem(
                  value: _DatePreset.last30,
                  child: Text('Last 30 Days'),
                ),
                PopupMenuItem(
                  value: _DatePreset.custom,
                  child: Text('Custom Range…'),
                ),
                PopupMenuItem(value: _DatePreset.all, child: Text('All dates')),
              ],
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: AppColors.primary600,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          label,
                          key: ValueKey(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary600,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary600,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (stepping) ...[
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: 'Previous month',
              child: shadcn.IconButton.ghost(
                onPressed: onPrevious,
                density: shadcn.ButtonDensity.icon,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
            ),
            Tooltip(
              message: 'Next month',
              child: shadcn.IconButton.ghost(
                onPressed: onNext,
                density: shadcn.ButtonDensity.icon,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.onChanged});

  final _TxTab selected;
  final ValueChanged<_TxTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = shadcn.Theme.of(context);
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      // The selected tab paints with `background`; lift it to the card
      // colour so it reads as a raised pill on the muted track.
      child: shadcn.Theme(
        data: theme.copyWith(
          colorScheme: () => theme.colorScheme.copyWith(background: () => card),
        ),
        child: shadcn.Tabs(
          index: selected.index,
          onChanged: (value) => onChanged(_TxTab.values[value]),
          theme: shadcn.TabsTheme(
            backgroundColor: AppColors.secondarySurface(context),
            borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
            containerPadding: const EdgeInsets.all(4),
            tabPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          ),
          children: [
            for (final tab in _TxTab.values)
              shadcn.TabItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tab == _TxTab.overdue) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: tab == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: tab == selected
                            ? AppColors.primary600
                            : AppColors.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultsRow extends StatelessWidget {
  const _ResultsRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.mutedText(context),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ── 3-tier cards ─────────────────────────────────────────────────────────

/// Card chrome shared by both list kinds: bordered shadcn card, press dip,
/// header + recessed body as the tap target, optional action footer.
class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.header,
    required this.body,
    this.footer,
    this.onTap,
  });

  final Widget header;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppPressScale(
    builder: (onHighlight) => shadcn.Card(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(DashboardTokens.radius),
      borderColor: DashboardTokens.border(context),
      boxShadow: DashboardTokens.shadow(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onHighlightChanged: onTap == null ? null : onHighlight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, const SizedBox(height: 11), body],
                ),
              ),
            ),
          ),
          if (footer != null) ...[
            shadcn.Divider(color: DashboardTokens.border(context)),
            footer!,
          ],
        ],
      ),
    ),
  );
}

/// Recessed patient + service + amount panel (body tier).
class _ChargePanel extends StatelessWidget {
  const _ChargePanel({
    required this.patientName,
    required this.service,
    required this.amount,
    this.amountNote,
    this.amountColor,
  });

  final String patientName;
  final String service;
  final double amount;
  final String? amountNote;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface(context).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
      border: Border.all(
        color: DashboardTokens.border(context).withValues(alpha: 0.6),
      ),
    ),
    child: Row(
      children: [
        shadcn.Avatar(
          initials: shadcn.Avatar.getInitials(
            patientName.trim().isEmpty ? 'Patient' : patientName,
          ),
          size: 38,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              _ServiceTag(service),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money.format(amount.round()),
              style: TextStyle(
                color: amountColor ?? AppColors.onSurface(context),
                fontSize: 19,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (amountNote != null) ...[
              const SizedBox(height: 3),
              Text(
                amountNote!,
                style: TextStyle(
                  color: AppColors.subtleText(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _ServiceTag extends StatelessWidget {
  const _ServiceTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: AppColors.isDark(context)
          ? DashboardTokens.teal.withValues(alpha: 0.16)
          : Color.alphaBlend(
              DashboardTokens.teal.withValues(alpha: 0.08),
              AppColors.card,
            ),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: DashboardTokens.teal.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.medical_services_outlined,
          size: 11,
          color: DashboardTokens.tealDeep,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text.trim().isEmpty ? 'Consultation' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DashboardTokens.tealDeep,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({required this.transaction});

  final BillingTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = _isOverdue(transaction);
    final (label, color, icon) = overdue
        ? ('Overdue', AppColors.destructive, null)
        : switch (transaction.paymentStatus) {
            BillingPaymentStatus.paid => (
              'Paid',
              AppColors.success,
              Icons.check_circle_rounded,
            ),
            BillingPaymentStatus.pending => (
              'Pending',
              AppColors.warning,
              Icons.schedule_rounded,
            ),
            BillingPaymentStatus.payAtClinic => (
              'Pay at Clinic',
              AppColors.primary600,
              Icons.storefront_rounded,
            ),
            BillingPaymentStatus.refunded => (
              'Refunded',
              AppColors.mutedText(context),
              Icons.undo_rounded,
            ),
          };
    final unpaid =
        transaction.paymentStatus == BillingPaymentStatus.pending ||
        transaction.paymentStatus == BillingPaymentStatus.payAtClinic;
    return _TierCard(
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, d MMM yyyy').format(transaction.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Appointment · ${_titleCase(transaction.appointmentStatus)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (transaction.isMock) ...[
            const _TestTag(),
            const SizedBox(width: 6),
          ],
          DashboardToneBadge(
            label: label,
            color: color,
            icon: icon,
            showDot: overdue,
          ),
        ],
      ),
      body: _ChargePanel(
        patientName: transaction.patientName,
        service: transaction.serviceName,
        amount: transaction.amount,
        amountColor: transaction.paymentStatus == BillingPaymentStatus.refunded
            ? AppColors.mutedText(context)
            : null,
        amountNote: transaction.paymentStatus == BillingPaymentStatus.refunded
            ? 'Refunded in full'
            : null,
      ),
      footer: unpaid
          ? Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      transaction.paymentStatus ==
                              BillingPaymentStatus.payAtClinic
                          ? 'To be paid at the clinic'
                          : overdue
                          ? 'Online payment not received'
                          : 'Awaiting online payment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  shadcn.PrimaryButton(
                    onPressed: () => _shareReminder(ref),
                    size: shadcn.ButtonSize.small,
                    leading: const Icon(Icons.send_rounded, size: 14),
                    child: const Text('Send Reminder'),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  /// Opens the share sheet with a prefilled reminder; the doctor picks the
  /// app (WhatsApp, SMS…) and recipient. No backend involved.
  Future<void> _shareReminder(WidgetRef ref) {
    final doctor = ref.read(doctorProfileProvider)?.fullName?.trim();
    final signature = doctor == null || doctor.isEmpty
        ? ''
        : '\n\n— Dr. ${doctor.replaceFirst(RegExp(r'^Dr\.?\s*'), '')}';
    final when = DateFormat('d MMM yyyy').format(transaction.date);
    final amount = _money.format(transaction.amount.round());
    final ask = transaction.paymentStatus == BillingPaymentStatus.payAtClinic
        ? 'Kindly pay at the clinic during your visit.'
        : 'Kindly complete the payment at your earliest convenience.';
    return SharePlus.instance.share(
      ShareParams(
        subject: 'Payment reminder',
        text:
            'Hello ${transaction.patientName}, this is a reminder about your '
            'payment of $amount for ${transaction.serviceName} on $when. '
            '$ask$signature',
      ),
    );
  }

  static String _titleCase(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _TestTag extends StatelessWidget {
  const _TestTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
    ),
    child: const Text(
      'TEST',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: AppColors.warning,
      ),
    ),
  );
}

class _InvoiceCard extends ConsumerStatefulWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends ConsumerState<_InvoiceCard> {
  bool _sharing = false;

  Future<void> _share() async {
    final profile = ref.read(doctorProfileProvider);
    if (profile == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await shareInvoicePdf(widget.invoice, profile);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate the invoice PDF.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final gstRegistered =
        ref.watch(doctorProfileProvider)?.gstRegistered == true;
    final hasProfile = ref.watch(doctorProfileProvider) != null;
    final status = invoice.status.trim().isEmpty
        ? 'Paid'
        : _InvoiceStatus.label(invoice.status);
    void open() => showInvoiceSheet(context, invoice);
    return _TierCard(
      onTap: open,
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber.startsWith('#')
                      ? invoice.invoiceNumber
                      : '#${invoice.invoiceNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColors.onSurface(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Issued ${DateFormat('d MMM yyyy').format(invoice.createdAt)}',
                  style: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          DashboardToneBadge(
            label: status,
            color: _InvoiceStatus.color(context, invoice.status),
            icon: Icons.verified_rounded,
          ),
        ],
      ),
      body: _ChargePanel(
        patientName: invoice.patientName,
        service: invoice.serviceName,
        amount: invoice.totalAmount,
        amountNote: gstRegistered && invoice.gstRate > 0
            ? 'incl. GST ${invoice.gstRate.toStringAsFixed(0)}%'
            : null,
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 10),
        child: Row(
          children: [
            Tooltip(
              message: 'Share invoice PDF',
              child: shadcn.IconButton.ghost(
                onPressed: _sharing || !hasProfile ? null : _share,
                density: shadcn.ButtonDensity.icon,
                icon: Icon(
                  _sharing
                      ? Icons.hourglass_top_rounded
                      : Icons.ios_share_rounded,
                  size: 18,
                ),
              ),
            ),
            const Spacer(),
            shadcn.OutlineButton(
              onPressed: open,
              size: shadcn.ButtonSize.small,
              trailing: const Icon(Icons.chevron_right_rounded, size: 16),
              child: const Text('View Breakdown'),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _InvoiceStatus {
  static String label(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static Color color(BuildContext context, String value) =>
      switch (value.toLowerCase()) {
        'paid' || '' => AppColors.success,
        'cancelled' || 'void' || 'refunded' => AppColors.mutedText(context),
        _ => AppColors.warning,
      };
}

// ── Loading & empty states ───────────────────────────────────────────────

/// Renders [child]'s real layout as a soft pulsing skeleton.
Widget _skeleton(BuildContext context, Widget child) {
  final isDark = AppColors.isDark(context);
  return Skeleton(
    semanticsLabel: 'Loading billing',
    palette: SkeletonPalette(
      surface: isDark ? AppColors.darkCard : AppColors.card,
      surfaceBorder: DashboardTokens.border(context),
      bone: isDark ? AppColors.darkBorder : AppColors.secondarySurface(context),
      innerSurface: isDark
          ? AppColors.darkSecondary
          : AppColors.secondarySurface(context).withValues(alpha: 0.55),
    ),
    child: child,
  );
}

/// Three 1:1 placeholder cards while a list loads — no spinner.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.invoices});

  final bool invoices;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (var i = 0; i < 3; i++)
        if (invoices)
          _InvoiceCard(
            invoice: Invoice(
              id: 'skeleton-$i',
              invoiceNumber: 'INV-2026-000',
              patientName: 'Patient Name',
              serviceName: 'Consultation',
              amount: 1000,
              gstRate: 0,
              gstAmount: 0,
              totalAmount: 1000,
              status: 'paid',
              createdAt: DateTime(2026),
            ),
          )
        else
          _TransactionCard(
            transaction: BillingTransaction(
              id: 'skeleton-$i',
              patientName: 'Patient Name',
              serviceName: 'Consultation',
              date: DateTime(2026),
              amount: 1000,
              paymentStatus: i == 1
                  ? BillingPaymentStatus.payAtClinic
                  : BillingPaymentStatus.paid,
              appointmentStatus: 'completed',
            ),
          ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: _skeleton(
        context,
        Column(
          children: [
            for (final (i, card) in cards.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              card,
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  static const _step = Duration(milliseconds: 80);

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xxl,
    ),
    child: Column(
      children: [
        AppEntrance(
          index: 0,
          offset: Offset.zero,
          scale: 0.4,
          curve: Curves.elasticOut,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  DashboardTokens.teal.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.isDark(context)
                      ? AppColors.darkCard
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: DashboardTokens.border(context)),
                  boxShadow: DashboardTokens.shadow(context),
                ),
                child: Icon(icon, size: 26, color: AppColors.primary600),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppEntrance(
          index: 2,
          step: _step,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AppEntrance(
          index: 3,
          step: _step,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        if (actionLabel != null || secondaryLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppEntrance(
            index: 4,
            step: _step,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (actionLabel != null)
                  shadcn.PrimaryButton(
                    onPressed: onAction,
                    leading: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    child: Text(actionLabel!),
                  ),
                if (secondaryLabel != null)
                  shadcn.OutlineButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _LockedBilling extends StatelessWidget {
  const _LockedBilling();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Billing & Invoices',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Track revenue, GST invoices and transactions with Pro or '
              'Premium.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface(context).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => context.go('/app/settings?tab=subscription'),
                child: const Text('View plans'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
