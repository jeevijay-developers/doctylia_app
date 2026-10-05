import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_banners.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_stats_grid.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/revenue_website_cards.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/today_schedule_card.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vertical gap between dashboard sections (shared by loaded + skeleton).
const _sectionGap = 20.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final session = ref.watch(authControllerProvider).value?.session;
    return dashboard.when(
      skipLoadingOnRefresh: true,
      loading: () => _DashboardSkeleton(
        session: session,
        trialStatus: ref.watch(trialStatusProvider),
      ),
      error: (error, _) => Center(
        child: SingleChildScrollView(
          child: AppErrorView(
            message: error is AppFailure
                ? error.userMessage
                : 'The dashboard could not be loaded.',
            onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
        ),
      ),
      data: (snapshot) {
        if (snapshot.maintenanceMode) return const _MaintenanceView();
        final trialStatus = ref.watch(trialStatusProvider);
        return RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: _DashboardBody(
            snapshot: snapshot,
            session: session,
            trialStatus: trialStatus,
          ),
        );
      },
    );
  }
}

/// The dashboard's section layout. Used for loaded data and — with a
/// placeholder snapshot — for the skeleton, so both share every size and
/// gap and the swap on load causes no layout shift.
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.snapshot,
    required this.session,
    required this.trialStatus,
  });

  final DashboardSnapshot snapshot;
  final DoctorSession? session;
  final TrialStatusSnapshot trialStatus;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xl,
    ),
    children: [
      DashboardHeader(session: session),
      if (trialStatus.isTrialEndingSoon ||
          trialStatus.isExpired ||
          trialStatus.isCancelled) ...[
        const SizedBox(height: AppSpacing.sm),
        TrialPlanBanner(status: trialStatus),
      ],
      if (snapshot.isNearAppointmentCap) ...[
        const SizedBox(height: AppSpacing.sm),
        AppointmentCapBanner(
          used: snapshot.appointmentsUsed,
          cap: snapshot.appointmentsCap!,
        ),
      ],
      const SizedBox(height: _sectionGap),
      DashboardStatsGrid(snapshot: snapshot),
      if (snapshot.hasNoPracticeData) ...[
        const SizedBox(height: _sectionGap),
        const _NewDoctorEmptyState(),
      ],
      const SizedBox(height: _sectionGap),
      TodayScheduleCard(
        appointments: snapshot.todaySchedule,
        totalTodayCount: snapshot.stats.todayAppointments,
      ),
      const SizedBox(height: _sectionGap),
      RevenueCard(
        points: snapshot.revenueSeries,
        monthlyRevenue: snapshot.monthlyRevenue,
        growthPercent: snapshot.stats.revenueGrowthPercent,
      ),
      const SizedBox(height: _sectionGap),
      WebsiteShareCard(
        doctorName: session?.displayName ?? 'Doctor',
        websiteSlug: snapshot.websiteSlug,
        isLive: snapshot.websiteIsLive,
      ),
    ],
  );
}

/// Loading state: the real section layout rendered as a 1:1 skeleton.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.session, required this.trialStatus});

  final DoctorSession? session;
  final TrialStatusSnapshot trialStatus;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Skeleton(
      semanticsLabel: 'Loading dashboard',
      palette: SkeletonPalette(
        surface: isDark ? AppColors.darkCard : AppColors.card,
        surfaceBorder: DashboardTokens.border(context),
        // Dark mode needs lighter bones to read on dark cards.
        bone: isDark
            ? AppColors.darkBorder
            : AppColors.secondarySurface(context),
        innerSurface: isDark
            ? AppColors.darkSecondary
            : AppColors.secondarySurface(context).withValues(alpha: 0.55),
      ),
      child: _DashboardBody(
        snapshot: _placeholderSnapshot(),
        session: session,
        trialStatus: trialStatus,
      ),
    );
  }

  /// Typical-shaped data so every section renders at its loaded size. The
  /// schedule assumes two rows; the real count is only known after loading.
  static DashboardSnapshot _placeholderSnapshot() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DashboardSnapshot(
      stats: const DashboardStats(
        appointments: 128,
        patients: 96,
        totalRevenue: 48000,
        todayAppointments: 2,
        reviewCount: 12,
        averageRating: 4.8,
        monthlyPaidInvoices: 18,
        revenueGrowthPercent: 12.5,
        newPatientsThisWeek: 4,
        activePatientsThisWeek: 9,
      ),
      todaySchedule: [
        for (var i = 0; i < 2; i++)
          DashboardAppointment(
            id: 'skeleton-$i',
            patientName: 'Patient Name',
            serviceName: 'Consultation',
            appointmentType: 'Clinic',
            scheduledAt: today.add(Duration(hours: 10 + i)),
            status: DashboardAppointmentStatus.confirmed,
            timeSlot: '10:00',
          ),
      ],
      revenueSeries: [
        for (var i = 0; i < 30; i++)
          RevenuePoint(
            day: today.subtract(Duration(days: 29 - i)),
            amount: 1000 + (i % 6) * 300,
          ),
      ],
      monthlyRevenue: 24000,
      websiteIsLive: true,
      websiteSlug: 'your-clinic',
      appointmentsUsed: 0,
      appointmentsCap: null,
    );
  }
}

class _NewDoctorEmptyState extends StatelessWidget {
  const _NewDoctorEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 30,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Your dashboard is ready',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'New appointments, patients, and revenue will appear here as '
          'your practice starts receiving bookings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText(context)),
        ),
      ],
    ),
  );
}

class _MaintenanceView extends StatelessWidget {
  const _MaintenanceView();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.build_rounded,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Under maintenance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Doctylia is undergoing maintenance. Please try again shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText(context)),
          ),
        ],
      ),
    ),
  );
}
