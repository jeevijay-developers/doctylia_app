import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/reviews/domain/entities/review.dart';
import 'package:doctylia_app/features/reviews/presentation/providers/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  Timer? _debounce;
  ReviewFilter _filter = ReviewFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(reviewsProvider);
    final stats = ref.watch(reviewStatsProvider);
    final slug = ref.watch(doctorProfileProvider)?.slug;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reviewStatsProvider);
        await ref.read(reviewsProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          stats.when(
            data: (value) => _PracticeBanner(stats: value, slug: slug),
            loading: () => const _LoadingBox(height: 102),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.sm),
          stats.when(
            data: (value) => _StatsRow(stats: value),
            loading: () => const _LoadingBox(height: 66),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Search patient or keyword...',
              hintStyle: const TextStyle(
                color: Color(0xFF9AA6B8),
                fontSize: 11,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: const Icon(Icons.filter_alt_outlined, size: 17),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          _FilterRow(
            selected: _filter,
            total: stats.asData?.value.total,
            onSelected: _setFilter,
          ),
          const SizedBox(height: 10),
          ...reviews.when(
            loading: () => const [
              SizedBox(
                height: 220,
                child: AppLoadingView(label: 'Loading reviews'),
              ),
            ],
            error: (error, _) => [
              SizedBox(
                height: 220,
                child: AppErrorView(
                  message: error is AppFailure
                      ? error.userMessage
                      : 'Could not load reviews.',
                  onRetry: () => ref.read(reviewsProvider.notifier).refresh(),
                ),
              ),
            ],
            data: (page) => [
              if (page.items.isEmpty)
                const SizedBox(
                  height: 220,
                  child: AppEmptyView(
                    icon: Icons.reviews_rounded,
                    title: 'No reviews found',
                    message:
                        'Patient feedback matching this filter will appear here.',
                  ),
                )
              else
                for (final review in page.items) _ReviewCard(review: review),
              if (_filter == ReviewFilter.all) ...[
                const SizedBox(height: 2),
                _CollectReviewsCard(slug: slug),
              ],
              PagedListFooter(
                hasMore: page.hasMore,
                onLoadMore: () => ref.read(reviewsProvider.notifier).loadMore(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(reviewsProvider.notifier).search(value),
    );
  }

  void _setFilter(ReviewFilter value) {
    setState(() => _filter = value);
    ref.read(reviewsProvider.notifier).filter(value);
  }
}

class _PracticeBanner extends StatelessWidget {
  const _PracticeBanner({required this.stats, required this.slug});

  final ReviewStats stats;
  final String? slug;

  @override
  Widget build(BuildContext context) {
    final rating = stats.total == 0
        ? '0.0'
        : stats.averageRating.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2462F0), Color(0xFF4285F4)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5FE5B2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      slug == null
                          ? 'Public Profile'
                          : 'Public Profile Verified',
                      style: const TextStyle(
                        color: Color(0xFFDCE9FF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$rating Star Practice',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Your verified rating is prominently featured',
                  style: TextStyle(color: Color(0xFFE6EEFF), fontSize: 9.5),
                ),
                const SizedBox(height: 2),
                Text(
                  slug == null
                      ? 'Complete your public profile'
                      : 'on doctylia.com/dr/$slug',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 58,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rating,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (_) => const Icon(
                      Icons.star_rounded,
                      size: 9,
                      color: Color(0xFFFFD53D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final ReviewStats stats;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _StatCard(
        label: 'Total',
        value: '${stats.total}',
        icon: Icons.chat_bubble_outline_rounded,
        color: AppColors.primary,
      ),
      _StatCard(
        label: 'Avg',
        value: stats.averageRating.toStringAsFixed(1),
        icon: Icons.star_rounded,
        color: AppColors.warning,
      ),
      _StatCard(
        label: 'Verified',
        value: '${stats.verified}',
        icon: Icons.verified_user_outlined,
        color: AppColors.success,
      ),
      _StatCard(
        label: 'Pinned',
        value: '${stats.pinned}',
        icon: Icons.bookmark_outline_rounded,
        color: AppColors.aiPurple,
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.045),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.total,
    required this.onSelected,
  });

  final ReviewFilter selected;
  final int? total;
  final ValueChanged<ReviewFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      (ReviewFilter.all, 'All'),
      (ReviewFilter.fiveStars, '5 Stars \u2605'),
      (ReviewFilter.verified, 'Verified Only'),
      (ReviewFilter.hidden, 'Hidden'),
    ];
    return SizedBox(
      height: 27,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final option = options[index];
          final active = selected == option.$1;
          return ChoiceChip(
            selected: active,
            onSelected: (_) => onSelected(option.$1),
            label: Text(
              option.$1 == ReviewFilter.all
                  ? 'All (${total ?? '—'})'
                  : option.$2,
            ),
            labelStyle: TextStyle(
              color: active ? Colors.white : AppColors.onSurface(context),
              fontSize: 8.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: Theme.of(context).cardColor,
            side: BorderSide(
              color: active ? AppColors.primary : AppColors.border(context),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            labelPadding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.review});

  final PatientReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: review.isPinned
          ? AppColors.warning.withValues(alpha: 0.035)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: review.isPinned
            ? AppColors.warning.withValues(alpha: 0.22)
            : AppColors.border(context),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow(context),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => _details(context, ref, review),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 10, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.11),
                    foregroundColor: const Color(0xFFB66B00),
                    child: Text(
                      _initial(review.patientName),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                review.patientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (review.isVerified) ...[
                              const SizedBox(width: 5),
                              const _VerifiedBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d MMM yyyy').format(review.createdAt),
                          style: TextStyle(
                            color: AppColors.subtleText(context),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActionIcon(
                    tooltip: review.isVisible ? 'Hide' : 'Show',
                    icon: review.isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: review.isVisible
                        ? AppColors.success
                        : const Color(0xFF8A98AE),
                    onPressed: () => _runMutation(
                      context,
                      ref
                          .read(reviewsProvider.notifier)
                          .toggleVisible(review.id),
                      successMessage: review.isVisible
                          ? 'Review hidden from your website.'
                          : 'Review is now visible on your website.',
                    ),
                  ),
                  const SizedBox(width: 5),
                  _ActionIcon(
                    tooltip: review.isPinned ? 'Unpin' : 'Pin',
                    icon: review.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.bookmark_outline_rounded,
                    color: review.isPinned
                        ? AppColors.aiPurple
                        : const Color(0xFF8A98AE),
                    onPressed: () => _runMutation(
                      context,
                      ref.read(reviewsProvider.notifier).togglePin(review.id),
                      successMessage: review.isPinned
                          ? 'Review unpinned.'
                          : 'Review pinned.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  for (var index = 0; index < 5; index++)
                    Icon(
                      index < review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 12,
                      color: AppColors.warning,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if ((review.reviewText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  review.reviewText!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedText(context),
                    fontSize: 9.5,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 9),
              Divider(height: 1, color: AppColors.border(context)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    review.isVisible
                        ? Icons.public_rounded
                        : Icons.public_off_rounded,
                    size: 11,
                    color: const Color(0xFF97A4B7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      review.isVisible
                          ? 'Published patient review'
                          : 'Hidden from public profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8A98AE),
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'View details  \u203A',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static String _initial(String name) {
    final clean = name.trim();
    return clean.isEmpty ? 'P' : clean[0].toUpperCase();
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_rounded, size: 9, color: AppColors.success),
        SizedBox(width: 2),
        Text(
          'Verified',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    ),
  );
}

class _CollectReviewsCard extends StatelessWidget {
  const _CollectReviewsCard({required this.slug});

  final String? slug;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: const Color(0xFFD7E1F0),
        style: BorderStyle.solid,
      ),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collect More Patient Reviews',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'Send an automated SMS link after checkout',
                style: TextStyle(color: Color(0xFF77859B), fontSize: 8.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: slug == null ? null : () => _shareReviewLink(slug!),
          style: FilledButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.share_rounded, size: 13),
          label: const Text(
            'Share Link',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  static Future<void> _shareReviewLink(String slug) => SharePlus.instance.share(
    ShareParams(
      subject: 'Review your Doctylia visit',
      text: 'Share your experience: https://doctylia.com/dr/$slug#reviews',
    ),
  );
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );
}

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
              Row(
                children: [
                  for (var index = 0; index < 5; index++)
                    Icon(
                      index < review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.warning,
                    ),
                ],
              ),
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
                          ? const _MutationProgress()
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
                          ? const _MutationProgress()
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

class _MutationProgress extends StatelessWidget {
  const _MutationProgress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
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
