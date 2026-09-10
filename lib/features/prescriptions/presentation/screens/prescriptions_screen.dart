import 'dart:async';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:doctylia_app/features/prescriptions/presentation/widgets/prescription_card.dart';
import 'package:doctylia_app/features/prescriptions/presentation/widgets/prescription_form_sheet.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriptionsProvider);
    final readOnly =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    return Scaffold(
      floatingActionButton: _selectMode
          ? _selectedIds.isEmpty
                ? null
                : FloatingActionButton.extended(
                    onPressed: _confirmBulkDelete,
                    backgroundColor: AppColors.destructive,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text('Delete ${_selectedIds.length}'),
                  )
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: readOnly
                  ? null
                  : () async {
                      ref.invalidate(prescriptionPatientsProvider);
                      final value = await showPrescriptionForm(context, ref);
                      if (value != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prescription saved')),
                        );
                      }
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Rx'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.045),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      enabled: !_selectMode,
                      onChanged: (value) {
                        setState(() => _search = value);
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 350),
                          () => ref
                              .read(prescriptionsProvider.notifier)
                              .search(value),
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Search patient or diagnosis',
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
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(
                            color: AppColors.border(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.3,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(
                            color: AppColors.border(context),
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
                _ActionIconButton(
                  icon: Icons.event_rounded,
                  tooltip: 'Filter by prescription date',
                  isActive: _date != null,
                  onPressed: _selectMode ? null : _pickDate,
                ),
              ],
            ),
          ),
          if (_date != null || state.value != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_date != null)
                      _FilterPill(
                        icon: Icons.event_outlined,
                        label:
                            'Prescriptions ${DateFormat('d MMM yyyy').format(_date!)}',
                        active: true,
                        onClear: _selectMode
                            ? null
                            : () {
                                setState(() => _date = null);
                                ref
                                    .read(prescriptionsProvider.notifier)
                                    .filterDate(null);
                              },
                      ),
                    if (_date != null && state.value != null) ...[
                      const SizedBox(width: 8),
                      _FilterPill(
                        label:
                            'Active Rx (${state.value!.totalCount ?? state.value!.items.length})',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (state.value case final page?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectMode
                          ? '${_selectedIds.length} of ${page.items.length} selected on this page'
                          : '${page.totalCount ?? page.items.length} total clinical ${_recordLabel(page.totalCount ?? page.items.length)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (page.items.isNotEmpty && _selectMode)
                    IconButton(
                      onPressed: () => _toggleAll(page.items),
                      tooltip: _selectedIds.length == page.items.length
                          ? 'Deselect all'
                          : 'Select all on this page',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _selectedIds.length == page.items.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                      ),
                    ),
                  if (page.items.isNotEmpty)
                    IconButton(
                      onPressed: _selectMode
                          ? _exitSelectMode
                          : () => setState(() => _selectMode = true),
                      tooltip: _selectMode ? 'Done' : 'Select prescriptions',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _selectMode
                            ? Icons.close_rounded
                            : Icons.delete_outline_rounded,
                        color: _selectMode ? AppColors.destructive : null,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: state.when(
              loading: () =>
                  const AppLoadingView(label: 'Loading prescriptions'),
              error: (error, _) => AppErrorView(
                message: error is AppFailure
                    ? error.userMessage
                    : 'Could not load prescriptions.',
                onRetry: () =>
                    ref.read(prescriptionsProvider.notifier).refresh(),
              ),
              data: (page) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(prescriptionsProvider.notifier).refresh(),
                child: page.items.isEmpty
                    ? ListView(
                        children: [
                          AppEmptyView(
                            icon: Icons.medication_rounded,
                            title: _search.trim().isNotEmpty || _date != null
                                ? 'No prescriptions match your filters'
                                : 'No prescriptions yet',
                            message: _search.trim().isNotEmpty || _date != null
                                ? 'Try a different search or date.'
                                : 'Create the first prescription to get started.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          96,
                        ),
                        itemCount: page.items.length + 1,
                        itemBuilder: (context, index) =>
                            index == page.items.length
                            ? _PrescriptionListFooter(
                                hasMore: page.hasMore,
                                isLoading: page.isLoadingMore,
                                date: _date,
                                onLoadMore: () => ref
                                    .read(prescriptionsProvider.notifier)
                                    .loadMore(),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: PrescriptionCard(
                                  prescription: page.items[index],
                                  readOnly: readOnly,
                                  selectionMode: _selectMode,
                                  selected: _selectedIds.contains(
                                    page.items[index].id,
                                  ),
                                  onSelectionChanged: (_) =>
                                      _toggleSelected(page.items[index].id),
                                ),
                              ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _recordLabel(int count) => count == 1 ? 'record' : 'records';

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
          ? OutlinedButton(
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
          ? AppColors.primary.withValues(alpha: 0.07)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(
        color: active ? AppColors.primary200 : AppColors.border(context),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary600 : AppColors.onSurface(context),
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
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
                color: AppColors.primary,
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary50 : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive ? AppColors.primary200 : AppColors.border(context),
          ),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    ),
  );
}
