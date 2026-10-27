import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';
import 'package:doctylia_app/features/reviews/presentation/providers/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:share_plus/share_plus.dart';

/// Star/amber accent used for ratings throughout the screen.
const _starColor = Color(0xFFF59E0B);

/// Filter tabs. All but [critical] map 1:1 to the server-side
/// [ReviewFilter]; [critical] (1–2★) loads everything and narrows the loaded
/// reviews on the device.
enum _Tab {
  all('All Reviews', ReviewFilter.all),
  fiveStars('5 Stars', ReviewFilter.fiveStars),
  critical('Critical', ReviewFilter.all),
  verified('Verified Patients', ReviewFilter.verified),
  hidden('Hidden', ReviewFilter.hidden);

  const _Tab(this.label, this.serverFilter);

  final String label;
  final ReviewFilter serverFilter;
}

bool _isCritical(PatientReview review) => review.rating <= 2;

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  Timer? _debounce;
  _Tab _tab = _Tab.all;
  final _searchController = TextEditingController();

  /// Card entrances already played for the current results.
  final Set<String> _animated = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(reviewsProvider.notifier).search(value),
    );
  }

  /// Clearing applies at once (no typing debounce).
  void _clearSearch() {
    _debounce?.cancel();
    setState(_searchController.clear);
    ref.read(reviewsProvider.notifier).search('');
  }

  void _setTab(_Tab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _animated.clear();
    });
    ref.read(reviewsProvider.notifier).filter(tab.serverFilter);
  }

  void _resetFilters() {
    if (_searchController.text.isNotEmpty) _clearSearch();
    _setTab(_Tab.all);
  }

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(reviewsProvider);
    // A new query is loading: its results should cascade in again.
    if (reviews.isLoading && !reviews.isRefreshing) _animated.clear();
    final stats = ref.watch(reviewStatsProvider);
    final slug = ref.watch(doctorProfileProvider)?.slug;

    return DashboardShadcnScope(
      child: AppMotion(
        enabled: true,
        child: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              onChanged: _search,
              onClear: _clearSearch,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(reviewStatsProvider);
                  await ref.read(reviewsProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _RatingSummary(stats: stats, slug: slug),
                    ),
                    SliverToBoxAdapter(
                      child: _FilterTabs(
                        selected: _tab,
                        total: stats.value?.total,
                        onChanged: _setTab,
                      ),
                    ),
                    ..._reviewSlivers(reviews, slug),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _reviewSlivers(
    AsyncValue<PagedState<PatientReview>> state,
    String? slug,
  ) => state.when(
    loading: () => const [SliverToBoxAdapter(child: _ListSkeleton())],
    error: (error, _) => [
      SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(
          message: error is AppFailure
              ? error.userMessage
              : 'Could not load reviews.',
          onRetry: () => ref.read(reviewsProvider.notifier).refresh(),
        ),
      ),
    ],
    data: (page) {
      final visible = _tab == _Tab.critical
          ? page.items.where(_isCritical).toList(growable: false)
          : page.items;
      final collect = _tab == _Tab.all
          ? [
              SliverToBoxAdapter(
                child: AppEntrance(
                  index: visible.length.clamp(0, 8),
                  step: const Duration(milliseconds: 35),
                  child: _CollectReviewsCard(slug: slug),
                ),
              ),
            ]
          : const <Widget>[];
      if (visible.isEmpty) {
        final narrowedOnly = _tab == _Tab.critical && page.items.isNotEmpty;
        final filtered =
            _searchController.text.trim().isNotEmpty || _tab != _Tab.all;
        return [
          SliverToBoxAdapter(
            child: _EmptyState(
              title: narrowedOnly ? 'No critical reviews' : 'No Reviews Found',
              message: narrowedOnly
                  ? (page.hasMore
                        ? 'None of the loaded reviews are 1–2★. Load more, '
                              'or view all.'
                        : 'No 1–2★ reviews — nothing needs attention.')
                  : filtered
                  ? 'No patient feedback matches this search or filter.'
                  : 'Share your review link to start collecting feedback.',
              actionLabel: narrowedOnly
                  ? 'Show all'
                  : filtered
                  ? 'Reset filters'
                  : null,
              onAction: _resetFilters,
              secondaryLabel: narrowedOnly && page.hasMore ? 'Load more' : null,
              onSecondary: () => ref.read(reviewsProvider.notifier).loadMore(),
            ),
          ),
          ...collect,
        ];
      }
      return [
        SliverToBoxAdapter(
          child: _ResultsRow(
            text: _tab == _Tab.critical
                ? '${visible.length} critical of ${page.items.length} loaded'
                : '${visible.length}${page.hasMore ? '+' : ''} '
                      '${visible.length == 1 ? 'review' : 'reviews'}',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => AppEntrance(
              key: ValueKey(visible[index].id),
              index: index < 8 ? index : 0,
              step: const Duration(milliseconds: 35),
              offset: const Offset(0, 0.06),
              enabled: _animated.add(visible[index].id),
              child: _ReviewCard(review: visible[index]),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        ...collect,
        SliverToBoxAdapter(
          child: PagedListFooter(
            hasMore: page.hasMore,
            onLoadMore: () => ref.read(reviewsProvider.notifier).loadMore(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ];
    },
  );
}

// ── Search ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: DashboardTokens.border(context)),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search patient or keyword...',
          hintStyle: TextStyle(
            color: AppColors.subtleText(context),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: AppColors.subtleText(context),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: AppColors.secondarySurface(context).withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: border(DashboardTokens.border(context)),
          focusedBorder: border(AppColors.primary, 1.4),
        ),
      ),
    );
  }
}

// ── Rating overview & breakdown ──────────────────────────────────────────

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.stats, required this.slug});

  final AsyncValue<ReviewStats> stats;
  final String? slug;

  static const _placeholder = ReviewStats(
    total: 48,
    averageRating: 4.6,
    verified: 40,
    pinned: 3,
    starCounts: [1, 1, 3, 9, 34],
  );

  @override
  Widget build(BuildContext context) {
    final value = stats.value;
    if (value == null && stats.hasError) return const SizedBox.shrink();
    final card = AppEntrance(
      index: 0,
      child: _SummaryCard(stats: value ?? _placeholder, slug: slug),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: value == null ? _skeleton(context, card) : card,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.slug});

  final ReviewStats stats;
  final String? slug;

  @override
  Widget build(BuildContext context) {
    final total = stats.total;
    final average = total == 0 ? 0.0 : stats.averageRating;
    int share(int count) => total == 0 ? 0 : (count * 100 / total).round();
    return DashboardSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: slug == null
                      ? AppColors.subtleText(context)
                      : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  slug == null
                      ? 'Complete your public profile to show reviews'
                      : 'Shown on doctylia.com/dr/$slug',
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
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 118,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            AppCountUp(
                              value: average,
                              format: (v) => v.toStringAsFixed(1),
                              delay: const Duration(milliseconds: 120),
                              style: TextStyle(
                                color: AppColors.onSurface(context),
                                fontSize: 38,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              ' / 5.0',
                              style: TextStyle(
                                color: AppColors.subtleText(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StarRow(rating: average, size: 17),
                      const SizedBox(height: 6),
                      Text(
                        total == 0
                            ? 'No reviews yet'
                            : 'Based on $total patient '
                                  '${total == 1 ? 'review' : 'reviews'}',
                        maxLines: 2,
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 24,
                  thickness: 1,
                  color: DashboardTokens.border(context),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var stars = 5; stars >= 1; stars--) ...[
                        if (stars < 5) const SizedBox(height: 6),
                        _DistributionBar(
                          stars: stars,
                          count: stats.countFor(stars),
                          total: total,
                          order: 5 - stars,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetricChip(
                icon: Icons.verified_user_rounded,
                label: '${share(stats.verified)}% verified',
                color: AppColors.success,
              ),
              _MetricChip(
                icon: Icons.star_rounded,
                label: '${share(stats.countFor(5))}% five-star',
                color: _starColor,
              ),
              _MetricChip(
                icon: Icons.push_pin_rounded,
                label: '${stats.pinned} pinned',
                color: AppColors.aiPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One "5★ ▓▓▓▓░ 71%" row; fills from 0 after the card lands.
class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.stars,
    required this.count,
    required this.total,
    required this.order,
  });

  final int stars;
  final int count;
  final int total;
  final int order;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    final motion = AppMotion.of(context);
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$stars',
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Icons.star_rounded, size: 11, color: _starColor),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 7,
            child: motion
                ? _DelayedFill(
                    target: fraction,
                    delay: Duration(milliseconds: 200 + 60 * order),
                    builder: (value) => _bar(context, value),
                  )
                : _bar(context, fraction),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            '${(fraction * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  // shadcn_flutter 0.0.55: Progress forwards `color` via the indicator's
  // `theme:`, which LinearProgressIndicator ignores — so the color was lost.
  // Use the indicator directly, where `color` is honored.
  Widget _bar(BuildContext context, double value) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: shadcn.LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: 7,
      disableAnimation: true,
      color: stars >= 4
          ? _starColor
          : stars == 3
          ? AppColors.warning.withValues(alpha: 0.7)
          : AppColors.destructive.withValues(alpha: 0.75),
      backgroundColor: AppColors.secondarySurface(context),
    ),
  );
}

/// Animates 0 → [target] once, after [delay]; later target changes ease
/// from the current value. The timer is cancelled on dispose.
class _DelayedFill extends StatefulWidget {
  const _DelayedFill({
    required this.target,
    required this.delay,
    required this.builder,
  });

  final double target;
  final Duration delay;
  final Widget Function(double value) builder;

  @override
  State<_DelayedFill> createState() => _DelayedFillState();
}

class _DelayedFillState extends State<_DelayedFill> {
  bool _started = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () => setState(() => _started = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: _started ? widget.target : 0),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (context, value, _) => widget.builder(value),
  );
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.isDark(context)
          ? color.withValues(alpha: 0.16)
          : Color.alphaBlend(color.withValues(alpha: 0.08), AppColors.card),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Five stars, filled to [rating] with half-star precision.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          rating >= i
              ? Icons.star_rounded
              : rating >= i - 0.5
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: _starColor,
        ),
    ],
  );
}

// ── Filters ──────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.total,
    required this.onChanged,
  });

  final _Tab selected;
  final int? total;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = shadcn.Theme.of(context);
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      // The selected tab paints with `background`; lift it to the card
      // colour so it reads as a raised pill on the muted track.
      child: shadcn.Theme(
        data: theme.copyWith(
          colorScheme: () => theme.colorScheme.copyWith(background: () => card),
        ),
        child: shadcn.Tabs(
          index: selected.index,
          onChanged: (value) => onChanged(_Tab.values[value]),
          theme: shadcn.TabsTheme(
            backgroundColor: AppColors.secondarySurface(context),
            borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
            containerPadding: const EdgeInsets.all(4),
            tabPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          ),
          children: [
            for (final tab in _Tab.values)
              shadcn.TabItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tab == _Tab.critical) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      tab == _Tab.all && total != null
                          ? '${tab.label} ($total)'
                          : tab.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: tab == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: tab == selected
                            ? AppColors.primary600
                            : AppColors.mutedText(context),
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

class _ResultsRow extends StatelessWidget {
  const _ResultsRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.mutedText(context),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ── 3-tier review card ───────────────────────────────────────────────────

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({required this.review});

  final PatientReview review;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _busy = false;

  Future<void> _mutate(Future<String?> operation, String successMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _runMutation(context, operation, successMessage: successMessage);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final text = review.reviewText?.trim() ?? '';
    final notifier = ref.read(reviewsProvider.notifier);
    return AppPressScale(
      builder: (onHighlight) => shadcn.Card(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(DashboardTokens.radius),
        borderColor: review.isPinned
            ? AppColors.aiPurple.withValues(alpha: 0.35)
            : DashboardTokens.border(context),
        boxShadow: DashboardTokens.shadow(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _details(context, ref, review),
                onHighlightChanged: onHighlight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(context, review),
                      const SizedBox(height: 11),
                      _body(context, review, text),
                    ],
                  ),
                ),
              ),
            ),
            shadcn.Divider(color: DashboardTokens.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          _ToggleChip(
                            icon: review.isVisible
                                ? Icons.public_rounded
                                : Icons.public_off_rounded,
                            label: review.isVisible ? 'On website' : 'Hidden',
                            tooltip: review.isVisible
                                ? 'Hide from your website'
                                : 'Show on your website',
                            active: review.isVisible,
                            color: AppColors.success,
                            onPressed: _busy
                                ? null
                                : () => _mutate(
                                    notifier.toggleVisible(review.id),
                                    review.isVisible
                                        ? 'Review hidden from your website.'
                                        : 'Review is now visible on your website.',
                                  ),
                          ),
                          const SizedBox(width: 6),
                          _ToggleChip(
                            icon: review.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            label: review.isPinned ? 'Pinned' : 'Pin to top',
                            tooltip: review.isPinned
                                ? 'Unpin review'
                                : 'Pin review',
                            active: review.isPinned,
                            color: AppColors.aiPurple,
                            onPressed: _busy
                                ? null
                                : () => _mutate(
                                    notifier.togglePin(review.id),
                                    review.isPinned
                                        ? 'Review unpinned.'
                                        : 'Review pinned.',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  shadcn.GhostButton(
                    onPressed: () => _details(context, ref, review),
                    size: shadcn.ButtonSize.small,
                    trailing: const Icon(Icons.chevron_right_rounded, size: 16),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, PatientReview review) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      shadcn.Avatar(
        initials: shadcn.Avatar.getInitials(
          review.patientName.trim().isEmpty ? 'Patient' : review.patientName,
        ),
        size: 40,
        backgroundColor: _starColor.withValues(alpha: 0.14),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review.patientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (review.isVerified) const _VerifiedBadge(),
                Text(
                  _relativeTime(review.createdAt),
                  style: TextStyle(
                    color: AppColors.subtleText(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DashboardToneBadge(
            label: review.rating.toStringAsFixed(1),
            color: _isCritical(review) ? AppColors.destructive : _starColor,
            icon: Icons.star_rounded,
          ),
          if (review.isPinned) ...[
            const SizedBox(height: 5),
            const Icon(
              Icons.push_pin_rounded,
              size: 14,
              color: AppColors.aiPurple,
            ),
          ],
        ],
      ),
    ],
  );

  Widget _body(BuildContext context, PatientReview review, String text) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: AppColors.secondarySurface(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
          border: Border.all(
            color: DashboardTokens.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StarRow(rating: review.rating.toDouble(), size: 14),
                const SizedBox(width: 8),
                const Spacer(),
                if (!review.isVisible)
                  Flexible(
                    flex: 100,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.public_off_rounded,
                          size: 12,
                          color: AppColors.subtleText(context),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Hidden from website',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.subtleText(context),
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
            const SizedBox(height: 7),
            Text(
              text.isEmpty ? 'Rating only — no written review.' : text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text.isEmpty
                    ? AppColors.subtleText(context)
                    : AppColors.onSurface(context),
                fontStyle: text.isEmpty ? FontStyle.italic : null,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ),
      );

  static String _relativeTime(DateTime value) {
    final days = DateUtils.dateOnly(
      DateTime.now(),
    ).difference(DateUtils.dateOnly(value)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final weeks = days ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    if (days < 365) {
      final months = days ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
    return DateFormat('d MMM yyyy').format(value);
  }
}

/// Compact tinted toggle used for the visibility and pin actions.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.active,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tint = active ? color : AppColors.mutedText(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.09)
                  : AppColors.secondarySurface(context),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.3)
                    : DashboardTokens.border(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: tint),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: tint,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_rounded, size: 11, color: AppColors.success),
        SizedBox(width: 3),
        Flexible(
          child: Text(
            'Verified Patient',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.success,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CollectReviewsCard extends StatelessWidget {
  const _CollectReviewsCard({required this.slug});

  final String? slug;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      0,
    ),
    child: DashboardSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const DashboardIconTile(
            icon: Icons.rate_review_rounded,
            color: _starColor,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collect More Patient Reviews',
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Share your review link with patients after a visit',
                  style: TextStyle(
                    color: AppColors.mutedText(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          shadcn.PrimaryButton(
            onPressed: slug == null ? null : () => _shareReviewLink(slug!),
            size: shadcn.ButtonSize.small,
            leading: const Icon(Icons.share_rounded, size: 14),
            child: const Text('Share Link'),
          ),
        ],
      ),
    ),
  );

  static Future<void> _shareReviewLink(String slug) => SharePlus.instance.share(
    ShareParams(
      subject: 'Review your Doctylia visit',
      text: 'Share your experience: https://doctylia.com/dr/$slug#reviews',
    ),
  );
}

// ── Loading & empty states ───────────────────────────────────────────────

/// Renders [child]'s real layout as a soft pulsing skeleton.
Widget _skeleton(BuildContext context, Widget child) {
  final isDark = AppColors.isDark(context);
  return Skeleton(
    semanticsLabel: 'Loading reviews',
    palette: SkeletonPalette(
      surface: isDark ? AppColors.darkCard : AppColors.card,
      surfaceBorder: DashboardTokens.border(context),
      bone: isDark ? AppColors.darkBorder : AppColors.secondarySurface(context),
      innerSurface: isDark
          ? AppColors.darkSecondary
          : AppColors.secondarySurface(context).withValues(alpha: 0.55),
    ),
    child: child,
  );
}

/// Three 1:1 placeholder review cards while the list loads — no spinner.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: _skeleton(
      context,
      Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _ReviewCard(
              review: PatientReview(
                id: 'skeleton-$i',
                patientName: 'Patient Name',
                rating: 5,
                isPinned: false,
                isVerified: true,
                isVisible: true,
                createdAt: DateTime(2026),
                reviewText:
                    'Placeholder review text that spans a couple of lines '
                    'to match a typical patient comment.',
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  static const _step = Duration(milliseconds: 80);

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.lg,
    ),
    child: Column(
      children: [
        AppEntrance(
          index: 0,
          offset: Offset.zero,
          scale: 0.4,
          curve: Curves.elasticOut,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _starColor.withValues(alpha: 0.16),
                  AppColors.primary.withValues(alpha: 0.07),
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
                child: const Icon(
                  Icons.reviews_rounded,
                  size: 26,
                  color: _starColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppEntrance(
          index: 2,
          step: _step,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AppEntrance(
          index: 3,
          step: _step,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        if (actionLabel != null || secondaryLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppEntrance(
            index: 4,
            step: _step,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (actionLabel != null)
                  shadcn.PrimaryButton(
                    onPressed: onAction,
                    leading: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    child: Text(actionLabel!),
                  ),
                if (secondaryLabel != null)
                  shadcn.OutlineButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

// ── Details sheet (behavior unchanged) ───────────────────────────────────

Future<void> _details(
  BuildContext context,
  WidgetRef ref,
  PatientReview review,
) {
  var isVisible = review.isVisible;
  var isPinned = review.isPinned;
  var updatingVisibility = false;
  var updatingPin = false;
  String? statusMessage;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                    foregroundColor: AppColors.warning,
                    child: Text(
                      review.patientName.trim().isEmpty
                          ? 'P'
                          : review.patientName.trim()[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.patientName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          DateFormat('d MMM yyyy').format(review.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF7B899D),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (review.isVerified) const _VerifiedBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _StarRow(rating: review.rating.toDouble(), size: 24),
              const SizedBox(height: AppSpacing.md),
              Text(review.reviewText ?? 'No written review — rating only.'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: updatingVisibility
                          ? null
                          : () async {
                              setSheetState(() => updatingVisibility = true);
                              final wasVisible = isVisible;
                              final error = await ref
                                  .read(reviewsProvider.notifier)
                                  .toggleVisible(review.id);
                              if (!context.mounted) return;
                              setSheetState(() {
                                updatingVisibility = false;
                                if (error == null) isVisible = !wasVisible;
                                statusMessage =
                                    error ??
                                    (wasVisible
                                        ? 'Review hidden from your website.'
                                        : 'Review is now visible on your website.');
                              });
                            },
                      icon: updatingVisibility
                          ? const _Pending()
                          : Icon(
                              isVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                      label: Text(isVisible ? 'Hide' : 'Show'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: updatingPin
                          ? null
                          : () async {
                              setSheetState(() => updatingPin = true);
                              final wasPinned = isPinned;
                              final error = await ref
                                  .read(reviewsProvider.notifier)
                                  .togglePin(review.id);
                              if (!context.mounted) return;
                              setSheetState(() {
                                updatingPin = false;
                                if (error == null) isPinned = !wasPinned;
                                statusMessage =
                                    error ??
                                    (wasPinned
                                        ? 'Review unpinned.'
                                        : 'Review pinned.');
                              });
                            },
                      icon: updatingPin
                          ? const _Pending()
                          : Icon(
                              isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                            ),
                      label: Text(isPinned ? 'Unpin' : 'Pin'),
                    ),
                  ),
                ],
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// In-flight marker for sheet buttons (no spinner).
class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.hourglass_top_rounded, size: 18);
}

Future<void> _runMutation(
  BuildContext context,
  Future<String?> operation, {
  required String successMessage,
}) async {
  final error = await operation;
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error ?? successMessage)));
}
