import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_banners.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_stats_grid.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/revenue_website_cards.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/today_schedule_card.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final session = ref.watch(authControllerProvider).value?.session;
    return dashboard.when(
      skipLoadingOnRefresh: true,
      loading: () => const _DashboardLoadingView(),
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
          child: ListView(
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
              const SizedBox(height: AppSpacing.sm),
              DashboardStatsGrid(snapshot: snapshot),
              if (snapshot.hasNoPracticeData) ...[
                const SizedBox(height: AppSpacing.sm),
                const _NewDoctorEmptyState(),
              ],
              const SizedBox(height: AppSpacing.sm),
              TodayScheduleCard(
                appointments: snapshot.todaySchedule,
                totalTodayCount: snapshot.stats.todayAppointments,
              ),
              const SizedBox(height: AppSpacing.sm),
              RevenueCard(
                points: snapshot.revenueSeries,
                monthlyRevenue: snapshot.monthlyRevenue,
                growthPercent: snapshot.stats.revenueGrowthPercent,
              ),
              const SizedBox(height: AppSpacing.sm),
              WebsiteShareCard(
                doctorName: session?.displayName ?? 'Doctor',
                websiteSlug: snapshot.websiteSlug,
                isLive: snapshot.websiteIsLive,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.sm),
        const Center(
          child: SizedBox.square(
            dimension: 30,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Loading your dashboard…',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _DashboardSkeleton(),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      _SkeletonBox(height: 142),
      SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(child: _SkeletonBox(height: 112)),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: _SkeletonBox(height: 112)),
        ],
      ),
      SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(child: _SkeletonBox(height: 112)),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: _SkeletonBox(height: 112)),
        ],
      ),
      SizedBox(height: AppSpacing.sm),
      _SkeletonBox(height: 220),
      SizedBox(height: AppSpacing.sm),
      _SkeletonBox(height: 190),
    ],
  );
}

/// A gently pulsing placeholder — reads as "loading" rather than a static
/// gray block, without pulling in a shimmer package.
class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.height});
  final double height;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.45 + (_controller.value * 0.35),
          child: child,
        );
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        ),
      ),
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
