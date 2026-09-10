import 'dart:async';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_card.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentsProvider);
    final summary = ref.watch(appointmentSummaryProvider);
    final writeDisabled =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RoutePaths.dashboard);
      },
      child: Scaffold(
        floatingActionButton: _selectionMode
            ? null
            : FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                onPressed: writeDisabled
                    ? null
                    : () => showAppointmentForm(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.035),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        enabled: !_selectionMode,
                        onChanged: _search,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Search patient or service',
                          hintStyle: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12.5,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.3,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _RoundIconButton(
                    icon: Icons.date_range_rounded,
                    tooltip: 'Filter by date range',
                    isActive: _dateRange != null,
                    onPressed: _selectionMode ? null : _pickDateRange,
                  ),
                ],
              ),
            ),
            if (_dateRange != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      right: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _dateRangeLabel(_dateRange!),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          onPressed: _clearDates,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _AppointmentSummaryStrip(summary: summary),
            SizedBox(
              height: 46,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                children:
                    [
                      null,
                      AppointmentStatus.pending,
                      AppointmentStatus.confirmed,
                      AppointmentStatus.completed,
                      AppointmentStatus.cancelled,
                      AppointmentStatus.noShow,
                    ].map((status) {
                      final label = status == null
                          ? 'All'
                          : _statusLabel(status);
                      final selected = _status == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          avatar: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                          label: Text(label),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Theme.of(context).cardColor,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : Colors.black.withValues(alpha: 0.07),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          onSelected: _selectionMode
                              ? null
                              : (_) {
                                  setState(() => _status = status);
                                  ref
                                      .read(appointmentsProvider.notifier)
                                      .filterStatus(status);
                                },
                        ),
                      );
                    }).toList(),
              ),
            ),
            if (writeDisabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Trial grace access is read-only. Upgrade to edit.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: state.when(
                loading: () =>
                    const AppLoadingView(label: 'Loading appointments'),
                error: (error, _) => AppErrorView(
                  message: error is AppFailure
                      ? error.userMessage
                      : 'Could not load appointments.',
                  onRetry: () =>
                      ref.read(appointmentsProvider.notifier).refresh(),
                ),
                data: (page) => RefreshIndicator(
                  onRefresh: () =>
                      ref.read(appointmentsProvider.notifier).refresh(),
                  child: page.items.isEmpty
                      ? ListView(
                          children: const [
                            AppEmptyView(
                              icon: Icons.event_busy_rounded,
                              title: 'No appointments',
                              message:
                                  'Try changing the filters or add an appointment.',
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _SelectionBar(
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
                            Expanded(
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  0,
                                  AppSpacing.md,
                                  96,
                                ),
                                itemCount: page.items.length + 1,
                                itemBuilder: (context, index) =>
                                    index == page.items.length
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
                                        onSelected: () => _toggleSelected(
                                          page.items[index].id,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
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
            color: AppColors.onSurface(context),
          ),
          const SizedBox(width: 6),
          _SummaryCard(
            value: value.pending,
            label: 'Pending',
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          _SummaryCard(
            value: value.completed,
            label: 'Completed',
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
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
          SizedBox(width: 6),
          _SummaryCard(label: 'Pending'),
          SizedBox(width: 6),
          _SummaryCard(label: 'Completed'),
          SizedBox(width: 6),
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
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value?.toString() ?? '—',
            style: TextStyle(
              color: color ?? AppColors.subtleText(context),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 8.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Consistent tinted-square icon button (matches the pattern used across
/// patients/billing search rows), with an active state for the date filter.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;

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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.32)
                : AppColors.border(context),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(context, alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    ),
  );
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
    decoration: selectionMode
        ? BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          )
        : null,
    child: Row(
      children: [
        Expanded(
          child: Text(
            selectionMode
                ? '$selectedCount of $pageCount selected on loaded pages'
                : '${totalCount ?? pageCount} appointments',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selectionMode ? FontWeight.w600 : FontWeight.normal,
              color: selectionMode
                  ? AppColors.primary
                  : AppColors.mutedText(context),
            ),
          ),
        ),
        if (selectionMode) ...[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: onSelectAll,
            child: const Text('Select all'),
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
                : const Icon(Icons.delete_rounded),
          ),
        ],
        IconButton(
          onPressed: writeDisabled ? null : onToggleMode,
          tooltip: selectionMode
              ? 'Exit selection mode'
              : 'Select appointments',
          icon: Icon(
            selectionMode ? Icons.close_rounded : Icons.checklist_rounded,
            color: AppColors.primary,
            size: 19,
          ),
        ),
      ],
    ),
  );
}

String _statusLabel(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => 'Pending',
  AppointmentStatus.confirmed => 'Confirmed',
  AppointmentStatus.completed => 'Completed',
  AppointmentStatus.cancelled => 'Cancelled',
  AppointmentStatus.noShow => 'No Show',
};
