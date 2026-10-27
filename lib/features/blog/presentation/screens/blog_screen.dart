import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_profile.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/blog/domain/entities/blog_post.dart';
import 'package:doctylia_app/features/blog/presentation/providers/blog_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:share_plus/share_plus.dart';

const _blogCategories = [
  'General Health',
  'Heart Health',
  'Diabetes',
  'Skin Care',
  'Mental Health',
  'Nutrition',
  'Fitness',
  "Women's Health",
  "Children's Health",
  'Prevention',
];

InputDecoration _fieldDecoration(String label, {String? helperText}) =>
    InputDecoration(
      labelText: label,
      helperText: helperText,
      alignLabelWithHint: helperText != null,
      filled: true,
      fillColor: AppColors.primary.withValues(alpha: 0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
    );

/// Same estimate as the web (BlogPreview.tsx): 200 words a minute, min 1.
int _readMinutes(String? content) {
  final words = (content ?? '')
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
  return (words / 200).ceil().clamp(1, 999);
}

/// The web's public post page (App.tsx: /dr/:slug/blog/:postId). Only
/// published posts are reachable there.
Uri? _publicUrl(BlogPost post, String? slug) {
  final value = slug?.trim();
  if (!post.isPublished || value == null || value.isEmpty) return null;
  return Uri.https('doctylia.com', '/dr/$value/blog/${post.id}');
}

String _authorName(DoctorProfile? author) {
  final name = author?.fullName?.trim() ?? '';
  if (name.isEmpty) return 'You';
  return name.toLowerCase().startsWith('dr') ? name : 'Dr. $name';
}

/// "24 Oct" this year, "24 Oct 2025" otherwise.
String _shortDate(DateTime date) => DateFormat(
  date.year == DateTime.now().year ? 'd MMM' : 'd MMM yyyy',
).format(date);

IconData _topicIcon(String? category) => switch (category) {
  'Heart Health' => Icons.favorite_rounded,
  'Diabetes' => Icons.bloodtype_rounded,
  'Skin Care' => Icons.face_retouching_natural_rounded,
  'Mental Health' => Icons.psychology_rounded,
  'Nutrition' => Icons.restaurant_rounded,
  'Fitness' => Icons.directions_run_rounded,
  "Women's Health" => Icons.female_rounded,
  "Children's Health" => Icons.child_care_rounded,
  'Prevention' => Icons.health_and_safety_rounded,
  _ => Icons.medical_information_rounded,
};

/// Status tabs, each mapping to the stored `is_published` flag.
enum _Status {
  all('All', null),
  published('Published', true),
  drafts('Drafts', false);

  const _Status(this.label, this.isPublished);

  final String label;
  final bool? isPublished;
}

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});
  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  Timer? _debounce;
  final _searchController = TextEditingController();
  _Status _status = _Status.all;
  String? _category;

  /// True while a new search / filter loads: the current feed dims, then
  /// the new results fade in.
  bool _switching = false;

  /// Card entrances already played for the current results.
  final Set<String> _animated = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload(Future<void> Function(BlogPostsController) apply) async {
    setState(() {
      _switching = true;
      _animated.clear();
    });
    await apply(ref.read(blogPostsProvider.notifier));
    if (mounted) setState(() => _switching = false);
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _reload((posts) => posts.search(value)),
    );
  }

  /// Clearing applies at once (no typing debounce).
  void _clearSearch() {
    _debounce?.cancel();
    setState(_searchController.clear);
    _reload((posts) => posts.search(''));
  }

  void _applyFilters() => _reload(
    (posts) =>
        posts.filter(category: _category, published: _status.isPublished),
  );

  void _setStatus(_Status status) {
    if (status == _status) return;
    setState(() => _status = status);
    _applyFilters();
  }

  void _setCategory(String? category) {
    if (category == _category) return;
    setState(() => _category = category);
    _applyFilters();
  }

  void _resetFilters() {
    _debounce?.cancel();
    final hadSearch = _searchController.text.isNotEmpty;
    setState(() {
      _searchController.clear();
      _status = _Status.all;
      _category = null;
    });
    _reload((posts) async {
      if (hadSearch) await posts.search('');
      await posts.filter();
    });
  }

  bool get _filtered =>
      _searchController.text.trim().isNotEmpty ||
      _status != _Status.all ||
      _category != null;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blogPostsProvider);
    // A new query is loading: its results should cascade in again.
    if (state.isLoading && !state.isRefreshing) _animated.clear();
    final stats = ref.watch(blogStatsProvider);
    final author = ref.watch(doctorProfileProvider);
    return DashboardShadcnScope(
      child: AppMotion(
        enabled: true,
        child: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            onPressed: () => _showEditor(context, ref, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Post'),
          ),
          body: Column(
            children: [
              _SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(blogStatsProvider);
                    await ref.read(blogPostsProvider.notifier).refresh();
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _JournalHeader(stats: stats)),
                      SliverToBoxAdapter(
                        child: _StatusTabs(
                          selected: _status,
                          onChanged: _setStatus,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _TopicStrip(
                          selected: _category,
                          onChanged: _setCategory,
                        ),
                      ),
                      SliverAnimatedOpacity(
                        opacity: _switching ? 0.4 : 1,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        sliver: SliverMainAxisGroup(
                          slivers: _feedSlivers(state, author),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(
    AsyncValue<PagedState<BlogPost>> state,
    DoctorProfile? author,
  ) => state.when(
    loading: () => const [SliverToBoxAdapter(child: _FeedSkeleton())],
    error: (error, _) => [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: AppErrorView(
            message: error is AppFailure
                ? error.userMessage
                : 'Could not load blog posts.',
            onRetry: () => ref.read(blogPostsProvider.notifier).refresh(),
          ),
        ),
      ),
    ],
    data: (page) {
      if (page.items.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: _EmptyState(
              filtered: _filtered,
              onReset: _resetFilters,
              onWrite: () => _showEditor(context, ref, null),
            ),
          ),
        ];
      }
      // Spotlight: the newest live article, else the newest post.
      final hero = page.items.firstWhere(
        (post) => post.isPublished,
        orElse: () => page.items.first,
      );
      final rest = page.items
          .where((post) => post.id != hero.id)
          .toList(growable: false);
      final heroKey = 'hero-${hero.id}';
      return [
        _SectionLabel(
          text: hero.isPublished ? 'Spotlight' : 'Latest draft',
        ).sliver,
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverToBoxAdapter(
            child: AppEntrance(
              key: ValueKey(heroKey),
              index: 0,
              step: const Duration(milliseconds: 35),
              offset: const Offset(0, 0.03),
              enabled: _animated.add(heroKey),
              child: _HeroCard(post: hero, author: author),
            ),
          ),
        ),
        if (rest.isNotEmpty) ...[
          _SectionLabel(
            text: 'Latest articles',
            trailing:
                '${rest.length}${page.hasMore ? '+' : ''} '
                '${rest.length == 1 ? 'post' : 'posts'}',
          ).sliver,
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverList.separated(
              itemCount: rest.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => AppEntrance(
                key: ValueKey(rest[index].id),
                index: index < 8 ? index + 1 : 0,
                step: const Duration(milliseconds: 35),
                offset: const Offset(0, 0.07),
                enabled: _animated.add(rest[index].id),
                child: _BlogCard(post: rest[index], author: author),
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: PagedListFooter(
            hasMore: page.hasMore,
            onLoadMore: () => ref.read(blogPostsProvider.notifier).loadMore(),
          ),
        ),
        // Room for the floating "New Post" button.
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
          hintText: 'Search posts or categories',
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

// ── Header & filters ─────────────────────────────────────────────────────

class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.stats});

  final AsyncValue<BlogStats> stats;

  static const _placeholder = BlogStats(total: 12, published: 9);

  @override
  Widget build(BuildContext context) {
    final value = stats.value;
    final s = value ?? _placeholder;
    final counts = Row(
      children: [
        Expanded(
          child: Text(
            '${s.published} published · ${s.drafts} '
            '${s.drafts == 1 ? 'draft' : 'drafts'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DashboardTokens.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: DashboardTokens.teal.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${s.total} ${s.total == 1 ? 'article' : 'articles'}',
        style: const TextStyle(
          color: DashboardTokens.tealDeep,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
    final hasCounts = value != null || !stats.hasError;
    Widget loading(Widget child) =>
        value == null ? _skeleton(context, child) : child;
    return AppEntrance(
      index: 0,
      offset: const Offset(0, 0.1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Row(
          children: [
            const DashboardIconTile(
              icon: Icons.auto_stories_rounded,
              color: DashboardTokens.tealDeep,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Health Journal & Insights',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (hasCounts) ...[
                    const SizedBox(height: 2),
                    loading(counts),
                  ],
                ],
              ),
            ),
            if (hasCounts) ...[const SizedBox(width: 8), loading(pill)],
          ],
        ),
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.onChanged});

  final _Status selected;
  final ValueChanged<_Status> onChanged;

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
        0,
      ),
      // The selected tab paints with `background`; lift it to the card
      // colour so it reads as a raised pill on the muted track.
      child: shadcn.Theme(
        data: theme.copyWith(
          colorScheme: () => theme.colorScheme.copyWith(background: () => card),
        ),
        child: shadcn.Tabs(
          index: selected.index,
          onChanged: (value) => onChanged(_Status.values[value]),
          theme: shadcn.TabsTheme(
            backgroundColor: AppColors.secondarySurface(context),
            borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
            containerPadding: const EdgeInsets.all(4),
            tabPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          ),
          children: [
            for (final status in _Status.values)
              shadcn.TabItem(
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: status == selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: status == selected
                        ? AppColors.primary600
                        : AppColors.mutedText(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal topic pills: "All Topics" plus the editor's categories.
class _TopicStrip extends StatelessWidget {
  const _TopicStrip({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xxs,
    ),
    child: Row(
      children: [
        _TopicPill(
          label: 'All Topics',
          icon: Icons.apps_rounded,
          active: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final category in _blogCategories) ...[
          const SizedBox(width: 6),
          _TopicPill(
            label: category,
            icon: _topicIcon(category),
            active: selected == category,
            onTap: () => onChanged(category),
          ),
        ],
      ],
    ),
  );
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.mutedText(context);
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? DashboardTokens.tealDeep
                  : AppColors.secondarySurface(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active
                    ? DashboardTokens.tealDeep
                    : DashboardTokens.border(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.trailing});

  final String text;
  final String? trailing;

  Widget get sliver => SliverToBoxAdapter(child: this);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardTokens.eyebrow(context),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: AppColors.subtleText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

// ── Spotlight & article cards ────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.post, required this.author});

  final BlogPost post;
  final DoctorProfile? author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shareUrl = _publicUrl(post, author?.slug);
    return AppPressScale(
      builder: (onHighlight) => shadcn.Card(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        borderColor: DashboardTokens.border(context),
        boxShadow: DashboardTokens.shadow(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _showEditor(context, ref, post),
                onHighlightChanged: onHighlight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Cover(
                            url: post.featuredImageUrl,
                            category: post.category,
                            iconSize: 48,
                          ),
                          // Scrim for photos only; the placeholder is light.
                          if (post.featuredImageUrl?.trim().isNotEmpty ?? false)
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.4, 1],
                                  colors: [
                                    Color(0x00000000),
                                    Color(0x99000000),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            left: 12,
                            top: 12,
                            right: 64,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: _OverlayBadge(
                                icon: post.isPublished
                                    ? Icons.auto_awesome_rounded
                                    : Icons.edit_note_rounded,
                                label: post.isPublished
                                    ? 'Featured'
                                    : 'Latest draft',
                                solid: true,
                              ),
                            ),
                          ),
                          if (post.category != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: _OverlayBadge(
                                  icon: _topicIcon(post.category),
                                  label: post.category!,
                                ),
                              ),
                            ),
                          if (shareUrl != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: _PulseIconButton(
                                tooltip: 'Share post',
                                icon: Icons.ios_share_rounded,
                                onPressed: () => _sharePost(post, shareUrl),
                                onImage: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ReadTime(minutes: _readMinutes(post.content)),
                              const Spacer(),
                              _StatusBadge(published: post.isPublished),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onSurface(context),
                              fontSize: 19,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (post.excerpt?.trim().isNotEmpty ?? false) ...[
                            const SizedBox(height: 6),
                            Text(
                              post.excerpt!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.mutedText(context),
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _AuthorLine(
                            author: author,
                            date: post.publishedAt ?? post.createdAt,
                            avatarSize: 28,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
              child: _PostActions(post: post, prominent: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlogCard extends ConsumerWidget {
  const _BlogCard({required this.post, required this.author});

  final BlogPost post;
  final DoctorProfile? author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shareUrl = _publicUrl(post, author?.slug);
    return AppPressScale(
      builder: (onHighlight) => shadcn.Card(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(14),
        borderColor: DashboardTokens.border(context),
        boxShadow: DashboardTokens.shadow(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _showEditor(context, ref, post),
                onHighlightChanged: onHighlight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.square(
                          dimension: 92,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _Cover(
                                url: post.featuredImageUrl,
                                category: post.category,
                                iconSize: 30,
                              ),
                              Positioned(
                                left: 6,
                                bottom: 6,
                                right: 6,
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: _StatusBadge(
                                    published: post.isPublished,
                                    compact: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (post.category != null) ...[
                                  Flexible(
                                    child: DashboardToneBadge(
                                      label: post.category!,
                                      color: DashboardTokens.tealDeep,
                                      icon: _topicIcon(post.category),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                _ReadTime(minutes: _readMinutes(post.content)),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.onSurface(context),
                                fontSize: 14.5,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (post.excerpt?.trim().isNotEmpty ?? false) ...[
                              const SizedBox(height: 3),
                              Text(
                                post.excerpt!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.mutedText(context),
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 9),
                            _AuthorLine(
                              author: author,
                              date: post.publishedAt ?? post.createdAt,
                              avatarSize: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            shadcn.Divider(color: DashboardTokens.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
              child: _PostActions(post: post, shareUrl: shareUrl),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cover image, or a topic-tinted placeholder while loading / on error.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.url,
    required this.category,
    required this.iconSize,
  });

  final String? url;
  final String? category;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      key: const ValueKey('cover-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DashboardTokens.teal.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _topicIcon(category),
          size: iconSize,
          color: DashboardTokens.tealDeep.withValues(alpha: 0.65),
        ),
      ),
    );
    final value = url?.trim();
    if (value == null || value.isEmpty) return fallback;
    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      frameBuilder: (_, child, frame, synchronous) => synchronous
          ? child
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: frame == null
                  ? fallback
                  : KeyedSubtree(key: const ValueKey('cover'), child: child),
            ),
    );
  }
}

class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({
    required this.icon,
    required this.label,
    this.solid = false,
  });

  final IconData icon;
  final String label;

  /// Solid teal (the spotlight marker) vs. frosted dark (topic).
  final bool solid;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
    decoration: BoxDecoration(
      color: solid ? DashboardTokens.tealDeep : const Color(0x8C000000),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.published, this.compact = false});

  final bool published;

  /// Small solid chip for use over the thumbnail.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = published ? AppColors.success : AppColors.warning;
    final label = published ? 'Published' : 'Draft';
    if (!compact) {
      return DashboardToneBadge(label: label, color: color, showDot: true);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReadTime extends StatelessWidget {
  const _ReadTime({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.schedule_rounded,
        size: 13,
        color: AppColors.subtleText(context),
      ),
      const SizedBox(width: 3),
      Text(
        '$minutes min read',
        maxLines: 1,
        style: TextStyle(
          color: AppColors.subtleText(context),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({
    required this.author,
    required this.date,
    required this.avatarSize,
  });

  final DoctorProfile? author;
  final DateTime date;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final name = _authorName(author);
    final photo = author?.profilePhotoUrl?.trim();
    return Row(
      children: [
        shadcn.Avatar(
          initials: shadcn.Avatar.getInitials(
            name.replaceFirst(RegExp(r'^Dr\.?\s*'), ''),
          ),
          size: avatarSize,
          backgroundColor: AppColors.primary.withValues(alpha: 0.14),
          provider: photo == null || photo.isEmpty ? null : NetworkImage(photo),
        ),
        const SizedBox(width: 7),
        // The name shrinks so the (short) date always shows in full.
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '  ·  ${_shortDate(date)}',
          maxLines: 1,
          style: TextStyle(
            color: AppColors.subtleText(context),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

/// Edit · Publish/Unpublish · Share · Delete (behavior unchanged).
class _PostActions extends ConsumerWidget {
  const _PostActions({
    required this.post,
    this.shareUrl,
    this.prominent = false,
  });

  final BlogPost post;

  /// Shown as an inline share button (the spotlight shares from its image).
  final Uri? shareUrl;

  /// Solid Edit button on the spotlight card.
  final bool prominent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editIcon = const Icon(Icons.edit_outlined, size: 15);
    final toggleIcon = Icon(
      post.isPublished
          ? Icons.visibility_off_rounded
          : Icons.visibility_rounded,
      size: 15,
    );
    final toggleLabel = Text(post.isPublished ? 'Unpublish' : 'Publish');
    void edit() => _showEditor(context, ref, post);
    void toggle() => _togglePublished(context, ref, post);
    return Row(
      children: [
        Expanded(
          // Scales down rather than overflowing on narrow phones or with
          // large accessibility text.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: prominent
                  ? [
                      shadcn.PrimaryButton(
                        onPressed: edit,
                        size: shadcn.ButtonSize.small,
                        leading: editIcon,
                        child: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      shadcn.OutlineButton(
                        key: ValueKey('blog-toggle-${post.id}'),
                        onPressed: toggle,
                        size: shadcn.ButtonSize.small,
                        leading: toggleIcon,
                        child: toggleLabel,
                      ),
                    ]
                  : [
                      shadcn.GhostButton(
                        onPressed: edit,
                        size: shadcn.ButtonSize.small,
                        leading: editIcon,
                        child: const Text('Edit'),
                      ),
                      shadcn.GhostButton(
                        key: ValueKey('blog-toggle-${post.id}'),
                        onPressed: toggle,
                        size: shadcn.ButtonSize.small,
                        leading: toggleIcon,
                        child: toggleLabel,
                      ),
                    ],
            ),
          ),
        ),
        if (shareUrl != null)
          _PulseIconButton(
            tooltip: 'Share post',
            icon: Icons.ios_share_rounded,
            onPressed: () => _sharePost(post, shareUrl!),
          ),
        _PulseIconButton(
          tooltip: 'Delete post',
          icon: Icons.delete_outline_rounded,
          color: AppColors.destructive,
          onPressed: () => _confirmDelete(context, ref, post),
        ),
      ],
    );
  }
}

/// Ghost icon button with a crisp press pulse (scale 1 → 0.8 → 1).
class _PulseIconButton extends StatefulWidget {
  const _PulseIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
    this.onImage = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  /// Frosted circle for legibility over a cover image.
  final bool onImage;

  @override
  State<_PulseIconButton> createState() => _PulseIconButtonState();
}

class _PulseIconButtonState extends State<_PulseIconButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.8,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.8,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tap() {
    if (!MediaQuery.disableAnimationsOf(context)) _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.icon,
      size: 18,
      color: widget.onImage
          ? Colors.white
          : widget.color ?? AppColors.mutedText(context),
    );
    final button = widget.onImage
        ? Material(
            color: const Color(0x66000000),
            shape: const CircleBorder(
              side: BorderSide(color: Color(0x33FFFFFF)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _tap,
              child: SizedBox.square(dimension: 40, child: icon),
            ),
          )
        : shadcn.IconButton.ghost(
            onPressed: _tap,
            density: shadcn.ButtonDensity.icon,
            icon: icon,
          );
    return Tooltip(
      message: widget.tooltip,
      child: ScaleTransition(scale: _scale, child: button),
    );
  }
}

Future<void> _sharePost(BlogPost post, Uri url) async {
  await SharePlus.instance.share(
    ShareParams(text: '${post.title}\n$url', subject: post.title),
  );
}

Future<void> _togglePublished(
  BuildContext context,
  WidgetRef ref,
  BlogPost post,
) async {
  final error = await ref
      .read(blogPostsProvider.notifier)
      .togglePublished(post.id);
  if (context.mounted) {
    _message(
      context,
      error ?? (post.isPublished ? 'Post unpublished.' : 'Post published.'),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  BlogPost post,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      title: const Text('Delete this post?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (yes == true) {
    final error = await ref.read(blogPostsProvider.notifier).delete(post.id);
    if (context.mounted) {
      _message(context, error ?? 'Post deleted.');
    }
  }
}

// ── Loading & empty states ───────────────────────────────────────────────

/// Renders [child]'s real layout as a soft pulsing skeleton.
Widget _skeleton(BuildContext context, Widget child) {
  final isDark = AppColors.isDark(context);
  return Skeleton(
    semanticsLabel: 'Loading blog posts',
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

/// 1:1 placeholder spotlight + two article cards — no spinner.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    BlogPost post(int i) => BlogPost(
      id: 'skeleton-$i',
      title: 'Placeholder article title that wraps onto a second line',
      excerpt: 'A short excerpt previewing the article for patients.',
      category: 'General Health',
      isPublished: true,
      createdAt: now,
      updatedAt: now,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: _skeleton(
        context,
        Column(
          children: [
            _HeroCard(post: post(0), author: null),
            for (var i = 1; i < 3; i++) ...[
              const SizedBox(height: 12),
              _BlogCard(post: post(i), author: null),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filtered,
    required this.onReset,
    required this.onWrite,
  });

  static const _step = Duration(milliseconds: 80);

  final bool filtered;
  final VoidCallback onReset;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xxl,
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
                  DashboardTokens.teal.withValues(alpha: 0.14),
                  AppColors.primary.withValues(alpha: 0.08),
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
                  Icons.menu_book_rounded,
                  size: 26,
                  color: DashboardTokens.tealDeep,
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
            'No Articles Found',
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
            filtered
                ? 'No article matches this search, status or topic.'
                : 'Write your first patient-friendly health article. '
                      'Published posts appear on your website.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppEntrance(
          index: 4,
          step: _step,
          child: filtered
              ? shadcn.PrimaryButton(
                  onPressed: onReset,
                  leading: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  child: const Text('Reset filters'),
                )
              : shadcn.PrimaryButton(
                  onPressed: onWrite,
                  leading: const Icon(Icons.edit_note_rounded, size: 16),
                  child: const Text('Write your first post'),
                ),
        ),
      ],
    ),
  );
}

// ── Editor (behavior unchanged) ──────────────────────────────────────────

Future<void> _showEditor(
  BuildContext context,
  WidgetRef ref,
  BlogPost? post,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BlogEditorSheet(post: post),
  );
}

class _AiWriter extends StatelessWidget {
  const _AiWriter({
    required this.topic,
    required this.generating,
    required this.generate,
    this.error,
  });

  final TextEditingController topic;
  final bool generating;
  final String? error;
  final VoidCallback generate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.aiPurple.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.aiPurple.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.aiPurple.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.aiPurple,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'AI Blog Writer',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.aiPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: topic,
                enabled: !generating,
                onSubmitted: generating ? null : (_) => generate(),
                decoration: InputDecoration(
                  hintText: 'e.g. Tips for heart health',
                  filled: true,
                  fillColor: AppColors.aiPurple.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.aiPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: generating ? null : generate,
              child: Text(generating ? 'Writing...' : 'Generate'),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.destructive,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ),
              TextButton(
                onPressed: generating ? null : generate,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _LockedAiWriter extends StatelessWidget {
  const _LockedAiWriter();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.aiPurple.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.aiPurple.withValues(alpha: .2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.aiPurple.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.aiPurple,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Text(
            'AI Blog Writer is available on Pro and Premium plans. Upgrade to generate patient-friendly drafts.',
          ),
        ),
      ],
    ),
  );
}

class _BlogEditorSheet extends ConsumerStatefulWidget {
  const _BlogEditorSheet({this.post});

  final BlogPost? post;

  @override
  ConsumerState<_BlogEditorSheet> createState() => _BlogEditorSheetState();
}

class _BlogEditorSheetState extends ConsumerState<_BlogEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _excerpt;
  late final TextEditingController _content;
  final _topic = TextEditingController();
  late String _category;
  late bool _published;
  String? _coverUrl;
  bool _generating = false;
  bool _uploading = false;
  bool _saving = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.post?.title);
    _excerpt = TextEditingController(text: widget.post?.excerpt);
    _content = TextEditingController(text: widget.post?.content);
    _category = widget.post?.category ?? 'General Health';
    _published = widget.post?.isPublished ?? false;
    _coverUrl = widget.post?.featuredImageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _excerpt.dispose();
    _content.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_topic.text.trim().isEmpty) {
      setState(() => _aiError = 'Enter a topic for the article.');
      return;
    }
    setState(() {
      _generating = true;
      _aiError = null;
    });
    try {
      final draft = await ref
          .read(blogPostsProvider.notifier)
          .generate(_topic.text);
      if (!mounted) return;
      setState(() {
        _title.text = draft.title;
        _excerpt.text = draft.excerpt;
        _content.text = draft.content;
        _category = _blogCategories.contains(draft.category)
            ? draft.category
            : 'General Health';
        _topic.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = error is AppFailure
            ? error.userMessage
            : 'AI generation failed. Please check your connection and retry.';
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _uploadCover() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    final extension = file.extension?.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    setState(() => _uploading = true);
    final result = await ref
        .read(blogPostsProvider.notifier)
        .uploadCover(
          BlogImageUpload(
            fileName: file.name,
            bytes: file.bytes!,
            mimeType: mimeType,
          ),
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    result.fold(
      onSuccess: (url) {
        setState(() => _coverUrl = url);
        _message(context, 'Cover image uploaded.');
      },
      onFailure: (failure) => _message(context, failure.userMessage),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      _message(context, 'Title is required.');
      return;
    }
    setState(() => _saving = true);
    String? error;
    try {
      error = await ref
          .read(blogPostsProvider.notifier)
          .save(
            BlogPostDraft(
              id: widget.post?.id,
              title: _title.text,
              excerpt: _excerpt.text,
              content: _content.text,
              category: _category,
              featuredImageUrl: _coverUrl,
              isPublished: _published,
            ),
          );
    } catch (failure) {
      error = failure is AppFailure
          ? failure.userMessage
          : 'The post could not be saved. Please try again.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (error == null) {
      _message(
        context,
        widget.post == null ? 'Post created.' : 'Post updated.',
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.article_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.post == null ? 'New Blog Post' : 'Edit Post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FeatureGate(
                feature: FeatureKey.aiBlogWriter,
                lockedChild: const _LockedAiWriter(),
                child: _AiWriter(
                  topic: _topic,
                  generating: _generating,
                  error: _aiError,
                  generate: _generate,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _title,
                decoration: _fieldDecoration('Title *'),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_coverUrl != null && _coverUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    _coverUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 90,
                      child: Center(child: Icon(Icons.broken_image_rounded)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: _uploading ? null : _uploadCover,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Replace cover'),
                    ),
                    TextButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => setState(() => _coverUrl = null),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ] else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  onPressed: _uploading ? null : _uploadCover,
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(
                    _uploading ? 'Uploading...' : 'Upload cover image',
                  ),
                ),
              Text(
                'JPG, PNG or WebP - up to 5 MB',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedText(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _excerpt,
                maxLines: 2,
                decoration: _fieldDecoration('Excerpt'),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey(_category),
                initialValue: _category,
                decoration: _fieldDecoration('Category'),
                items: _blogCategories
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _RichContentEditor(controller: _content),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                // The tint lives on a Material so the tile's ink shows.
                child: Material(
                  color: AppColors.primary.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    activeThumbColor: AppColors.primary,
                    title: const Text('Publish now'),
                    value: _published,
                    onChanged: (value) => setState(() => _published = value),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: _saving || _uploading ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : widget.post == null
                        ? 'Create Post'
                        : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RichContentEditor extends StatelessWidget {
  const _RichContentEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Wrap(
          spacing: AppSpacing.xxs,
          children: [
            _ToolbarButton(
              tooltip: 'Heading',
              icon: Icons.title_rounded,
              onPressed: () => _insertMarkup(controller, '## ', ''),
            ),
            _ToolbarButton(
              tooltip: 'Bold',
              icon: Icons.format_bold_rounded,
              onPressed: () => _insertMarkup(controller, '**', '**'),
            ),
            _ToolbarButton(
              tooltip: 'Bulleted list',
              icon: Icons.format_list_bulleted_rounded,
              onPressed: () => _insertMarkup(controller, '- ', ''),
            ),
            _ToolbarButton(
              tooltip: 'Link',
              icon: Icons.link_rounded,
              onPressed: () => _insertMarkup(controller, '[', '](https://)'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextField(
        controller: controller,
        minLines: 7,
        maxLines: 12,
        decoration: _fieldDecoration(
          'Rich content',
          helperText: 'HTML and Markdown formatting are preserved.',
        ),
      ),
    ],
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
    ),
  );
}

void _insertMarkup(
  TextEditingController controller,
  String prefix,
  String suffix,
) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.isValid ? selection.start : text.length;
  final end = selection.isValid ? selection.end : text.length;
  final selected = text.substring(start, end);
  final replacement = '$prefix$selected$suffix';
  controller.value = TextEditingValue(
    text: text.replaceRange(start, end, replacement),
    selection: TextSelection.collapsed(
      offset: start + prefix.length + selected.length,
    ),
  );
}

void _message(BuildContext context, String value) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
