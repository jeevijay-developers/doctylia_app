import 'dart:async';
import 'dart:io';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:doctylia_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:doctylia_app/features/billing/presentation/widgets/invoice_sheet.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeatureGate(
    feature: FeatureKey.billingInvoices,
    lockedChild: _LockedBilling(),
    child: _BillingContent(),
  );
}

class _BillingContent extends ConsumerWidget {
  const _BillingContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(billingSummaryProvider);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: summary.when(
              loading: () => const SizedBox(
                height: 102,
                child: AppLoadingView(label: 'Loading revenue'),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (value) => _RevenueCards(summary: value),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: _PillTabBar(),
          ),
          const Expanded(
            child: TabBarView(children: [_TransactionsList(), _InvoicesList()]),
          ),
        ],
      ),
    );
  }
}

/// A segmented "pill" tab switcher — a solid rounded background slides
/// behind the selected tab, instead of a plain Material underline.
class _PillTabBar extends StatelessWidget {
  const _PillTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(10),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.mutedText(context),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: const [
          Tab(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.credit_card_rounded, size: 14),
                  SizedBox(width: 7),
                  Text('Transactions'),
                ],
              ),
            ),
          ),
          Tab(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 14),
                  SizedBox(width: 7),
                  Text('Invoices'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueCards extends StatelessWidget {
  const _RevenueCards({required this.summary});
  final BillingSummary summary;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return Row(
      children: [
        _RevenueCard(
          'Today',
          money.format(summary.todayRevenue),
          Icons.today_rounded,
          AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        _RevenueCard(
          'This week',
          money.format(summary.weekRevenue),
          Icons.trending_up_rounded,
          AppColors.teal,
        ),
        const SizedBox(width: AppSpacing.xs),
        _RevenueCard(
          'This month',
          money.format(summary.monthRevenue),
          Icons.currency_rupee_rounded,
          AppColors.primary,
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.onSurface(context),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.subtleText(context),
            ),
          ),
        ],
      ),
    ),
  );
}

enum _TransactionDateMode { month, date }

class _TransactionDateFilter extends StatelessWidget {
  const _TransactionDateFilter({
    required this.mode,
    required this.selectedDate,
    required this.active,
    required this.onModeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onYearChanged,
    required this.onPickDate,
    required this.onClear,
  });

  final _TransactionDateMode mode;
  final DateTime selectedDate;
  final bool active;
  final ValueChanged<_TransactionDateMode> onModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final years = <int>{
      for (
        var year = DateTime.now().year - 4;
        year <= DateTime.now().year + 2;
        year++
      )
        year,
      selectedDate.year,
    }.toList()..sort();
    final label = mode == _TransactionDateMode.month
        ? DateFormat('MMMM yyyy').format(selectedDate)
        : DateFormat('d MMMM yyyy').format(selectedDate);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface(context),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DateModeButton(
                      label: 'Month',
                      selected: mode == _TransactionDateMode.month,
                      onTap: () => onModeChanged(_TransactionDateMode.month),
                    ),
                    _DateModeButton(
                      label: 'Date',
                      selected: mode == _TransactionDateMode.date,
                      onTap: () => onModeChanged(_TransactionDateMode.date),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedDate.year,
                    isDense: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    style: TextStyle(
                      color: AppColors.onSurface(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      for (final year in years)
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: onYearChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                color: AppColors.mutedText(context),
                tooltip: 'Previous',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: mode == _TransactionDateMode.date ? onPickDate : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      active ? label : 'All dates',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                color: AppColors.mutedText(context),
                tooltip: 'Next',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              TextButton(
                onPressed: active ? onClear : null,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateModeButton extends StatelessWidget {
  const _DateModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    ),
  );
}

class _PaymentStatusStrip extends StatelessWidget {
  const _PaymentStatusStrip({required this.summary});

  final BillingSummary summary;

  @override
  Widget build(BuildContext context) {
    final total =
        summary.paidCount +
        summary.pendingCount +
        summary.payAtClinicCount +
        summary.refundedCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatusCount(
            'Total',
            total,
            AppColors.onSurface(context),
            showDot: false,
          ),
          const _StatusDivider(),
          _StatusCount('Paid', summary.paidCount, AppColors.success),
          const _StatusDivider(),
          _StatusCount('Pending', summary.pendingCount, AppColors.warning),
          const _StatusDivider(),
          _StatusCount('Clinic', summary.payAtClinicCount, AppColors.primary),
          const _StatusDivider(),
          _StatusCount('Refund', summary.refundedCount, AppColors.textLight),
        ],
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount(this.label, this.value, this.color, {this.showDot = true});

  final String label;
  final int value;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showDot) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 9.5, color: AppColors.mutedText(context)),
        ),
      ],
    ),
  );
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 27, color: AppColors.border(context));
}

class _TransactionsList extends ConsumerStatefulWidget {
  const _TransactionsList();
  @override
  ConsumerState<_TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends ConsumerState<_TransactionsList> {
  Timer? _debounce;
  BillingPaymentStatus? _filter;
  _TransactionDateMode _dateMode = _TransactionDateMode.month;
  DateTime _selectedDate = DateTime.now();
  bool _dateFilterActive = true;
  bool _exporting = false;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingTransactionsProvider);
    final summary = ref.watch(billingSummaryProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: _TransactionDateFilter(
            mode: _dateMode,
            selectedDate: _selectedDate,
            active: _dateFilterActive,
            onModeChanged: _setDateMode,
            onPrevious: () => _moveDate(-1),
            onNext: () => _moveDate(1),
            onYearChanged: _setYear,
            onPickDate: _pickDate,
            onClear: _clearDateFilter,
          ),
        ),
        summary.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (value) => Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: _PaymentStatusStrip(summary: value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 350),
                      () => ref
                          .read(billingTransactionsProvider.notifier)
                          .search(value),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 19,
                      color: AppColors.textLight,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _FilterMenu(
                value: _filter,
                onSelected: (value) {
                  setState(() => _filter = value);
                  ref.read(billingTransactionsProvider.notifier).filter(value);
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              _RoundIconButton(
                tooltip: 'Export CSV',
                onPressed: _exporting ? null : _exportCsv,
                loading: _exporting,
                icon: Icons.download_rounded,
              ),
            ],
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const AppLoadingView(label: 'Loading transactions'),
            error: (error, _) => AppErrorView(
              message: error is AppFailure
                  ? error.userMessage
                  : 'Could not load transactions.',
              onRetry: () =>
                  ref.read(billingTransactionsProvider.notifier).refresh(),
            ),
            data: (page) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(billingSummaryProvider);
                await ref.read(billingTransactionsProvider.notifier).refresh();
              },
              child: page.items.isEmpty
                  ? ListView(
                      children: const [
                        AppEmptyView(
                          icon: Icons.credit_card_off_rounded,
                          title: 'No transactions',
                          message: 'No payments match this filter.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      itemCount: page.items.length + 1,
                      itemBuilder: (_, index) => index == page.items.length
                          ? PagedListFooter(
                              hasMore: page.hasMore,
                              onLoadMore: () => ref
                                  .read(billingTransactionsProvider.notifier)
                                  .loadMore(),
                            )
                          : _TransactionCard(transaction: page.items[index]),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _setDateMode(_TransactionDateMode value) {
    setState(() {
      _dateMode = value;
      _dateFilterActive = true;
    });
    _applyDateFilter();
  }

  void _moveDate(int amount) {
    setState(() {
      _selectedDate = _dateMode == _TransactionDateMode.month
          ? DateTime(_selectedDate.year, _selectedDate.month + amount)
          : _selectedDate.add(Duration(days: amount));
      _dateFilterActive = true;
    });
    _applyDateFilter();
  }

  void _setYear(int? year) {
    if (year == null) return;
    setState(() {
      _selectedDate = DateTime(
        year,
        _selectedDate.month,
        _dateMode == _TransactionDateMode.date ? _selectedDate.day : 1,
      );
      _dateFilterActive = true;
    });
    _applyDateFilter();
  }

  Future<void> _pickDate() async {
    if (_dateMode != _TransactionDateMode.date) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDate = selected;
      _dateFilterActive = true;
    });
    _applyDateFilter();
  }

  void _clearDateFilter() {
    setState(() => _dateFilterActive = false);
    ref.read(billingTransactionsProvider.notifier).filterDates(null, null);
  }

  void _applyDateFilter() {
    final start = _dateMode == _TransactionDateMode.month
        ? DateTime(_selectedDate.year, _selectedDate.month)
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = _dateMode == _TransactionDateMode.month
        ? DateTime(_selectedDate.year, _selectedDate.month + 1)
        : start.add(const Duration(days: 1));
    ref.read(billingTransactionsProvider.notifier).filterDates(start, end);
  }

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
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}${Platform.pathSeparator}doctylia-transactions-$safeName-$date.csv';
        final file = File(path);
        await file.writeAsString(
          '\ufeff${_transactionsCsv(rows)}',
          flush: true,
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: 'text/csv')],
            subject: 'Doctylia transactions export',
          ),
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
    final text = '${value ?? ''}';
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

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.value, required this.onSelected});
  final BillingPaymentStatus? value;
  final ValueChanged<BillingPaymentStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    return PopupMenuButton<BillingPaymentStatus?>(
      tooltip: 'Payment status',
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('All payments')),
        ...BillingPaymentStatus.values.map(
          (v) => PopupMenuItem(value: v, child: Text(v.label)),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary100 : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: isActive ? 0.3 : 0.13),
          ),
        ),
        child: Icon(
          Icons.filter_list_rounded,
          size: 20,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.loading = false,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool loading;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.13)),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 20, color: AppColors.primary),
      ),
    ),
  );
}

/// A card with a colored left accent bar reflecting payment status — the
/// status reads at a glance, before the eye even reaches the badge.
class _AccentCard extends StatelessWidget {
  const _AccentCard({required this.color, required this.child, this.onTap});
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black.withValues(alpha: 0.025)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.055),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final BillingTransaction transaction;
  @override
  Widget build(BuildContext context) {
    final color = switch (transaction.paymentStatus) {
      BillingPaymentStatus.paid => AppColors.success,
      BillingPaymentStatus.pending => AppColors.warning,
      BillingPaymentStatus.refunded => AppColors.destructive,
      BillingPaymentStatus.payAtClinic => AppColors.primary,
    };
    final appointmentColor = switch (transaction.appointmentStatus) {
      'completed' || 'confirmed' => AppColors.success,
      'cancelled' || 'no_show' => AppColors.destructive,
      _ => AppColors.primary,
    };
    return _AccentCard(
      color: color,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            radius: 20,
            child: Text(
              transaction.patientName.trim().isEmpty
                  ? 'P'
                  : transaction.patientName.trim()[0].toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        transaction.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (transaction.isMock) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Text(
                          'TEST',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${transaction.serviceName} · ${DateFormat('d MMM yy').format(transaction.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurface(
                            context,
                          ).withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: appointmentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _statusLabel(transaction.appointmentStatus),
                    style: TextStyle(
                      color: appointmentColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${transaction.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  transaction.paymentStatus.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _InvoicesList extends ConsumerStatefulWidget {
  const _InvoicesList();
  @override
  ConsumerState<_InvoicesList> createState() => _InvoicesListState();
}

class _InvoicesListState extends ConsumerState<_InvoicesList> {
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoicesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: TextField(
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 350),
                () => ref.read(invoicesProvider.notifier).search(value),
              );
            },
            decoration: InputDecoration(
              hintText: 'Search invoice or patient...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
                color: AppColors.textLight,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.07),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.07),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const AppLoadingView(label: 'Loading invoices'),
            error: (error, _) => AppErrorView(
              message: error is AppFailure
                  ? error.userMessage
                  : 'Could not load invoices.',
              onRetry: () => ref.read(invoicesProvider.notifier).refresh(),
            ),
            data: (page) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(billingSummaryProvider);
                await ref.read(invoicesProvider.notifier).refresh();
              },
              child: page.items.isEmpty
                  ? ListView(
                      children: const [
                        AppEmptyView(
                          icon: Icons.receipt_long_rounded,
                          title: 'No invoices',
                          message:
                              'Invoices appear after a payment is marked paid.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      itemCount: page.items.length + 1,
                      itemBuilder: (_, index) => index == page.items.length
                          ? PagedListFooter(
                              hasMore: page.hasMore,
                              onLoadMore: () => ref
                                  .read(invoicesProvider.notifier)
                                  .loadMore(),
                            )
                          : _InvoiceCard(invoice: page.items[index]),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({required this.invoice});
  final Invoice invoice;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gstRegistered =
        ref.watch(doctorProfileProvider)?.gstRegistered == true;
    return _AccentCard(
      color: AppColors.primary,
      onTap: () => showInvoiceSheet(context, invoice),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.invoiceNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${invoice.patientName} · ${DateFormat('d MMM yyyy').format(invoice.createdAt)}${gstRegistered && invoice.gstRate > 0 ? ' · GST ${invoice.gstRate.toStringAsFixed(0)}% (${invoice.gstAmount.toStringAsFixed(2)})' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurface(context).withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${invoice.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
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
