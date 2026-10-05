import 'dart:async';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_card.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_ui.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

const _statusFilters = <AppointmentStatus?>[
  null,
  AppointmentStatus.pending,
  AppointmentStatus.confirmed,
  AppointmentStatus.completed,
  AppointmentStatus.cancelled,
  AppointmentStatus.noShow,
];

/// Tab label per status filter. The `pending` filter already matches both
/// pending and confirmed bookings (see `matchesFilter`), i.e. "Upcoming".
String _filterLabel(AppointmentStatus? status) => switch (status) {
  null => 'All',
  AppointmentStatus.pending => 'Upcoming',
  _ => appointmentStatusLabel(status),
};

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  Timer? _debounce;
  AppointmentStatus? _status;
  DateTimeRange? _dateRange;
  bool _selectionMode = false;
  bool _deleting = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dateRange = DateTimeRange(start: today, end: today);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(appointmentsProvider.notifier).search(value),
    );
  }

  void _selectStatus(AppointmentStatus? status) {
    setState(() => _status = status);
    ref.read(appointmentsProvider.notifier).filterStatus(status);
  }

  /// Day-card tap: the same single-day range filter the date picker applies.
  Future<void> _selectDay(DateTime day) async {
    final range = DateTimeRange(start: day, end: day);
    setState(() => _dateRange = range);
    await ref
        .read(appointmentsProvider.notifier)
        .filterDates(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentsProvider);
    final summary = ref.watch(appointmentSummaryProvider);
    final writeDisabled =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    final surface = Theme.of(context).colorScheme.surface;
    final onAdd = writeDisabled
        ? null
        : () => showAppointmentForm(context, ref);

    final content = <Widget>[
      ...state.when(
        loading: () => const [
          SliverToBoxAdapter(child: _AppointmentsSkeleton()),
        ],
        error: (error, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppErrorView(
              message: error is AppFailure
                  ? error.userMessage
                  : 'Could not load appointments.',
              onRetry: () => ref.read(appointmentsProvider.notifier).refresh(),
            ),
          ),
        ],
        data: (page) => page.items.isEmpty
            ? [
                SliverToBoxAdapter(
                  child: _AppointmentsEmptyState(
                    filtered: _dateRange != null || _status != null,
                    onAdd: onAdd,
                    onShowAllDates: _dateRange == null || _selectionMode
                        ? null
                        : _clearDates,
                  ),
                ),
              ]
            : [
                SliverToBoxAdapter(
                  child: _SelectionBar(
                    selectionMode: _selectionMode,
                    selectedCount: _selectedIds.length,
                    pageCount: page.items.length,
                    totalCount: page.totalCount,
                    deleting: _deleting,
                    writeDisabled: writeDisabled,
                    onToggleMode: _toggleSelectionMode,
                    onSelectAll: () => _selectAll(page.items),
                    onDelete: _confirmBulkDelete,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    96,
                  ),
                  sliver: SliverList.separated(
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => index == page.items.length
                        ? PagedListFooter(
                            hasMore: page.hasMore,
                            isLoading: page.isLoadingMore,
                            onLoadMore: () => ref
                                .read(appointmentsProvider.notifier)
                                .loadMore(),
                          )
                        : AppointmentCard(
                            appointment: page.items[index],
                            selectionMode: _selectionMode,
                            selected: _selectedIds.contains(
                              page.items[index].id,
                            ),
                            onSelected: () =>
                                _toggleSelected(page.items[index].id),
                          ),
                  ),
                ),
              ],
      ),
    ];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RoutePaths.dashboard);
      },
      child: DashboardShadcnScope(
        child: Scaffold(
          // Hidden on the empty state, which has its own Book CTA.
          floatingActionButton:
              _selectionMode || (state.value?.items.isEmpty ?? false)
              ? null
              : FloatingActionButton.extended(
                  elevation: 2,
                  highlightElevation: 4,
                  backgroundColor: AppColors.primary600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DashboardTokens.radius),
                  ),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Book',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
          body: Column(
            children: [
              // ── Pinned control strip: search + date picker ────────────
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(
                    bottom: BorderSide(color: DashboardTokens.border(context)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        enabled: !_selectionMode,
                        onChanged: _search,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _DateFilterButton(
                      isActive: _dateRange != null,
                      onPressed: _selectionMode ? null : _pickDateRange,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(appointmentsProvider.notifier).refresh(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _WeekStrip(
                          selected: _dateRange?.start,
                          label: _dateRange == null
                              ? 'All dates'
                              : _dateRangeLabel(_dateRange!),
                          enabled: !_selectionMode,
                          onSelectDay: _selectDay,
                          onSelectAll: _clearDates,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _AppointmentSummaryStrip(summary: summary),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _PinnedTabsDelegate(
                          background: surface,
                          border: DashboardTokens.border(context),
                          child: _StatusTabs(
                            selected: _status,
                            enabled: !_selectionMode,
                            onChanged: _selectStatus,
                          ),
                        ),
                      ),
                      if (writeDisabled)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.xs,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.warning.withValues(alpha: 0.13),
                                    AppColors.warning.withValues(alpha: 0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  DashboardTokens.innerRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_clock_rounded,
                                    size: 16,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      'Trial grace access is read-only. Upgrade to edit.',
                                      style: TextStyle(
                                        color: AppColors.onSurface(context),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ...content,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateRangeLabel(DateTimeRange range) {
    if (DateUtils.isSameDay(range.start, range.end)) {
      return DateFormat('EEE, d MMM yyyy').format(range.start);
    }
    return '${DateFormat('d MMM').format(range.start)} – '
        '${DateFormat('d MMM yyyy').format(range.end)}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final lastSelectable = now.add(const Duration(days: 730));
    final selected = await showDatePicker(
      context: context,
      helpText: 'Appointment date',
      initialDate: _dateRange?.start ?? now,
      firstDate: DateTime(2020),
      lastDate: lastSelectable,
    );
    if (selected == null) return;
    final range = DateTimeRange(start: selected, end: selected);
    setState(() => _dateRange = range);
    await ref
        .read(appointmentsProvider.notifier)
        .filterDates(range.start, range.end);
  }

  Future<void> _clearDates() async {
    setState(() => _dateRange = null);
    await ref.read(appointmentsProvider.notifier).filterDates(null, null);
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  void _selectAll(List<Appointment> appointments) {
    setState(() {
      final pageIds = appointments.map((item) => item.id).toSet();
      if (_selectedIds.containsAll(pageIds)) {
        _selectedIds.removeAll(pageIds);
      } else {
        _selectedIds.addAll(pageIds);
      }
    });
  }

  Future<void> _confirmBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: Text('Delete ${_selectedIds.length} appointments?'),
        content: const Text(
          'This cannot be undone. Historical invoices will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    setState(() => _deleting = true);
    final count = _selectedIds.length;
    final error = await ref
        .read(appointmentsProvider.notifier)
        .deleteMany(_selectedIds.toList(growable: false));
    if (!mounted) return;
    setState(() {
      _deleting = false;
      if (error == null) {
        _selectionMode = false;
        _selectedIds.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? '$count appointment${count == 1 ? '' : 's'} deleted',
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      enabled: enabled,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.onSurface(context), fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search patient or service',
        hintStyle: TextStyle(
          color: AppColors.subtleText(context),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.subtleText(context),
        ),
        filled: true,
        fillColor: AppColors.isDark(context)
            ? AppColors.darkCard
            : AppColors.card,
        enabledBorder: border(DashboardTokens.border(context)),
        focusedBorder: border(DashboardTokens.teal, 1.8),
        disabledBorder: border(
          DashboardTokens.border(context).withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

/// Outlined icon button for the date filter, with a teal dot when active.
class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({required this.isActive, required this.onPressed});

  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Filter by date range',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: shadcn.IconButton.outline(
            onPressed: onPressed,
            icon: Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: isActive
                  ? DashboardTokens.tealDeep
                  : AppColors.mutedText(context),
            ),
          ),
        ),
        if (isActive)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: DashboardTokens.teal,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final AppointmentStatus? selected;
  final bool enabled;
  final ValueChanged<AppointmentStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = shadcn.Theme.of(context);
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    final index = _statusFilters.indexOf(selected);
    return Padding(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            // The selected tab paints with `background`; lift it to the card
            // colour so it reads as a raised pill on the muted track.
            child: shadcn.Theme(
              data: theme.copyWith(
                colorScheme: () =>
                    theme.colorScheme.copyWith(background: () => card),
              ),
              child: shadcn.Tabs(
                index: index,
                onChanged: (value) => onChanged(_statusFilters[value]),
                theme: shadcn.TabsTheme(
                  backgroundColor: AppColors.secondarySurface(context),
                  borderRadius: BorderRadius.circular(
                    DashboardTokens.innerRadius,
                  ),
                  containerPadding: const EdgeInsets.all(4),
                  tabPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                ),
                children: [
                  for (var i = 0; i < _statusFilters.length; i++)
                    shadcn.TabItem(
                      child: Text(
                        _filterLabel(_statusFilters[i]),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: i == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == index
                              ? DashboardTokens.tealDeep
                              : AppColors.mutedText(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentSummaryStrip extends StatelessWidget {
  const _AppointmentSummaryStrip({required this.summary});

  final AsyncValue<AppointmentSummary> summary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      0,
    ),
    child: summary.when(
      data: (value) => Row(
        children: [
          _SummaryCard(
            value: value.total,
            label: 'Total',
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            value: value.pending,
            label: 'Pending',
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            value: value.completed,
            label: 'Completed',
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            value: value.cancelled,
            label: 'Cancelled',
            color: AppColors.destructive,
          ),
        ],
      ),
      loading: () => const Row(
        children: [
          _SummaryCard(label: 'Total'),
          SizedBox(width: 8),
          _SummaryCard(label: 'Pending'),
          SizedBox(width: 8),
          _SummaryCard(label: 'Completed'),
          SizedBox(width: 8),
          _SummaryCard(label: 'Cancelled'),
        ],
      ),
      error: (_, _) => const SizedBox.shrink(),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, this.value, this.color});

  final String label;
  final int? value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.subtleText(context);
    return Expanded(
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.isDark(context)
              ? AppColors.darkCard
              : AppColors.card,
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius + 2),
          border: Border.all(color: DashboardTokens.border(context)),
          boxShadow: DashboardTokens.shadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value?.toString() ?? '—',
              style: TextStyle(
                color: value == null
                    ? AppColors.subtleText(context)
                    : AppColors.onSurface(context),
                fontSize: 19,
                height: 1,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectionMode,
    required this.selectedCount,
    required this.pageCount,
    required this.totalCount,
    required this.deleting,
    required this.writeDisabled,
    required this.onToggleMode,
    required this.onSelectAll,
    required this.onDelete,
  });
  final bool selectionMode;
  final int selectedCount;
  final int pageCount;
  final int? totalCount;
  final bool deleting;
  final bool writeDisabled;
  final VoidCallback onToggleMode;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    margin: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    padding: const EdgeInsets.only(left: AppSpacing.sm),
    decoration: BoxDecoration(
      color: selectionMode
          ? DashboardTokens.teal.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
      border: Border.all(
        color: selectionMode
            ? DashboardTokens.teal.withValues(alpha: 0.28)
            : Colors.transparent,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            selectionMode
                ? '$selectedCount of $pageCount selected on loaded pages'
                : '${totalCount ?? pageCount} appointments',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selectionMode ? FontWeight.w600 : FontWeight.w500,
              color: selectionMode
                  ? DashboardTokens.tealDeep
                  : AppColors.mutedText(context),
            ),
          ),
        ),
        if (selectionMode) ...[
          shadcn.GhostButton(
            onPressed: onSelectAll,
            size: shadcn.ButtonSize.small,
            child: const Text(
              'Select all',
              style: TextStyle(
                color: DashboardTokens.tealDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: selectedCount == 0 || deleting ? null : onDelete,
            tooltip: 'Delete selected',
            color: AppColors.destructive,
            icon: deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_rounded, size: 20),
          ),
        ],
        IconButton(
          onPressed: writeDisabled ? null : onToggleMode,
          tooltip: selectionMode
              ? 'Exit selection mode'
              : 'Select appointments',
          icon: Icon(
            selectionMode ? Icons.close_rounded : Icons.checklist_rounded,
            color: selectionMode
                ? DashboardTokens.tealDeep
                : AppColors.mutedText(context),
            size: 19,
          ),
        ),
      ],
    ),
  );
}

/// Horizontal strip of day cards driving the single-day date filter, with an
/// "All" card that clears it. Today carries an indicator dot.
class _WeekStrip extends StatefulWidget {
  const _WeekStrip({
    required this.selected,
    required this.label,
    required this.enabled,
    required this.onSelectDay,
    required this.onSelectAll,
  });

  final DateTime? selected;
  final String label;
  final bool enabled;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onSelectAll;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  static const _days = 21;
  final _selectedKey = GlobalKey();

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Monday of today's week, unless the picked day falls outside the
  /// three-week window — then the window moves to that day's week.
  DateTime get _windowStart {
    DateTime mondayOf(DateTime day) =>
        DateTime(day.year, day.month, day.day - (day.weekday - 1));
    final base = mondayOf(_today);
    final selected = widget.selected;
    if (selected == null) return base;
    final end = DateTime(base.year, base.month, base.day + _days - 1);
    final inWindow = !selected.isBefore(base) && !selected.isAfter(end);
    return inWindow ? base : mondayOf(selected);
  }

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(covariant _WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected(animate: true);
  }

  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _windowStart;
    final today = _today;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(widget.selected ?? today),
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DashboardTokens.tealDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 74,
            child: IgnorePointer(
              ignoring: !widget.enabled,
              child: Opacity(
                opacity: widget.enabled ? 1 : 0.5,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: _days + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final active = widget.selected == null;
                      return _DayCard(
                        key: active ? _selectedKey : null,
                        top: 'All',
                        center: null,
                        selected: active,
                        onTap: widget.onSelectAll,
                      );
                    }
                    final day = DateTime(
                      start.year,
                      start.month,
                      start.day + index - 1,
                    );
                    final active =
                        widget.selected != null &&
                        DateUtils.isSameDay(day, widget.selected);
                    return _DayCard(
                      key: active ? _selectedKey : null,
                      top: DateFormat('EEE').format(day),
                      center: '${day.day}',
                      selected: active,
                      isToday: DateUtils.isSameDay(day, today),
                      onTap: () => widget.onSelectDay(day),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.top,
    required this.center,
    required this.selected,
    required this.onTap,
    this.isToday = false,
    super.key,
  });

  final String top;

  /// Date numeral; null renders the "All dates" card.
  final String? center;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DashboardTokens.innerRadius + 2);
    final foreground = selected ? Colors.white : AppColors.onSurface(context);
    final muted = selected
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.mutedText(context);
    return Semantics(
      button: true,
      selected: selected,
      label: center == null ? 'All dates' : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [DashboardTokens.teal, DashboardTokens.tealDeep],
                    )
                  : null,
              color: selected
                  ? null
                  : AppColors.isDark(context)
                  ? AppColors.darkCard
                  : AppColors.card,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : isToday
                    ? DashboardTokens.teal.withValues(alpha: 0.5)
                    : DashboardTokens.border(context),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: DashboardTokens.teal.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  top,
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                if (center != null)
                  Text(
                    center!,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                else
                  Icon(
                    Icons.all_inclusive_rounded,
                    size: 20,
                    color: foreground,
                  ),
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday
                        ? (selected ? Colors.white : DashboardTokens.teal)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the status tabs pinned under the toolbar while the list scrolls.
class _PinnedTabsDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabsDelegate({
    required this.child,
    required this.background,
    required this.border,
  });

  final Widget child;
  final Color background;
  final Color border;

  static const _extent = 58.0;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      border: Border(
        bottom: BorderSide(
          color: overlapsContent || shrinkOffset > 0
              ? border
              : Colors.transparent,
        ),
      ),
    ),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  @override
  bool shouldRebuild(covariant _PinnedTabsDelegate oldDelegate) => true;
}

class _AppointmentsEmptyState extends StatelessWidget {
  const _AppointmentsEmptyState({
    required this.filtered,
    required this.onAdd,
    required this.onShowAllDates,
  });

  final bool filtered;
  final VoidCallback? onAdd;
  final VoidCallback? onShowAllDates;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
      96,
    ),
    child: Column(
      children: [
        Container(
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
              child: const Icon(
                Icons.event_available_rounded,
                size: 26,
                color: DashboardTokens.tealDeep,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          filtered ? 'No appointments here' : 'No appointments yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          filtered
              ? 'Nothing matches this day or status. Pick another date or '
                    'book a new visit.'
              : 'Your schedule is empty. Book a visit to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mutedText(context),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        shadcn.PrimaryButton(
          onPressed: onAdd,
          leading: const Icon(Icons.add_rounded, size: 16),
          child: Text(filtered ? 'Book Appointment' : 'Book First Appointment'),
        ),
        if (onShowAllDates != null) ...[
          const SizedBox(height: AppSpacing.xs),
          shadcn.GhostButton(
            onPressed: onShowAllDates,
            child: const Text(
              'Show all dates',
              style: TextStyle(
                color: DashboardTokens.tealDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Pulsing placeholder cards shown while appointments load.
class _AppointmentsSkeleton extends StatefulWidget {
  const _AppointmentsSkeleton();

  @override
  State<_AppointmentsSkeleton> createState() => _AppointmentsSkeletonState();
}

class _AppointmentsSkeletonState extends State<_AppointmentsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bone = AppColors.secondarySurface(context);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bone,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Semantics(
      label: 'Loading appointments',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Opacity(opacity: 0.55 + _controller.value * 0.45, child: child),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: Column(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DashboardSurface(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: bone,
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bar(140, 14),
                                const SizedBox(height: 6),
                                bar(100, 11),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        bar(double.infinity, 58),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: bar(150, 28),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
