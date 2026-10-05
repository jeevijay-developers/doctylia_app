import 'dart:async';
import 'dart:io';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_ui.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
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
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

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

  /// UI-only: lets the clear (✕) action and "Clear filters" reset the text.
  final _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(patientsProvider.notifier).search(value),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _clearDate() {
    setState(() => _date = null);
    ref.read(patientsProvider.notifier).filterDate(null);
  }

  void _resetFilters() {
    if (_search.isNotEmpty) _clearSearch();
    if (_date != null) _clearDate();
  }

  /// "Registered today" pill: the same single-day filter used on open.
  void _filterToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() => _date = today);
    ref.read(patientsProvider.notifier).filterDate(today);
  }

  bool _isToday(DateTime? value) =>
      value != null && DateUtils.isSameDay(value, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientsProvider);
    final stats = ref.watch(dashboardProvider).value?.stats;
    final writeDisabled =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    final hasFilters = _search.trim().isNotEmpty || _date != null;
    final surface = Theme.of(context).colorScheme.surface;
    final page = state.value;

    final content = state.when<List<Widget>>(
      loading: () => const [SliverToBoxAdapter(child: _PatientsSkeleton())],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorView(
            message: error is AppFailure
                ? error.userMessage
                : 'Could not load patients.',
            onRetry: () => ref.read(patientsProvider.notifier).refresh(),
          ),
        ),
      ],
      data: (page) => page.items.isEmpty
          ? [
              SliverToBoxAdapter(
                child: _PatientsEmptyState(
                  filtered: hasFilters,
                  onReset: _selectMode ? null : _resetFilters,
                  onAdd: writeDisabled
                      ? null
                      : () => showPatientForm(context, ref),
                ),
              ),
            ]
          : [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xxs,
                  AppSpacing.md,
                  96,
                ),
                sliver: SliverList.separated(
                  itemCount: page.items.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => index == page.items.length
                      ? PagedListFooter(
                          hasMore: page.hasMore,
                          isLoading: page.isLoadingMore,
                          onLoadMore: () =>
                              ref.read(patientsProvider.notifier).loadMore(),
                        )
                      : PatientCard(
                          patient: page.items[index],
                          selectionMode: _selectMode,
                          selected: _selectedIds.contains(page.items[index].id),
                          onSelectionChanged: (_) =>
                              _toggleSelected(page.items[index].id),
                          onTap: _selectMode
                              ? () => _toggleSelected(page.items[index].id)
                              : () => _showPatientDetails(page.items[index]),
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
            ],
    );

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RoutePaths.dashboard);
      },
      child: DashboardShadcnScope(
        child: Scaffold(
          floatingActionButton: _selectMode
              ? _selectedIds.isEmpty
                    ? null
                    : FloatingActionButton.extended(
                        onPressed: _confirmBulkDelete,
                        elevation: 2,
                        backgroundColor: AppColors.destructive,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DashboardTokens.radius,
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(
                          'Delete ${_selectedIds.length}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      )
              // The empty state has its own Register CTA; hiding the FAB
              // there keeps it from covering that state's buttons.
              : page != null && page.items.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: writeDisabled
                      ? null
                      : () => showPatientForm(context, ref),
                  elevation: 2,
                  backgroundColor: AppColors.primary600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DashboardTokens.radius),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text(
                    'Add Patient',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
          body: Column(
            children: [
              // ── Unified toolbar: search + date filter + actions menu ──
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
                        controller: _searchController,
                        enabled: !_selectMode,
                        showClear: _search.isNotEmpty,
                        onChanged: _onSearchChanged,
                        onClear: _clearSearch,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _ActionIconButton(
                      icon: Icons.calendar_month_rounded,
                      tooltip: 'Filter by registration date',
                      isActive: _date != null,
                      onPressed: _selectMode ? null : _pickDate,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _ToolbarMenu(
                      exporting: _exporting,
                      canExport: !_exporting && !_selectMode,
                      canSelect:
                          !_selectMode && (page?.items.isNotEmpty ?? false),
                      onExport: _exportCsv,
                      onSelect: () => setState(() => _selectMode = true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(patientsProvider.notifier).refresh(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _DirectoryStats(
                          total: stats?.patients,
                          todayAppointments: stats?.todayAppointments,
                          newThisWeek: stats?.newPatientsThisWeek,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: IgnorePointer(
                            ignoring: _selectMode,
                            child: Opacity(
                              opacity: _selectMode ? 0.5 : 1,
                              child: Row(
                                children: [
                                  _FilterTab(
                                    label: 'All dates',
                                    icon: Icons.all_inclusive_rounded,
                                    selected: _date == null,
                                    onTap: _clearDate,
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterTab(
                                    label: 'Registered today',
                                    icon: Icons.today_rounded,
                                    selected: _isToday(_date),
                                    onTap: _filterToday,
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterTab(
                                    label: _date != null && !_isToday(_date)
                                        ? 'Registered ${DateFormat('d MMM yyyy').format(_date!)}'
                                        : 'Pick date',
                                    icon: Icons.event_outlined,
                                    selected: _date != null && !_isToday(_date),
                                    onTap: _pickDate,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (page != null)
                        SliverToBoxAdapter(
                          child: _CountRow(
                            text: '',
                            leading: _selectMode
                                ? null
                                : _ResultChip(
                                    label:
                                        'All Patients (${page.totalCount ?? page.items.length})',
                                    filtered: hasFilters,
                                  ),
                            trailingText: _selectMode
                                ? '${_selectedIds.length} of ${page.items.length} selected on this page'
                                : hasFilters
                                ? 'match your filters'
                                : null,
                            selectMode: _selectMode,
                            actions: [
                              if (page.items.isNotEmpty && _selectMode) ...[
                                IconButton(
                                  onPressed: () => _toggleAll(page.items),
                                  tooltip:
                                      _selectedIds.length == page.items.length
                                      ? 'Deselect all'
                                      : 'Select all on this page',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    _selectedIds.length == page.items.length
                                        ? Icons.deselect_rounded
                                        : Icons.select_all_rounded,
                                    size: 20,
                                    color: DashboardTokens.tealDeep,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _exitSelectMode,
                                  tooltip: 'Done',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: AppColors.destructive,
                                  ),
                                ),
                              ],
                            ],
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
    final color = patientStatusColor(patient);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: appointmentSheetConstraints(context),
      shape: appointmentSheetShape,
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => DashboardShadcnScope(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    Align(alignment: Alignment.topCenter, child: SheetHandle()),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: AppSpacing.xs),
                        child: SheetCloseButton(),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          shadcn.Avatar(
                            initials: patientInitials(patient.name),
                            size: 56,
                            borderRadius: 16,
                            backgroundColor: color.withValues(alpha: 0.12),
                            theme: shadcn.AvatarTheme(
                              textStyle: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
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
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  patient.phone,
                                  style: TextStyle(
                                    color: AppColors.mutedText(sheetContext),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DashboardToneBadge(
                            label: patient.statusLabel,
                            color: color,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 48,
                        child: shadcn.PrimaryButton(
                          alignment: Alignment.center,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            context.go(RoutePaths.patientRecord(patient.id));
                          },
                          leading: const Icon(
                            Icons.folder_shared_rounded,
                            size: 18,
                          ),
                          child: const Text(
                            'Open Medical Record',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
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
                            value: patient.age == null
                                ? '—'
                                : '${patient.age} years',
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
                      shadcn.Divider(
                        color: DashboardTokens.border(sheetContext),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 44,
                        child: shadcn.Button(
                          alignment: Alignment.center,
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await _confirmDelete(patient);
                          },
                          leading: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          style: const shadcn.ButtonStyle.outline().copyWith(
                            decoration: (context, states, value) =>
                                BoxDecoration(
                                  color: AppColors.destructive.withValues(
                                    alpha: states.contains(WidgetState.hovered)
                                        ? 0.08
                                        : 0.03,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    DashboardTokens.innerRadius,
                                  ),
                                  border: Border.all(
                                    color: AppColors.destructive.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                            textStyle: (context, states, value) =>
                                value.copyWith(
                                  color: AppColors.destructive,
                                  fontWeight: FontWeight.w600,
                                ),
                            iconTheme: (context, states, value) =>
                                value.copyWith(color: AppColors.destructive),
                          ),
                          child: const Text('Delete Patient Record'),
                        ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.enabled,
    required this.showClear,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.onSurface(context), fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search name or phone',
        hintStyle: TextStyle(
          color: AppColors.subtleText(context),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.subtleText(context),
        ),
        suffixIcon: showClear && enabled
            ? Tooltip(
                message: 'Clear search',
                child: shadcn.IconButton.ghost(
                  onPressed: onClear,
                  size: shadcn.ButtonSize.small,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.mutedText(context),
                  ),
                ),
              )
            : null,
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

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.text,
    required this.selectMode,
    required this.actions,
    this.leading,
    this.trailingText,
  });

  final String text;
  final bool selectMode;
  final List<Widget> actions;
  final Widget? leading;
  final String? trailingText;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    constraints: const BoxConstraints(minHeight: 40),
    margin: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xxs,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    padding: EdgeInsets.only(left: selectMode ? AppSpacing.sm : 0),
    decoration: BoxDecoration(
      color: selectMode
          ? DashboardTokens.teal.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
      border: Border.all(
        color: selectMode
            ? DashboardTokens.teal.withValues(alpha: 0.28)
            : Colors.transparent,
      ),
    ),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Text(
            trailingText ?? text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selectMode
                  ? DashboardTokens.tealDeep
                  : AppColors.mutedText(context),
              fontSize: 12,
              fontWeight: selectMode ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

/// Neutral chip showing the current result count.
class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label, required this.filtered});

  final String label;
  final bool filtered;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface(context).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: DashboardTokens.border(context)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.groups_2_outlined,
          size: 14,
          color: AppColors.mutedText(context),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (filtered) ...[
          const SizedBox(width: 5),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: DashboardTokens.teal,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    ),
  );
}

/// Pill filter tab with a filled active state.
class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final foreground = selected ? Colors.white : AppColors.mutedText(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
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
                    : DashboardTokens.border(context),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: DashboardTokens.teal.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppColors.onSurface(context),
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

/// "More" menu folding export and bulk-select into the toolbar.
class _ToolbarMenu extends StatelessWidget {
  const _ToolbarMenu({
    required this.exporting,
    required this.canExport,
    required this.canSelect,
    required this.onExport,
    required this.onSelect,
  });

  final bool exporting;
  final bool canExport;
  final bool canSelect;
  final VoidCallback onExport;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'More actions',
    position: PopupMenuPosition.under,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
      side: BorderSide(color: DashboardTokens.border(context)),
    ),
    onSelected: (value) => switch (value) {
      'export' => onExport(),
      'select' => onSelect(),
      _ => null,
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'export',
        enabled: canExport,
        child: const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.ios_share_rounded, size: 19),
          title: Text('Export all patients'),
        ),
      ),
      PopupMenuItem(
        value: 'select',
        enabled: canSelect,
        child: const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.checklist_rounded, size: 19),
          title: Text('Select patients'),
        ),
      ),
    ],
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
        border: Border.all(color: DashboardTokens.border(context)),
      ),
      child: exporting
          ? const Padding(
              padding: EdgeInsets.all(13),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DashboardTokens.teal,
              ),
            )
          : Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: AppColors.mutedText(context),
            ),
    ),
  );
}

/// Compact 3-column micro-stat bar from the cached dashboard snapshot.
class _DirectoryStats extends StatelessWidget {
  const _DirectoryStats({
    required this.total,
    required this.todayAppointments,
    required this.newThisWeek,
  });

  final int? total;
  final int? todayAppointments;
  final int? newThisWeek;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      0,
    ),
    child: Row(
      children: [
        _StatTile(
          icon: Icons.groups_rounded,
          label: 'Total patients',
          value: total,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _StatTile(
          icon: Icons.event_available_rounded,
          label: "Today's visits",
          value: todayAppointments,
          color: DashboardTokens.teal,
        ),
        const SizedBox(width: 8),
        _StatTile(
          icon: Icons.person_add_alt_rounded,
          label: 'New this week',
          value: newThisWeek,
          color: AppColors.success,
        ),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(DashboardTokens.innerRadius + 2),
        border: Border.all(color: DashboardTokens.border(context)),
        boxShadow: DashboardTokens.shadow(context),
      ),
      child: Row(
        children: [
          DashboardIconTile(icon: icon, color: color, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value?.toString() ?? '—',
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: 17,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.mutedText(context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
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

class _PatientsEmptyState extends StatelessWidget {
  const _PatientsEmptyState({
    required this.filtered,
    required this.onReset,
    required this.onAdd,
  });

  final bool filtered;
  final VoidCallback? onReset;
  final VoidCallback? onAdd;

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
              child: Icon(
                filtered
                    ? Icons.person_search_rounded
                    : Icons.folder_shared_rounded,
                size: 26,
                color: DashboardTokens.tealDeep,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          filtered ? 'No patients match your filters' : 'No patients yet',
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
              ? 'Try a different search or date.'
              : 'Register your first patient to start building records.',
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
          child: const Text('Register Patient'),
        ),
        if (filtered) ...[
          const SizedBox(height: AppSpacing.xs),
          shadcn.GhostButton(
            onPressed: onReset,
            leading: const Icon(
              Icons.filter_alt_off_outlined,
              size: 16,
              color: DashboardTokens.tealDeep,
            ),
            child: const Text(
              'Clear filters',
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface(context).withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
      border: Border.all(color: DashboardTokens.border(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: DashboardTokens.tealDeep),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ],
    ),
  );
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
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
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: shadcn.IconButton.outline(
            onPressed: onPressed,
            icon: Icon(
              icon,
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

class _PatientsSkeleton extends StatefulWidget {
  const _PatientsSkeleton();

  @override
  State<_PatientsSkeleton> createState() => _PatientsSkeletonState();
}

class _PatientsSkeletonState extends State<_PatientsSkeleton>
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
      label: 'Loading patients',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Opacity(opacity: 0.55 + _controller.value * 0.45, child: child),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          itemCount: 4,
          itemBuilder: (context, _) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                          bar(150, 13),
                          const SizedBox(height: 8),
                          bar(110, 16),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  bar(double.infinity, 1),
                  const SizedBox(height: 12),
                  bar(160, 11),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
