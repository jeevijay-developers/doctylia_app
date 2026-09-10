import 'dart:math' as math;

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({required this.snapshot, super.key});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final stats = snapshot.stats;
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final number = NumberFormat.decimalPattern('en_IN');

    return Column(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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

    return _DashboardCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
      child: Column(
        children: [
          Row(
            children: [
              const _IconTile(
                icon: Icons.currency_rupee_rounded,
                color: AppColors.primary,
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
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 23,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: trendColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: trendColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trendText,
                      style: TextStyle(
                        color: trendColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: AppColors.border(context)),
          const SizedBox(height: 12),
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
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$paidInvoiceCount paid invoices this month',
                  style: TextStyle(
                    color: AppColors.mutedText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 88,
                height: 25,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: points.map((point) => point.amount).toList(),
                  ),
                ),
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
  Widget build(BuildContext context) => _DashboardCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _IconTile(icon: icon, color: AppColors.primary, size: 34),
            const Spacer(),
            Flexible(
              child: _Tag(text: tag, color: tagColor),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 23,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
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
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.subtleText(context),
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
    return _DashboardCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const _IconTile(
            icon: Icons.star_rounded,
            color: AppColors.warning,
            size: 34,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Practice Rating',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  hasReviews
                      ? '$reviewCount verified patient reviews'
                      : 'No verified patient reviews yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFF8D78A)),
            ),
            child: Text(
              hasReviews
                  ? '${averageRating.toStringAsFixed(1)} \u2605'
                  : '\u2014',
              style: const TextStyle(
                color: Color(0xFFB96700),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xFF9AA8BC),
          ),
        ],
      ),
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
  Widget build(BuildContext context) {
    final statusColor = isLive ? AppColors.success : AppColors.warning;
    return _DashboardCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const _IconTile(
            icon: Icons.language_rounded,
            color: AppColors.primary,
            size: 34,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Public Profile & Booking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  slug == null
                      ? 'Complete your public profile'
                      : 'doctylia.com/dr/$slug',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: statusColor.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isLive ? 'Live' : 'Draft',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.open_in_new_rounded,
            size: 17,
            color: Color(0xFF97A5BA),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    required this.padding,
    required this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Ink(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(context, alpha: 0.055),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.12)),
    ),
    child: Icon(icon, size: size * 0.48, color: color),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
      ),
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
    canvas.drawPath(
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
