import 'dart:math' as math;

import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final trend = growthPercent;
    final isPositive = trend == null || trend >= 0;
    final trendColor = isPositive ? AppColors.success : AppColors.destructive;

    return _DashboardSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionIcon(
                icon: Icons.currency_rupee_rounded,
                color: Color(0xFF00A9B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Revenue',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 3,
                      children: [
                        Text(
                          money.format(monthlyRevenue),
                          style: TextStyle(
                            color: AppColors.onSurface(context),
                            fontSize: 21,
                            height: 1,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: trendColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            trend == null
                                ? '\u2197 NEW'
                                : '${isPositive ? '\u2197 +' : '\u2198 '}${trend.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: trendColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface(context),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Last 30 days',
                  style: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 180, child: _RevenueLineChart(points: points)),
        ],
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
      symbol: '\u20B9',
      decimalDigits: 2,
    );

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
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE6EBF2),
            strokeWidth: 1,
            dashArray: [3, 3],
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
              reservedSize: 34,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                money.format(value),
                style: const TextStyle(color: Color(0xFF8A98AE), fontSize: 8),
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
                return Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    isLast
                        ? 'Today (${DateFormat('MMM d').format(points[index].day)})'
                        : DateFormat('MMM d').format(points[index].day),
                    style: TextStyle(
                      color: isLast
                          ? AppColors.primary
                          : const Color(0xFF8A98AE),
                      fontSize: 8,
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
            tooltipRoundedRadius: 6,
            getTooltipItems: (spots) => spots
                .map((spot) {
                  final point = points[spot.x.round()];
                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(point.day)} \u00B7 ${money.format(point.amount)}',
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
            color: const Color(0xFF009CDD),
            barWidth: 2.6,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) =>
                  barData.spots.isNotEmpty && spot.x == barData.spots.last.x,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3.5,
                    color: const Color(0xFF009CDD),
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF009CDD).withValues(alpha: 0.13),
                  const Color(0xFF009CDD).withValues(alpha: 0),
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
    return _DashboardSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SectionIcon(
                icon: Icons.share_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Your Website',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Direct Patient Bookings',
                      style: TextStyle(
                        color: AppColors.subtleText(context),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            url == null
                ? 'Complete your public profile to start accepting direct patient bookings.'
                : 'Share your dedicated booking website with patients to get direct appointments with 0% commission.',
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 10,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 39,
            padding: const EdgeInsets.only(left: 11, right: 2),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface(context),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    url ?? 'Your booking link is not available yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.onSurface(context),
                      fontSize: 9.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: url == null ? null : () => _copy(context, url),
                  tooltip: 'Copy link',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Color(0xFF6F7F98),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: url == null
                      ? null
                      : () => _openSite(context, ref, url),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF172238),
                    side: const BorderSide(color: Color(0xFFDCE3ED)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(
                    'View site',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: url == null ? null : () => _share(ref, url),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF00AE75),
                    disabledBackgroundColor: const Color(0xFFE4E9F0),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
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

class _DashboardSectionCard extends StatelessWidget {
  const _DashboardSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: const Color(0xFFE3E8F0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF12213B).withValues(alpha: 0.055),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, size: 17, color: color),
  );
}
