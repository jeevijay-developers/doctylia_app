import 'dart:async';
import 'dart:io';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:doctylia_app/features/patients/presentation/providers/patient_providers.dart';
import 'package:doctylia_app/features/patients/presentation/widgets/patient_card.dart';
import 'package:doctylia_app/features/patients/presentation/widgets/patient_form_sheet.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});
  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  Timer? _debounce;
  DateTime? _date;
  String _search = '';
  bool _exporting = false;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(patientsProvider.notifier).filterDate(_date);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientsProvider);
    final writeDisabled =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RoutePaths.dashboard);
      },
      child: Scaffold(
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
                onPressed: writeDisabled
                    ? null
                    : () => showPatientForm(context, ref),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add Patient'),
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
                                .read(patientsProvider.notifier)
                                .search(value),
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Search name or phone',
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
                    tooltip: 'Filter by registration date',
                    isActive: _date != null,
                    onPressed: _selectMode ? null : _pickDate,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _ActionIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Export all patients',
                    onPressed: _exporting || _selectMode ? null : _exportCsv,
                    loading: _exporting,
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
                        _PatientFilterPill(
                          icon: Icons.event_outlined,
                          label:
                              'Registered ${DateFormat('d MMM yyyy').format(_date!)}',
                          active: true,
                          onClear: _selectMode
                              ? null
                              : () {
                                  setState(() => _date = null);
                                  ref
                                      .read(patientsProvider.notifier)
                                      .filterDate(null);
                                },
                        ),
                      if (_date != null && state.value != null)
                        const SizedBox(width: 8),
                      if (state.value case final page?)
                        _PatientFilterPill(
                          label:
                              'All Patients (${page.totalCount ?? page.items.length})',
                        ),
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
                      child: Row(
                        children: [
                          if (!_selectMode) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              _selectMode
                                  ? '${_selectedIds.length} of ${page.items.length} selected on this page'
                                  : _search.trim().isNotEmpty || _date != null
                                  ? '${page.totalCount ?? page.items.length} ${_patientWord(page.totalCount ?? page.items.length)} match your filters'
                                  : '${page.totalCount ?? page.items.length} ${_patientWord(page.totalCount ?? page.items.length)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
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
                        tooltip: _selectMode ? 'Done' : 'Select patients',
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
                loading: () => const AppLoadingView(label: 'Loading patients'),
                error: (error, _) => AppErrorView(
                  message: error is AppFailure
                      ? error.userMessage
                      : 'Could not load patients.',
                  onRetry: () => ref.read(patientsProvider.notifier).refresh(),
                ),
                data: (page) => RefreshIndicator(
                  onRefresh: () =>
                      ref.read(patientsProvider.notifier).refresh(),
                  child: page.items.isEmpty
                      ? ListView(
                          children: [
                            AppEmptyView(
                              icon: Icons.people_outline_rounded,
                              title: _search.trim().isNotEmpty || _date != null
                                  ? 'No patients match your filters'
                                  : 'No patients yet',
                              message:
                                  _search.trim().isNotEmpty || _date != null
                                  ? 'Try a different search or date.'
                                  : 'Add your first patient to get started.',
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
                              ? PagedListFooter(
                                  hasMore: page.hasMore,
                                  isLoading: page.isLoadingMore,
                                  onLoadMore: () => ref
                                      .read(patientsProvider.notifier)
                                      .loadMore(),
                                )
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: PatientCard(
                                    patient: page.items[index],
                                    selectionMode: _selectMode,
                                    selected: _selectedIds.contains(
                                      page.items[index].id,
                                    ),
                                    onSelectionChanged: (_) =>
                                        _toggleSelected(page.items[index].id),
                                    onTap: _selectMode
                                        ? () => _toggleSelected(
                                            page.items[index].id,
                                          )
                                        : () => _showPatientDetails(
                                            page.items[index],
                                          ),
                                    onEdit: writeDisabled || _selectMode
                                        ? null
                                        : () => showPatientForm(
                                            context,
                                            ref,
                                            patient: page.items[index],
                                          ),
                                    onCall: () => ref
                                        .read(externalLinkServiceProvider)
                                        .open(
                                          Uri(
                                            scheme: 'tel',
                                            path: page.items[index].phone,
                                          ),
                                        ),
                                    onCreatePrescription: () =>
                                        context.go(RoutePaths.prescriptions),
                                    onBookVisit: () =>
                                        context.go(RoutePaths.appointments),
                                  ),
                                ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _patientWord(int count) => count == 1 ? 'patient' : 'patients';

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleAll(List<Patient> patients) {
    setState(() {
      final pageIds = patients.map((patient) => patient.id).toSet();
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

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (value == null) return;
    setState(() => _date = value);
    await ref.read(patientsProvider.notifier).filterDate(value);
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    final result = await ref.read(patientsProvider.notifier).exportRows();
    if (!mounted) return;
    await result.fold(
      onSuccess: (patients) async {
        if (patients.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No patients to export')),
          );
          return;
        }
        final csv = _patientsCsv(patients);
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}${Platform.pathSeparator}patients-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
        final file = File(path);
        await file.writeAsString('\ufeff$csv', flush: true);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: 'text/csv')],
            subject: 'Doctylia patient export',
          ),
        );
      },
      onFailure: (failure) async => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _showPatientDetails(Patient patient) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.1),
                      foregroundColor: AppColors.teal,
                      child: Text(
                        patient.name.isEmpty
                            ? 'P'
                            : patient.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            patient.phone,
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.go(RoutePaths.patientRecord(patient.id));
                  },
                  icon: const Icon(Icons.folder_shared_rounded),
                  label: const Text('Open Medical Record'),
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  children: [
                    _PatientDetailTile(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: patient.email ?? '—',
                    ),
                    _PatientDetailTile(
                      icon: Icons.monitor_heart_outlined,
                      label: 'Age',
                      value: patient.age == null ? '—' : '${patient.age} years',
                    ),
                    _PatientDetailTile(
                      icon: Icons.people_outline_rounded,
                      label: 'Gender',
                      value: patient.gender ?? '—',
                    ),
                    _PatientDetailTile(
                      icon: Icons.calendar_month_outlined,
                      label: 'Total Visits',
                      value: '${patient.totalVisits}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: BorderSide(
                      color: AppColors.destructive.withValues(alpha: 0.3),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDelete(patient);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete Patient Record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete patient record?'),
        content: Text(
          "This permanently removes ${patient.name}'s record and cannot be "
          'undone. Past appointments will remain in appointment history.',
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await ref.read(patientsProvider.notifier).delete(patient.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Patient deleted')));
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedIds.length;
    if (count == 0) return;
    var confirmation = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Delete $count ${_patientWord(count)}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This cannot be undone. Past appointments and invoices will '
                'remain; linked prescriptions will be kept but detached.',
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
    final error = await ref.read(patientsProvider.notifier).deleteMany(ids);
    if (!mounted) return;
    if (error == null) _exitSelectMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '$count ${_patientWord(count)} deleted')),
    );
  }

  String _patientsCsv(List<Patient> patients) {
    const headers = [
      'Name',
      'Phone',
      'Email',
      'Age',
      'Gender',
      'First Visit',
      'Last Visit',
      'Total Visits',
      'Notes',
    ];
    String cell(Object? value) {
      if (value == null) return '';
      return '"${value.toString().replaceAll('"', '""')}"';
    }

    String date(DateTime? value) =>
        value == null ? '' : DateFormat('dd/MM/yyyy').format(value);
    return [
      headers.join(','),
      for (final patient in patients)
        [
          cell(patient.name),
          cell(patient.phone),
          cell(patient.email),
          patient.age ?? '',
          cell(patient.gender),
          cell(date(patient.firstVisit)),
          cell(date(patient.lastVisit)),
          patient.totalVisits,
          cell(patient.notes),
        ].join(','),
    ].join('\n');
  }
}

class _PatientDetailTile extends StatelessWidget {
  const _PatientDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).hintColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    ),
  );
}

class _PatientFilterPill extends StatelessWidget {
  const _PatientFilterPill({
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

/// Consistent tinted-square icon button used across the app's action rows,
/// with an optional "active" state (used for the date filter) and an
/// inline loading spinner (used for export).
class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    return Tooltip(
      message: tooltip ?? '',
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
              color: isActive
                  ? AppColors.primary200
                  : AppColors.border(context),
            ),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
