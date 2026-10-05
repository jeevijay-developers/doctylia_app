import 'dart:math' as math;

import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/widgets/whatsapp_icon.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

const _chartColor = Color(0xFF009CDD);

class RevenueCard extends StatelessWidget {
  const RevenueCard({
    required this.points,
    required this.monthlyRevenue,
    this.growthPercent,
    super.key,
  });

  final List<RevenuePoint> points;
  final double monthlyRevenue;
  final double? growthPercent;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final trend = growthPercent;
    final isPositive = trend == null || trend >= 0;
    final trendColor = isPositive ? AppColors.success : AppColors.destructive;

    return DashboardShadcnScope(
      child: DashboardSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DashboardIconTile(
                  icon: Icons.currency_rupee_rounded,
                  color: DashboardTokens.teal,
                  size: 36,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Revenue',
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            money.format(monthlyRevenue),
                            style: TextStyle(
                              color: AppColors.onSurface(context),
                              fontSize: 24,
                              height: 1,
                              letterSpacing: -0.5,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          DashboardToneBadge(
                            label: trend == null
                                ? 'NEW'
                                : '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}%',
                            color: trendColor,
                            icon: isPositive
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const shadcn.OutlineBadge(child: Text('Last 30 days')),
              ],
            ),
            const SizedBox(height: 14),
            shadcn.Divider(color: DashboardTokens.border(context)),
            const SizedBox(height: 14),
            SizedBox(height: 180, child: _RevenueLineChart(points: points)),
          ],
        ),
      ),
    );
  }
}

class _RevenueLineChart extends StatelessWidget {
  const _RevenueLineChart({required this.points});

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final highest = points.fold<double>(
      0,
      (value, point) => math.max(value, point.amount),
    );
    final maxValue = highest <= 0 ? 1.0 : highest * 1.12;
    final interval = maxValue / 4;
    final money = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    // Axis ticks use whole compact values ("₹12K") so they fit their column
    // instead of spilling over the plot ("₹12.35K").
    final axisMoney = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final axisLabelColor = AppColors.subtleText(context);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: points.isEmpty ? 1 : (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxValue,
        clipData: const FlClipData.all(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: DashboardTokens.border(context),
            strokeWidth: 1,
            dashArray: const [3, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(
                  axisMoney.format(value),
                  maxLines: 1,
                  style: TextStyle(color: axisLabelColor, fontSize: 8.5),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 25,
              interval: points.length > 2 ? (points.length - 1) / 2 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final isLast = index == points.length - 1;
                // fitInside keeps the first/last dates within the card
                // instead of overlapping the y-axis or the card edge.
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 7,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    isLast
                        ? 'Today'
                        : DateFormat('MMM d').format(points[index].day),
                    maxLines: 1,
                    style: TextStyle(
                      color: isLast ? AppColors.primary : axisLabelColor,
                      fontSize: 8.5,
                      fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF172236),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots
                .map((spot) {
                  final point = points[spot.x.round()];
                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(point.day)} · ${money.format(point.amount)}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < points.length; index++)
                FlSpot(index.toDouble(), points[index].amount),
            ],
            isCurved: true,
            curveSmoothness: 0.18,
            color: _chartColor,
            barWidth: 2.6,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) =>
                  barData.spots.isNotEmpty && spot.x == barData.spots.last.x,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: _chartColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _chartColor.withValues(alpha: 0.16),
                  _chartColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WebsiteShareCard extends ConsumerWidget {
  const WebsiteShareCard({
    required this.doctorName,
    required this.websiteSlug,
    required this.isLive,
    super.key,
  });

  final String doctorName;
  final String? websiteSlug;
  final bool isLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = websiteSlug == null
        ? null
        : 'https://doctylia.com/dr/$websiteSlug';
    return DashboardShadcnScope(
      child: DashboardSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DashboardIconTile(
                  icon: Icons.share_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Your Website',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.onSurface(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Direct Patient Bookings',
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                DashboardToneBadge(
                  label: isLive ? 'Live' : 'Draft',
                  color: isLive ? AppColors.success : AppColors.warning,
                  showDot: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            shadcn.Divider(color: DashboardTokens.border(context)),
            const SizedBox(height: 12),
            Text(
              url == null
                  ? 'Complete your public profile to start accepting direct patient bookings.'
                  : 'Share your dedicated booking website with patients to get direct appointments with 0% commission.',
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 42,
              padding: const EdgeInsets.only(left: 12, right: 2),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface(
                  context,
                ).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(
                  DashboardTokens.innerRadius,
                ),
                border: Border.all(color: DashboardTokens.border(context)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      url ?? 'Your booking link is not available yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Copy link',
                    child: shadcn.IconButton.ghost(
                      onPressed: url == null ? null : () => _copy(context, url),
                      size: shadcn.ButtonSize.small,
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: AppColors.mutedText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: shadcn.OutlineButton(
                      onPressed: url == null
                          ? null
                          : () => _openSite(context, ref, url),
                      alignment: Alignment.center,
                      leading: const Icon(Icons.open_in_new_rounded, size: 15),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('View site', maxLines: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton.icon(
                      onPressed: url == null ? null : () => _share(ref, url),
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: WhatsAppIcon.brandColor,
                        disabledBackgroundColor: AppColors.secondarySurface(
                          context,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const WhatsAppIcon(size: 16, withBackground: false),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Share on WhatsApp',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(WidgetRef ref, String url) {
    final message = 'Book your appointment online with $doctorName\n\n$url';
    return ref
        .read(externalLinkServiceProvider)
        .open(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'))
        .then((_) {});
  }

  Future<void> _openSite(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final opened = await ref
        .read(externalLinkServiceProvider)
        .open(Uri.parse(url));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the booking site.')),
      );
    }
  }

  Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }
}
