import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription_status.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:doctylia_app/features/prescriptions/presentation/widgets/prescription_card.dart';
import 'package:doctylia_app/features/prescriptions/presentation/widgets/prescription_form_sheet.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Status tabs. Prescriptions store no status, so tabs filter the loaded
/// results by the date-derived [PrescriptionStatus].
enum _RxTab {
  all('All', null),
  active('Active / Ongoing', PrescriptionStatus.active),
  completed('Completed', PrescriptionStatus.completed),
  followUpDue('Follow-up Due', PrescriptionStatus.followUpDue);

  const _RxTab(this.label, this.status);

  final String label;
  final PrescriptionStatus? status;
}

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  ConsumerState<PrescriptionsScreen> createState() =>
      _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  Timer? _debounce;
  DateTime? _date;
  String _search = '';
  _RxTab _tab = _RxTab.all;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();

  /// Prescription ids whose card entrance already played for the current
  /// results; reset when a new query loads or the tab changes.
  final Set<String> _animatedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(prescriptionsProvider.notifier).filterDate(_date);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(prescriptionsProvider.notifier).search(value),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _clearDate() {
    setState(() => _date = null);
    ref.read(prescriptionsProvider.notifier).filterDate(null);
  }

  void _selectTab(_RxTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _animatedIds.clear();
    });
  }

  Future<void> _addPrescription() async {
    ref.invalidate(prescriptionPatientsProvider);
    final value = await showPrescriptionForm(context, ref);
    if (value != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prescription saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriptionsProvider);
    // A new query is loading: its results should cascade in again.
    if (state.isLoading && !state.isRefreshing) _animatedIds.clear();
    final summary = ref.watch(prescriptionSummaryProvider);
    final readOnly =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    final page = state.value;

    return PrescriptionShadcnScope(
      child: AppMotion(
        enabled: true,
        child: Scaffold(
          floatingActionButton: _selectMode && _selectedIds.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _confirmBulkDelete,
                  elevation: 2,
                  backgroundColor: AppColors.destructive,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DashboardTokens.radius),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    'Delete ${_selectedIds.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : null,
          body: Column(
            children: [
              _Toolbar(
                activeCount: summary.value?.active,
                searchController: _searchController,
                showClear: _search.isNotEmpty,
                selectMode: _selectMode,
                dateActive: _date != null,
                canSelect: page?.items.isNotEmpty ?? false,
                onNew: readOnly || _selectMode ? null : _addPrescription,
                onSearchChanged: _onSearchChanged,
                onClearSearch: _clearSearch,
                onPickDate: _pickDate,
                onToggleSelect: _selectMode
                    ? _exitSelectMode
                    : () => setState(() => _selectMode = true),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(prescriptionSummaryProvider);
                    await ref.read(prescriptionsProvider.notifier).refresh();
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _MetricStrip(summary: summary)),
                      SliverToBoxAdapter(
                        child: _StatusTabs(
                          selected: _tab,
                          enabled: !_selectMode,
                          onChanged: _selectTab,
                        ),
                      ),
                      if (page != null)
                        SliverToBoxAdapter(child: _resultsRow(page)),
                      ..._content(state, readOnly),
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

  /// Date filter chip + result count, or the selection controls.
  Widget _resultsRow(PagedState<Prescription> page) {
    final items = page.items;
    final visible = _filtered(items);
    final total = page.totalCount ?? items.length;
    final countText = _selectMode
        ? '${_selectedIds.length} of ${visible.length} selected'
        : _tab == _RxTab.all
        ? '$total ${total == 1 ? 'record' : 'records'}'
        : '${visible.length} of ${items.length} loaded';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Flexible(
            child: _date != null
                ? _FilterPill(
                    icon: Icons.event_outlined,
                    label: DateFormat('d MMM yyyy').format(_date!),
                    active: true,
                    onClear: _selectMode ? null : _clearDate,
                  )
                : const _FilterPill(
                    icon: Icons.all_inclusive_rounded,
                    label: 'All dates',
                  ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              countText,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_selectMode && visible.isNotEmpty)
            IconButton(
              onPressed: () => _toggleAll(visible),
              tooltip: visible.every((p) => _selectedIds.contains(p.id))
                  ? 'Deselect all'
                  : 'Select all shown',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                visible.every((p) => _selectedIds.contains(p.id))
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                size: 20,
                color: DashboardTokens.tealDeep,
              ),
            ),
        ],
      ),
    );
  }

  List<Prescription> _filtered(List<Prescription> items) {
    final status = _tab.status;
    if (status == null) return items;
    final now = DateTime.now();
    return items
        .where((item) => prescriptionStatusOf(item, now: now) == status)
        .toList(growable: false);
  }

  List<Widget> _content(
    AsyncValue<PagedState<Prescription>> state,
    bool readOnly,
  ) {
    return state.when(
      loading: () => const [SliverToBoxAdapter(child: _CardsSkeleton())],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorView(
            message: error is AppFailure
                ? error.userMessage
                : 'Could not load prescriptions.',
            onRetry: () => ref.read(prescriptionsProvider.notifier).refresh(),
          ),
        ),
      ],
      data: (page) {
        final visible = _filtered(page.items);
        if (page.items.isEmpty) {
          final filtered = _search.trim().isNotEmpty || _date != null;
          return [
            SliverToBoxAdapter(
              child: _EmptyState(
                title: 'No Prescriptions Found',
                message: filtered
                    ? 'Nothing matches this search or date. Try another '
                          'date, or show prescriptions from all dates.'
                    : 'Create the first prescription to start your Rx '
                          'history.',
                primaryLabel: 'New Prescription',
                onPrimary: readOnly || _selectMode ? null : _addPrescription,
                secondaryLabel: _date != null ? 'Show all dates' : null,
                onSecondary: _date != null && !_selectMode ? _clearDate : null,
              ),
            ),
          ];
        }
        if (visible.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: _EmptyState(
                title: 'No ${_tab.label} prescriptions',
                message: page.hasMore
                    ? 'None of the loaded prescriptions are in this tab. '
                          'Load more, or view all.'
                    : 'None of these prescriptions are in this tab.',
                primaryLabel: page.hasMore ? 'Load more' : null,
                onPrimary: page.hasMore
                    ? () => ref.read(prescriptionsProvider.notifier).loadMore()
                    : null,
                secondaryLabel: 'Show all',
                onSecondary: () => _selectTab(_RxTab.all),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xxs,
              AppSpacing.md,
              96,
            ),
            sliver: SliverList.separated(
              itemCount: visible.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => index == visible.length
                  ? _PrescriptionListFooter(
                      hasMore: page.hasMore,
                      isLoading: page.isLoadingMore,
                      date: _date,
                      onLoadMore: () =>
                          ref.read(prescriptionsProvider.notifier).loadMore(),
                    )
                  : _listItem(visible[index], index, readOnly: readOnly),
            ),
          ),
        ];
      },
    );
  }

  /// Cards cascade in the first time each result shows; already-shown cards
  /// don't replay when scrolled back into view.
  Widget _listItem(Prescription item, int index, {required bool readOnly}) {
    final firstShow = _animatedIds.add(item.id);
    return AppEntrance(
      key: ValueKey(item.id),
      index: index < 8 ? index : 0,
      step: const Duration(milliseconds: 55),
      enabled: firstShow,
      child: PrescriptionCard(
        prescription: item,
        readOnly: readOnly,
        selectionMode: _selectMode,
        selected: _selectedIds.contains(item.id),
        onSelectionChanged: (_) => _toggleSelected(item.id),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await ref.read(prescriptionsProvider.notifier).filterDate(picked);
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleAll(List<Prescription> prescriptions) {
    setState(() {
      final pageIds = prescriptions.map((item) => item.id).toSet();
      if (pageIds.every(_selectedIds.contains)) {
        _selectedIds.removeAll(pageIds);
      } else {
        _selectedIds.addAll(pageIds);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedIds.length;
    if (count == 0) return;
    var confirmation = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Delete $count prescription${count == 1 ? '' : 's'}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action cannot be undone. These prescription records '
                'will be permanently removed.',
              ),
              if (count >= 10) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Type $count to confirm:'),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      setDialogState(() => confirmation = value.trim()),
                  decoration: InputDecoration(hintText: '$count'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive,
              ),
              onPressed: count >= 10 && confirmation != '$count'
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text('Delete $count'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final ids = Set<String>.from(_selectedIds);
    final error = await ref
        .read(prescriptionsProvider.notifier)
        .deleteMany(ids);
    if (!mounted) return;
    if (error == null) _exitSelectMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? '$count prescription${count == 1 ? '' : 's'} deleted',
        ),
      ),
    );
  }
}

// ── Header & quick toolbar ───────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.activeCount,
    required this.searchController,
    required this.showClear,
    required this.selectMode,
    required this.dateActive,
    required this.canSelect,
    required this.onNew,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onPickDate,
    required this.onToggleSelect,
  });

  final int? activeCount;
  final TextEditingController searchController;
  final bool showClear;
  final bool selectMode;
  final bool dateActive;
  final bool canSelect;
  final VoidCallback? onNew;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onPickDate;
  final VoidCallback onToggleSelect;

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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prescriptions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: AppColors.onSurface(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DashboardToneBadge(
                    label: activeCount == null
                        ? 'Rx manager'
                        : '$activeCount active Rx',
                    color: AppColors.success,
                    showDot: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            shadcn.PrimaryButton(
              onPressed: onNew,
              size: shadcn.ButtonSize.small,
              leading: const Icon(Icons.add_rounded, size: 17),
              child: const Text('New Prescription'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                enabled: !selectMode,
                onChanged: onSearchChanged,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search patient or diagnosis',
                  hintStyle: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: AppColors.subtleText(context),
                  ),
                  suffixIcon: showClear
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.secondarySurface(
                    context,
                  ).withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: _border(DashboardTokens.border(context)),
                  disabledBorder: _border(DashboardTokens.border(context)),
                  focusedBorder: _border(DashboardTokens.teal, width: 1.4),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _ActionIconButton(
              icon: Icons.event_rounded,
              tooltip: 'Filter by prescription date',
              isActive: dateActive,
              onPressed: selectMode ? null : onPickDate,
            ),
            if (canSelect || selectMode) ...[
              const SizedBox(width: AppSpacing.xs),
              _ActionIconButton(
                icon: selectMode
                    ? Icons.close_rounded
                    : Icons.checklist_rounded,
                tooltip: selectMode ? 'Done' : 'Select prescriptions',
                isActive: selectMode,
                onPressed: onToggleSelect,
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

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final _RxTab selected;
  final bool enabled;
  final ValueChanged<_RxTab> onChanged;

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
              index: selected.index,
              onChanged: (value) => onChanged(_RxTab.values[value]),
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
                for (final tab in _RxTab.values)
                  shadcn.TabItem(
                    child: Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: tab == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: tab == selected
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
    );
  }
}

// ── Summary metric strip ─────────────────────────────────────────────────

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.summary});

  final AsyncValue<PrescriptionSummary> summary;

  @override
  Widget build(BuildContext context) {
    final value = summary.value;
    final strip = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricTile(
          order: 0,
          icon: Icons.medication_rounded,
          color: AppColors.success,
          value: value?.active,
          label: 'Active Rx',
          caption: 'Today & ongoing',
        ),
        const SizedBox(width: 8),
        _MetricTile(
          order: 1,
          icon: Icons.event_repeat_rounded,
          color: AppColors.warning,
          value: value?.followUpsDue,
          label: 'Follow-ups due',
          caption: 'Next $followUpWindowAfter days',
        ),
        const SizedBox(width: 8),
        _MetricTile(
          order: 2,
          icon: Icons.insights_rounded,
          color: AppColors.primary600,
          value: value?.issuedThisWeek,
          label: 'Issued this week',
          caption: 'Since Monday',
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: summary.isLoading && value == null
          ? _skeleton(context, strip)
          : strip,
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.order,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.caption,
  });

  final int order;
  final IconData icon;
  final Color color;
  final int? value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      color: AppColors.onSurface(context),
      fontSize: 20,
      height: 1.1,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Expanded(
      child: AppEntrance(
        index: order,
        step: const Duration(milliseconds: 60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.isDark(context)
                ? AppColors.darkCard
                : AppColors.card,
            borderRadius: BorderRadius.circular(
              DashboardTokens.innerRadius + 2,
            ),
            border: Border.all(color: DashboardTokens.border(context)),
            boxShadow: DashboardTokens.shadow(context),
          ),
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
              if (value == null)
                Text('—', style: valueStyle)
              else
                AppCountUp(
                  value: value!.toDouble(),
                  format: (v) => '${v.round()}',
                  delay: Duration(milliseconds: 150 + 60 * order),
                  style: valueStyle,
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
              const SizedBox(height: 1),
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
}

// ── Loading & empty states ───────────────────────────────────────────────

/// Renders [child]'s real layout as a soft pulsing skeleton.
Widget _skeleton(BuildContext context, Widget child) {
  final isDark = AppColors.isDark(context);
  return Skeleton(
    semanticsLabel: 'Loading prescriptions',
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

/// Three 1:1 placeholder cards while the list loads — no spinner.
class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.md,
    ),
    child: _skeleton(
      context,
      const Column(
        children: [
          PrescriptionCardSkeleton(),
          SizedBox(height: 14),
          PrescriptionCardSkeleton(),
          SizedBox(height: 14),
          PrescriptionCardSkeleton(),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  static const _step = Duration(milliseconds: 80);

  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

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
                  DashboardTokens.teal.withValues(alpha: 0.14),
                  AppColors.primary.withValues(alpha: 0.08),
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
                  Icons.medication_liquid_rounded,
                  size: 27,
                  color: DashboardTokens.tealDeep,
                ),
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
        const SizedBox(height: AppSpacing.md),
        AppEntrance(
          index: 4,
          step: _step,
          child: Column(
            children: [
              if (primaryLabel != null)
                shadcn.PrimaryButton(
                  onPressed: onPrimary,
                  leading: const Icon(Icons.add_rounded, size: 16),
                  child: Text(primaryLabel!),
                ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: AppSpacing.xs),
                shadcn.GhostButton(
                  onPressed: onSecondary,
                  child: Text(
                    secondaryLabel!,
                    style: const TextStyle(
                      color: DashboardTokens.tealDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Small building blocks (carried over) ─────────────────────────────────

class _PrescriptionListFooter extends StatelessWidget {
  const _PrescriptionListFooter({
    required this.hasMore,
    required this.isLoading,
    required this.onLoadMore,
    this.date,
  });

  final bool hasMore;
  final bool isLoading;
  final DateTime? date;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Center(
      child: hasMore
          ? shadcn.OutlineButton(
              onPressed: isLoading ? null : onLoadMore,
              child: Text(isLoading ? 'Loading…' : 'Load more'),
            )
          : Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primary50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.primary400,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You have reached the end',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Showing records for ${DateFormat('d MMMM yyyy').format(date!)}',
                    style: const TextStyle(
                      color: AppColors.primary200,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ],
            ),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    this.icon,
    this.active = false,
    this.onClear,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: EdgeInsets.only(left: icon == null ? 12 : 9, right: 8),
    decoration: BoxDecoration(
      color: active
          ? DashboardTokens.teal.withValues(alpha: 0.08)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(
        color: active
            ? DashboardTokens.teal.withValues(alpha: 0.35)
            : DashboardTokens.border(context),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 14,
            color: active
                ? DashboardTokens.tealDeep
                : AppColors.mutedText(context),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active
                  ? DashboardTokens.tealDeep
                  : AppColors.onSurface(context),
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 5),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: DashboardTokens.tealDeep,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool isActive;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? DashboardTokens.teal.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
          border: Border.all(
            color: isActive
                ? DashboardTokens.teal.withValues(alpha: 0.4)
                : DashboardTokens.border(context),
          ),
        ),
        child: Icon(icon, size: 20, color: DashboardTokens.tealDeep),
      ),
    ),
  );
}
