import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/patients/domain/entities/medical_record.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:doctylia_app/features/patients/presentation/providers/patient_providers.dart';
import 'package:doctylia_app/features/patients/presentation/widgets/medical_record_section_view.dart';
import 'package:doctylia_app/features/patients/presentation/widgets/patient_card.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class PatientMedicalRecordScreen extends StatelessWidget {
  const PatientMedicalRecordScreen({required this.patientId, super.key});
  final String patientId;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.go(RoutePaths.patients);
    },
    child: DashboardShadcnScope(
      child: FeatureGate(
        feature: FeatureKey.patientRecords,
        lockedChild: const _LockedRecord(),
        child: _EntitledRecord(patientId: patientId),
      ),
    ),
  );
}

class _EntitledRecord extends ConsumerWidget {
  const _EntitledRecord({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider(patientId));
    final record = ref.watch(medicalRecordProvider(patientId));
    final readOnly =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    return DefaultTabController(
      length: 8,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.xxs,
                    AppSpacing.md,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: shadcn.GhostButton(
                      onPressed: () => context.go(RoutePaths.patients),
                      size: shadcn.ButtonSize.small,
                      leading: Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: AppColors.mutedText(context),
                      ),
                      child: Text(
                        'Back to Patients',
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                patient.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: shadcn.LinearProgressIndicator(
                      color: DashboardTokens.teal,
                      minHeight: 3,
                    ),
                  ),
                  error: (_, _) => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Patient record'),
                    ),
                  ),
                  data: (value) => Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xxs,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: _RecordHeaderCard(
                      patient: value,
                      record: record.value,
                    ),
                  ),
                ),
                if (readOnly)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
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
                        color: AppColors.warning.withValues(alpha: 0.3),
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
                            'Your account is in grace mode. Medical records are read-only.',
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
                const _RecordTabBar(),
                Container(height: 1, color: DashboardTokens.border(context)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Overview(patientId: patientId),
                MedicalHistoryView(patientId: patientId, readOnly: readOnly),
                MedicalRecordSectionView(
                  patientId: patientId,
                  section: MedicalRecordSection.medications,
                  readOnly: readOnly,
                ),
                MedicalRecordSectionView(
                  patientId: patientId,
                  section: MedicalRecordSection.allergies,
                  readOnly: readOnly,
                ),
                MedicalRecordSectionView(
                  patientId: patientId,
                  section: MedicalRecordSection.visits,
                  readOnly: readOnly,
                ),
                MedicalRecordSectionView(
                  patientId: patientId,
                  section: MedicalRecordSection.documents,
                  readOnly: readOnly,
                ),
                MedicalRecordSectionView(
                  patientId: patientId,
                  section: MedicalRecordSection.vitals,
                  readOnly: readOnly,
                ),
                MedicalRecordSectionView(
                  patientId: patientId,
                  section: MedicalRecordSection.reminders,
                  readOnly: readOnly,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile summary: identity plus mini-stat tiles drawn from the latest
/// recorded vitals and the allergy list of the already-loaded record.
/// Patient banner (identity + allergy alert) above a 4-cell vitals grid
/// drawn from the two most recent vitals entries of the loaded record.
class _RecordHeaderCard extends StatelessWidget {
  const _RecordHeaderCard({required this.patient, required this.record});

  final Patient patient;
  final MedicalRecordBundle? record;

  @override
  Widget build(BuildContext context) {
    final color = patientStatusColor(patient);
    final readings = _sortedVitals(record?.vitals ?? const []);
    final latest = readings.isEmpty ? null : readings[0];
    final previous = readings.length < 2 ? null : readings[1];
    final allergyCount = record?.allergies.length ?? 0;
    final gender = patient.gender?.trim();
    final meta = [
      if (patient.age != null) '${patient.age} yrs',
      if (gender != null && gender.isNotEmpty) gender,
      patient.phone,
    ].join(' · ');

    _VitalReading reading(String key, {String unit = ''}) {
      final raw = latest?[key]?.toString().trim() ?? '';
      return _VitalReading(
        value: raw.isEmpty ? '—' : '$raw$unit',
        delta: _delta(
          _leadingNumber(latest?[key]),
          _leadingNumber(previous?[key]),
        ),
      );
    }

    return DashboardSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              shadcn.Avatar(
                initials: patientInitials(patient.name),
                size: 48,
                borderRadius: 14,
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
                      'Medical record',
                      style: DashboardTokens.eyebrow(context),
                    ),
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DashboardToneBadge(
                    label: '${patient.totalVisits} visits',
                    color: DashboardTokens.teal,
                    icon: Icons.event_repeat_rounded,
                  ),
                  if (allergyCount > 0) ...[
                    const SizedBox(height: 4),
                    DashboardToneBadge(
                      label:
                          '$allergyCount allerg${allergyCount == 1 ? 'y' : 'ies'}',
                      color: AppColors.warning,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _VitalTile(
                icon: Icons.bloodtype_outlined,
                label: 'BP',
                reading: reading('blood_pressure'),
                color: AppColors.destructive,
              ),
              const SizedBox(width: 6),
              _VitalTile(
                icon: Icons.favorite_border_rounded,
                label: 'Pulse',
                reading: reading('pulse'),
                color: AppColors.pink,
              ),
              const SizedBox(width: 6),
              _VitalTile(
                icon: Icons.air_rounded,
                label: 'SpO₂',
                reading: reading('spo2', unit: '%'),
                color: DashboardTokens.teal,
              ),
              const SizedBox(width: 6),
              _VitalTile(
                icon: Icons.thermostat_rounded,
                label: 'Temp',
                reading: reading('temperature', unit: '°'),
                color: AppColors.orange,
              ),
            ],
          ),
          if (latest != null && latest['recorded_date'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'Latest vitals · ${latest['recorded_date']}',
              style: TextStyle(
                color: AppColors.subtleText(context),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Vitals entries newest first by `recorded_date` (unparseable dates last).
  static List<Map<String, dynamic>> _sortedVitals(
    List<MedicalRecordItem> items,
  ) {
    final list = [...items];
    DateTime? dateOf(MedicalRecordItem item) =>
        DateTime.tryParse('${item.values['recorded_date'] ?? ''}');
    list.sort((a, b) {
      final da = dateOf(a);
      final db = dateOf(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return [for (final item in list) item.values];
  }

  /// First number in a value ("120/80" → 120, "98.6" → 98.6).
  static double? _leadingNumber(Object? value) {
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch('${value ?? ''}');
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  static double? _delta(double? latest, double? previous) =>
      latest == null || previous == null ? null : latest - previous;
}

class _VitalReading {
  const _VitalReading({required this.value, required this.delta});
  final String value;

  /// Change vs the previous reading; null when there is no comparison.
  final double? delta;
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.icon,
    required this.label,
    required this.reading,
    required this.color,
  });

  final IconData icon;
  final String label;
  final _VitalReading reading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final delta = reading.delta;
    final trendIcon = delta == null
        ? null
        : delta > 0
        ? Icons.arrow_upward_rounded
        : delta < 0
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.mutedText(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trendIcon != null)
                  Icon(
                    trendIcon,
                    size: 11,
                    color: AppColors.mutedText(context),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                reading.value,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill tab switcher bound to the [DefaultTabController]: muted track with
/// the selected section as a filled teal pill.
class _RecordTabBar extends StatelessWidget {
  const _RecordTabBar();

  static const _tabs = [
    (label: 'Overview', icon: Icons.dashboard_rounded),
    (label: 'History', icon: Icons.history_rounded),
    (label: 'Medications', icon: Icons.medication_rounded),
    (label: 'Allergies', icon: Icons.warning_amber_rounded),
    (label: 'Visits', icon: Icons.event_note_rounded),
    (label: 'Documents', icon: Icons.folder_rounded),
    (label: 'Vitals', icon: Icons.monitor_heart_rounded),
    (label: 'Reminders', icon: Icons.notifications_active_rounded),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(999),
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DashboardTokens.teal, DashboardTokens.tealDeep],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: DashboardTokens.teal.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.mutedText(context),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: (index) => DefaultTabController.of(context).animateTo(index),
        tabs: [
          for (final tab in _tabs)
            Tab(
              height: 34,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 15),
                  const SizedBox(width: 6),
                  Text(tab.label),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.patientId});
  final String patientId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(medicalRecordProvider(patientId));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(medicalRecordProvider(patientId).future),
      child: record.when(
        loading: () => const _OverviewSkeleton(),
        error: (_, _) => ListView(
          children: [
            SizedBox(
              height: 300,
              child: _OverviewError(
                onRetry: () => ref.invalidate(medicalRecordProvider(patientId)),
              ),
            ),
          ],
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Record overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Tap a card to open that section.',
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - AppSpacing.sm) / 2;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CountCard(
                      width: width,
                      label: 'Conditions',
                      tabIndex: 1,
                      count: value.conditions.length,
                      icon: Icons.monitor_heart_rounded,
                      color: AppColors.primary,
                    ),
                    _CountCard(
                      width: width,
                      label: 'Medications',
                      tabIndex: 2,
                      count: value.medications.length,
                      icon: Icons.medication_rounded,
                      color: DashboardTokens.teal,
                    ),
                    _CountCard(
                      width: width,
                      label: 'Known allergies',
                      tabIndex: 3,
                      count: value.allergies.length,
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                    ),
                    _CountCard(
                      width: width,
                      label: 'Visits',
                      tabIndex: 4,
                      count: value.visits.length,
                      icon: Icons.note_alt_rounded,
                      color: AppColors.pink,
                    ),
                    _CountCard(
                      width: width,
                      label: 'Documents',
                      tabIndex: 5,
                      count: value.documents.length,
                      icon: Icons.folder_rounded,
                      color: AppColors.orange,
                    ),
                    _CountCard(
                      width: width,
                      label: 'Reminders',
                      tabIndex: 7,
                      count: value.reminders.length,
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.success,
                    ),
                  ],
                );
              },
            ),
            if (value.visits.isNotEmpty) ...[
              _OverviewHeading(
                title: 'Visit timeline',
                icon: Icons.timeline_rounded,
                trailing: value.visits.length > 5
                    ? 'Latest 5 of ${value.visits.length}'
                    : null,
              ),
              _VisitTimeline(visits: value.visits),
            ],
            if (value.medications.any((m) => m.status == 'active')) ...[
              const _OverviewHeading(
                title: 'Active medications',
                icon: Icons.medication_outlined,
              ),
              _BadgeWrap(
                children: [
                  for (final medication in value.medications.where(
                    (m) => m.status == 'active',
                  ))
                    _InfoChip(
                      icon: Icons.medication_rounded,
                      label: medication.name,
                      detail: [medication.dosage, medication.frequency]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      color: DashboardTokens.teal,
                    ),
                ],
              ),
            ],
            if (value.documents.isNotEmpty) ...[
              const _OverviewHeading(
                title: 'Recent documents',
                icon: Icons.attach_file_rounded,
              ),
              _BadgeWrap(
                children: [
                  for (final document in ([
                    ...value.documents,
                  ]..sort((a, b) => b.date.compareTo(a.date))).take(6))
                    _InfoChip(
                      icon: Icons.description_outlined,
                      label: document.name,
                      detail: DateFormat('d MMM yyyy').format(document.date),
                      color: AppColors.orange,
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (value.conditions.isEmpty &&
                value.medications.isEmpty &&
                value.allergies.isEmpty &&
                value.visits.isEmpty)
              DashboardSurface(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const DashboardIconTile(
                      icon: Icons.note_add_rounded,
                      color: DashboardTokens.teal,
                      size: 52,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No medical-record data yet. Add a record from one of '
                      'the tabs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: 13,
                        height: 1.45,
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.width,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.tabIndex,
  });
  final double width;
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  /// Index in [_RecordTabBar._tabs] opened when the card is tapped (web
  /// parity: overview cards navigate to their section).
  final int tabIndex;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      button: true,
      label: 'Open $label',
      child: DashboardSurface(
        onTap: () => DefaultTabController.of(context).animateTo(tabIndex),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DashboardIconTile(icon: icon, color: color, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: AppColors.onSurface(context),
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverviewSkeleton extends StatefulWidget {
  const _OverviewSkeleton();

  @override
  State<_OverviewSkeleton> createState() => _OverviewSkeletonState();
}

class _OverviewSkeletonState extends State<_OverviewSkeleton>
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) =>
        Opacity(opacity: 0.55 + _controller.value * 0.45, child: child),
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: List.generate(
        4,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.secondarySurface(context),
            borderRadius: BorderRadius.circular(DashboardTokens.radius),
          ),
        ),
      ),
    ),
  );
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DashboardIconTile(
          icon: Icons.cloud_off_rounded,
          color: AppColors.destructive,
          size: 60,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Could not load this medical record.',
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        shadcn.OutlineButton(
          onPressed: onRetry,
          leading: const Icon(Icons.refresh_rounded, size: 16),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _LockedRecord extends StatelessWidget {
  const _LockedRecord();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: DashboardSurface(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    DashboardTokens.teal.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Patient Medical Records',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Full medical records are available on the Premium plan. '
              'Upgrade to access history, visits, documents, vitals and '
              'reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText(context)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Section heading used inside the overview.
class _OverviewHeading extends StatelessWidget {
  const _OverviewHeading({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: 16, color: DashboardTokens.tealDeep),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

/// Vertical visit timeline: date marker, rail and a visit card per entry.
class _VisitTimeline extends StatelessWidget {
  const _VisitTimeline({required this.visits});

  final List<PatientVisit> visits;

  @override
  Widget build(BuildContext context) {
    final sorted = [...visits]..sort((a, b) => b.date.compareTo(a.date));
    final shown = sorted.take(5).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          _TimelineEntry(visit: shown[i], isLast: i == shown.length - 1),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.visit, required this.isLast});

  final PatientVisit visit;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reason = visit.reason?.trim();
    final diagnosis = visit.diagnosis?.trim();
    final notes = visit.notes?.trim();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Container(
                  width: 42,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: DashboardTokens.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: DashboardTokens.teal.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d').format(visit.date),
                        style: const TextStyle(
                          color: DashboardTokens.tealDeep,
                          fontSize: 15,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(visit.date).toUpperCase(),
                        style: const TextStyle(
                          color: DashboardTokens.tealDeep,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: DashboardTokens.border(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
              child: DashboardSurface(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason == null || reason.isEmpty
                                ? 'Consultation'
                                : reason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onSurface(context),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('yyyy').format(visit.date),
                          style: TextStyle(
                            color: AppColors.subtleText(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (diagnosis != null && diagnosis.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      DashboardToneBadge(
                        label: 'Dx · $diagnosis',
                        color: AppColors.primary,
                        icon: Icons.medical_information_outlined,
                      ),
                    ],
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notes,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrap of compact badges (medications, documents).
class _BadgeWrap extends StatelessWidget {
  const _BadgeWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 6, children: children);
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty)
                  TextSpan(
                    text: '  $detail',
                    style: TextStyle(color: AppColors.mutedText(context)),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
