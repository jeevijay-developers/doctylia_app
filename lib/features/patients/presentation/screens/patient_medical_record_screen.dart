import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/patients/domain/entities/medical_record.dart';
import 'package:doctylia_app/features/patients/presentation/providers/patient_providers.dart';
import 'package:doctylia_app/features/patients/presentation/widgets/medical_record_section_view.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PatientMedicalRecordScreen extends StatelessWidget {
  const PatientMedicalRecordScreen({required this.patientId, super.key});
  final String patientId;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.go(RoutePaths.patients);
    },
    child: FeatureGate(
      feature: FeatureKey.patientRecords,
      lockedChild: const _LockedRecord(),
      child: _EntitledRecord(patientId: patientId),
    ),
  );
}

class _EntitledRecord extends ConsumerWidget {
  const _EntitledRecord({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider(patientId));
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go(RoutePaths.patients),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Patients'),
                  ),
                ),
                patient.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: LinearProgressIndicator(
                      color: AppColors.primary,
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
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.teal.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.teal.withValues(
                              alpha: .12,
                            ),
                            foregroundColor: AppColors.teal,
                            child: Text(
                              value.name.isEmpty
                                  ? '?'
                                  : value.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface(
                                    context,
                                  ).withValues(alpha: 0.45),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                value.name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${value.phone} · ${value.age ?? '-'} yrs · ${value.gender ?? '-'}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.onSurface(
                                    context,
                                  ).withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '${value.totalVisits} visits',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                      ],
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
                      color: AppColors.warning.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: .3),
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
                            'Your account is in grace mode. Medical records are read-only.',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                const _RecordTabBar(),
                const Divider(height: 1),
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

/// Scrollable pill-style tab switcher: each tab gets its own icon, and the
/// selected tab sits inside a solid rounded pill rather than a plain
/// Material underline — matching the segmented style used on the billing
/// screen.
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(AppRadius.sm),
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.onSurface(
            context,
          ).withValues(alpha: 0.55),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: (index) => DefaultTabController.of(context).animateTo(index),
          tabs: [
            for (final tab in _tabs)
              Tab(
                height: 38,
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _CountCard(
                  label: 'Conditions',
                  tabIndex: 1,
                  count: value.conditions.length,
                  icon: Icons.monitor_heart_rounded,
                  color: AppColors.primary,
                ),
                _CountCard(
                  label: 'Medications',
                  tabIndex: 2,
                  count: value.medications.length,
                  icon: Icons.medication_rounded,
                  color: AppColors.teal,
                ),
                _CountCard(
                  label: 'Known allergies',
                  tabIndex: 3,
                  count: value.allergies.length,
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
                _CountCard(
                  label: 'Visits',
                  tabIndex: 4,
                  count: value.visits.length,
                  icon: Icons.note_alt_rounded,
                  color: AppColors.pink,
                ),
                _CountCard(
                  label: 'Documents',
                  tabIndex: 5,
                  count: value.documents.length,
                  icon: Icons.folder_rounded,
                  color: AppColors.orange,
                ),
                _CountCard(
                  label: 'Reminders',
                  tabIndex: 7,
                  count: value.reminders.length,
                  icon: Icons.notifications_active_rounded,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (value.conditions.isEmpty &&
                value.medications.isEmpty &&
                value.allergies.isEmpty &&
                value.visits.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.note_add_rounded,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'No medical-record data yet. Add a record from one of '
                      'the tabs.',
                      textAlign: TextAlign.center,
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
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.tabIndex,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  /// Index in [_RecordTabBar._tabs] opened when the card is tapped (web
  /// parity: overview cards navigate to their section).
  final int tabIndex;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 152,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => DefaultTabController.of(context).animateTo(tabIndex),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: _content(context),
      ),
    ),
  );

  Widget _content(BuildContext context) => Semantics(
    button: true,
    label: 'Open $label',
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.onSurface(context).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: List.generate(
      4,
      (_) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        height: 88,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
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
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.destructive.withOpacity(0.1),
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            size: 30,
            color: AppColors.destructive,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('Could not load this medical record.'),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Patient Medical Records',
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
              style: TextStyle(
                color: AppColors.onSurface(context).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
