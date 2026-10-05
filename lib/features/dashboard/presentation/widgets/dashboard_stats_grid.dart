import 'dart:math' as math;

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

const _tabularFigures = [FontFeature.tabularFigures()];

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({required this.snapshot, super.key});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final stats = snapshot.stats;
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final number = NumberFormat.decimalPattern('en_IN');

    return DashboardShadcnScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RevenueCard(
            amount: money.format(stats.totalRevenue),
            paidInvoiceCount: stats.monthlyPaidInvoices,
            growthPercent: stats.revenueGrowthPercent,
            points: snapshot.revenueSeries,
            onTap: () => context.go(RoutePaths.billing),
          ),
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.calendar_today_rounded,
                    tag: 'SCHEDULED',
                    tagColor: AppColors.primary,
                    value: number.format(stats.appointments),
                    label: 'Appointments',
                    detail: '${snapshot.todaySchedule.length} scheduled today',
                    detailColor: AppColors.primary,
                    onTap: () => context.go(RoutePaths.appointments),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.people_outline_rounded,
                    tag: '+${stats.newPatientsThisWeek} NEW',
                    tagColor: AppColors.success,
                    value: number.format(stats.patients),
                    label: 'Total Patients',
                    detail: '${stats.activePatientsThisWeek} active this week',
                    detailColor: AppColors.success,
                    onTap: () => context.go(RoutePaths.patients),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PracticeRatingCard(
            reviewCount: stats.reviewCount,
            averageRating: stats.averageRating,
            onTap: () => context.go(RoutePaths.reviews),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PublicProfileCard(
            isLive: snapshot.websiteIsLive,
            slug: snapshot.websiteSlug,
            onTap: () => context.go(RoutePaths.myWebsite),
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.amount,
    required this.paidInvoiceCount,
    required this.growthPercent,
    required this.points,
    required this.onTap,
  });

  final String amount;
  final int paidInvoiceCount;
  final double? growthPercent;
  final List<RevenuePoint> points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trend = growthPercent;
    final isPositive = trend == null || trend >= 0;
    final trendColor = isPositive ? AppColors.success : AppColors.destructive;
    final trendText = trend == null
        ? 'NEW'
        : '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}%';
    final hasSeries = points.length >= 2;

    return DashboardSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DashboardIconTile(
                icon: Icons.currency_rupee_rounded,
                color: AppColors.primary,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PRACTICE REVENUE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardTokens.eyebrow(context),
                    ),
                    const SizedBox(height: 4),
                    // Fixed line box: long amounts shrink horizontally
                    // without changing the card height (no layout shift).
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(27) * 1.05,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          maxLines: 1,
                          style: TextStyle(
                            color: AppColors.onSurface(context),
                            fontSize: 27,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            fontFeatures: _tabularFigures,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DashboardToneBadge(
                label: trendText,
                color: trendColor,
                icon: isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
              ),
            ],
          ),
          if (hasSeries) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: points.map((point) => point.amount).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          shadcn.Divider(color: DashboardTokens.border(context)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$paidInvoiceCount paid invoices this month',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.subtleText(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.tag,
    required this.tagColor,
    required this.value,
    required this.label,
    required this.detail,
    required this.detailColor,
    required this.onTap,
  });

  final IconData icon;
  final String tag;
  final Color tagColor;
  final String value;
  final String label;
  final String detail;
  final Color detailColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DashboardSurface(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DashboardIconTile(icon: icon, color: tagColor, size: 34),
            const SizedBox(width: 6),
            const Spacer(),
            Flexible(
              flex: 4,
              child: Align(
                alignment: Alignment.centerRight,
                child: DashboardToneBadge(label: tag, color: tagColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            fontFeatures: _tabularFigures,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: detailColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PracticeRatingCard extends StatelessWidget {
  const _PracticeRatingCard({
    required this.reviewCount,
    required this.averageRating,
    required this.onTap,
  });

  final int reviewCount;
  final double averageRating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasReviews = reviewCount > 0;
    return _ListTileCard(
      onTap: onTap,
      icon: Icons.star_rounded,
      iconColor: AppColors.warning,
      title: 'Practice Rating',
      subtitle: hasReviews
          ? '$reviewCount verified patient reviews'
          : 'No verified patient reviews yet',
      trailing: DashboardToneBadge(
        label: hasReviews ? '${averageRating.toStringAsFixed(1)} ★' : '—',
        color: const Color(0xFFB96700),
      ),
      trailingIcon: Icons.chevron_right_rounded,
    );
  }
}

class _PublicProfileCard extends StatelessWidget {
  const _PublicProfileCard({
    required this.isLive,
    required this.slug,
    required this.onTap,
  });

  final bool isLive;
  final String? slug;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _ListTileCard(
    onTap: onTap,
    icon: Icons.language_rounded,
    iconColor: DashboardTokens.teal,
    title: 'Public Profile & Booking',
    subtitle: slug == null
        ? 'Complete your public profile'
        : 'doctylia.com/dr/$slug',
    trailing: DashboardToneBadge(
      label: isLive ? 'Live' : 'Draft',
      color: isLive ? AppColors.success : AppColors.warning,
      showDot: true,
    ),
    trailingIcon: Icons.open_in_new_rounded,
  );
}

/// Compact row card: icon tile, title/subtitle, status badge and affordance.
class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingIcon,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) => DashboardSurface(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        DashboardIconTile(icon: icon, color: iconColor, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
        const SizedBox(width: 6),
        Icon(trailingIcon, size: 17, color: AppColors.subtleText(context)),
      ],
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final normalized = (values[index] - minValue) / range;
      final y = size.height - (normalized * (size.height - 4)) - 2;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.16),
              AppColors.primary.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
