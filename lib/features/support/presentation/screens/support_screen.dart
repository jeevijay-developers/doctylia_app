import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/platform/app_version.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/support/domain/entities/support_faq.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';
import 'package:doctylia_app/features/support/presentation/providers/support_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

InputDecoration _fieldDecoration(String label, {String? hintText}) =>
    InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: AppColors.primary.withValues(alpha: 0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
    );

void _openNewRequest(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _NewRequestSheet(),
);

bool _isActive(SupportTicketStatus status) =>
    status == SupportTicketStatus.open ||
    status == SupportTicketStatus.inProgress;

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _faqKey = GlobalKey();
  final _faqSearch = TextEditingController();
  FaqCategory? _category;

  /// Ticket entrances already played for the current results.
  final Set<String> _animated = {};

  @override
  void dispose() {
    _faqSearch.dispose();
    super.dispose();
  }

  void _scrollToFaq() {
    final target = _faqKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetFaq() => setState(() {
    _faqSearch.clear();
    _category = null;
  });

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(supportTicketsProvider);
    if (tickets.isLoading && !tickets.isRefreshing) _animated.clear();
    final links = ref.read(externalLinkServiceProvider);
    final faqs = supportFaqs
        .where((faq) => _category == null || faq.category == _category)
        .where((faq) => faq.matches(_faqSearch.text))
        .toList(growable: false);

    return DashboardShadcnScope(
      child: AppMotion(
        enabled: true,
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: ref.read(supportTicketsProvider.notifier).refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _Header()),
                SliverToBoxAdapter(
                  child: _ContactGrid(
                    onCall: () => links.open(
                      Uri(
                        scheme: 'tel',
                        path: SupportContacts.phone.replaceAll(' ', ''),
                      ),
                    ),
                    onEmail: () => links.open(
                      Uri(scheme: 'mailto', path: SupportContacts.email),
                    ),
                    onTicket: () => _openNewRequest(context),
                    onArticles: _scrollToFaq,
                  ),
                ),
                ..._ticketSlivers(tickets),
                SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: _faqKey,
                    child: _SectionTitle(
                      title: 'Help Articles',
                      badge: '${supportFaqs.length} answers',
                      badgeColor: AppColors.primary600,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FaqFilters(
                    controller: _faqSearch,
                    category: _category,
                    onSearch: () => setState(() {}),
                    onCategory: (value) => setState(() => _category = value),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey('${_category?.name}|${_faqSearch.text}'),
                      child: faqs.isEmpty
                          ? _FaqEmpty(
                              onReset: _resetFaq,
                              onAsk: () => _openNewRequest(context),
                            )
                          : _FaqList(faqs: faqs),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StillNeedHelp(
                    version: ref.watch(appVersionProvider).value,
                    onSubmit: () => _openNewRequest(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _ticketSlivers(AsyncValue<PagedState<SupportTicket>> state) {
    final active = state.value?.items.where((t) => _isActive(t.status)).length;
    return [
      SliverToBoxAdapter(
        child: _SectionTitle(
          title: 'Recent Support Tickets',
          badge: active == null ? null : '$active open',
          badgeColor: AppColors.warning,
        ),
      ),
      ...state.when(
        loading: () => const [SliverToBoxAdapter(child: _TicketSkeleton())],
        error: (error, _) => [
          SliverToBoxAdapter(
            child: AppErrorView(
              message: error is AppFailure
                  ? error.userMessage
                  : 'Could not load your support requests.',
              onRetry: ref.read(supportTicketsProvider.notifier).refresh,
            ),
          ),
        ],
        data: (page) => page.items.isEmpty
            ? [
                SliverToBoxAdapter(
                  child: _NoTickets(onCreate: () => _openNewRequest(context)),
                ),
              ]
            : [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  sliver: SliverList.separated(
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => AppEntrance(
                      key: ValueKey(page.items[index].id),
                      index: index < 6 ? index + 4 : 0,
                      step: const Duration(milliseconds: 30),
                      offset: const Offset(0, 0.06),
                      enabled: _animated.add(page.items[index].id),
                      child: _TicketCard(ticket: page.items[index]),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: PagedListFooter(
                    hasMore: page.hasMore,
                    onLoadMore: ref
                        .read(supportTicketsProvider.notifier)
                        .loadMore,
                  ),
                ),
              ],
      ),
    ];
  }
}

// ── Header & quick contact grid ──────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: AppEntrance(
      index: 0,
      child: Row(
        children: [
          const DashboardIconTile(
            icon: Icons.support_agent_rounded,
            color: AppColors.primary600,
            size: 44,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: AppColors.onSurface(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
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
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${SupportContacts.hours} · replies in '
                        '${SupportContacts.responseTime}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContactGrid extends StatelessWidget {
  const _ContactGrid({
    required this.onCall,
    required this.onEmail,
    required this.onTicket,
    required this.onArticles,
  });

  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onTicket;
  final VoidCallback onArticles;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: b),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          row(
            _ContactTile(
              order: 1,
              icon: Icons.call_rounded,
              color: DashboardTokens.tealDeep,
              title: 'Call support',
              caption: SupportContacts.phone,
              tooltip: 'Call ${SupportContacts.phone}',
              onTap: onCall,
            ),
            _ContactTile(
              order: 2,
              icon: Icons.mail_rounded,
              color: AppColors.primary600,
              title: 'Email us',
              caption: 'Replies in ${SupportContacts.responseTime}',
              tooltip: 'Email ${SupportContacts.email}',
              onTap: onEmail,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          row(
            _ContactTile(
              order: 3,
              icon: Icons.confirmation_number_rounded,
              color: AppColors.aiPurple,
              title: 'Raise a ticket',
              caption: 'Track replies below',
              tooltip: 'Raise a support ticket',
              onTap: onTicket,
            ),
            _ContactTile(
              order: 4,
              icon: Icons.menu_book_rounded,
              color: AppColors.warning,
              title: 'Help articles',
              caption: '${supportFaqs.length} quick answers',
              tooltip: 'Browse help articles',
              onTap: onArticles,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.order,
    required this.icon,
    required this.color,
    required this.title,
    required this.caption,
    required this.tooltip,
    required this.onTap,
  });

  final int order;
  final IconData icon;
  final Color color;
  final String title;
  final String caption;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppEntrance(
    index: order,
    step: const Duration(milliseconds: 30),
    offset: const Offset(0, 0.08),
    child: Tooltip(
      message: tooltip,
      child: DashboardSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        fillColor: Color.alphaBlend(
          color.withValues(alpha: AppColors.isDark(context) ? 0.12 : 0.05),
          AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
        ),
        borderColor: color.withValues(alpha: 0.22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DashboardIconTile(icon: icon, color: color, size: 34),
                const Spacer(),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
                  color: color.withValues(alpha: 0.7),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.badgeColor,
    this.badge,
  });

  final String title;
  final String? badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: AppSpacing.xs),
          DashboardToneBadge(label: badge!, color: badgeColor),
        ],
      ],
    ),
  );
}

// ── Ticket cards ─────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final SupportTicket ticket;

  static String _ref(String id) {
    final compact = id.replaceAll('-', '').toUpperCase();
    return '#${compact.length > 8 ? compact.substring(0, 8) : compact}';
  }

  void _openThread(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TicketDetails(initialTicket: ticket),
  );

  void _followUp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NewRequestSheet(
      initialSubject: ticket.subject.startsWith('Re: ')
          ? ticket.subject
          : 'Re: ${ticket.subject}',
      initialCategory: ticket.category,
      initialPriority: ticket.priority,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final replied = ticket.reply != null;
    return AppPressScale(
      builder: (onHighlight) => shadcn.Card(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(DashboardTokens.radius),
        borderColor: DashboardTokens.border(context),
        boxShadow: DashboardTokens.shadow(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _openThread(context),
                onHighlightChanged: onHighlight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _ref(ticket.id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: AppColors.mutedText(context),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          _StatusBadge(status: ticket.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: AppColors.secondarySurface(
                            context,
                          ).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(
                            DashboardTokens.innerRadius,
                          ),
                          border: Border.all(
                            color: DashboardTokens.border(
                              context,
                            ).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.onSurface(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: [
                                if (ticket.category != null)
                                  _Tag(
                                    label: ticket.category!.label,
                                    color: AppColors.primary,
                                  ),
                                _Tag(
                                  label: '${ticket.priority.label} priority',
                                  color:
                                      ticket.priority ==
                                              SupportPriority.urgent ||
                                          ticket.priority ==
                                              SupportPriority.high
                                      ? AppColors.destructive
                                      : DashboardTokens.tealDeep,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  replied
                                      ? Icons.support_agent_rounded
                                      : Icons.hourglass_top_rounded,
                                  size: 13,
                                  color: replied
                                      ? AppColors.success
                                      : AppColors.subtleText(context),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    replied
                                        ? 'Doctylia Support replied'
                                              '${ticket.repliedAt == null ? '' : ' · ${DateFormat('d MMM, h:mm a').format(ticket.repliedAt!)}'}'
                                        : 'Awaiting reply · raised '
                                              '${DateFormat('d MMM').format(ticket.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: replied
                                          ? AppColors.success
                                          : AppColors.mutedText(context),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  shadcn.GhostButton(
                    onPressed: () => _followUp(context),
                    size: shadcn.ButtonSize.small,
                    leading: const Icon(Icons.reply_rounded, size: 15),
                    child: const Text('Follow-up'),
                  ),
                  const SizedBox(width: 6),
                  shadcn.OutlineButton(
                    onPressed: () => _openThread(context),
                    size: shadcn.ButtonSize.small,
                    trailing: const Icon(Icons.chevron_right_rounded, size: 16),
                    child: const Text('View Thread'),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final SupportTicketStatus status;
  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      SupportTicketStatus.open => (AppColors.warning, Icons.schedule_rounded),
      SupportTicketStatus.inProgress => (
        AppColors.primary600,
        Icons.autorenew_rounded,
      ),
      SupportTicketStatus.resolved => (
        AppColors.success,
        Icons.check_circle_rounded,
      ),
      SupportTicketStatus.closed => (
        AppColors.mutedText(context),
        Icons.lock_outline_rounded,
      ),
    };
    return DashboardToneBadge(label: status.label, color: color, icon: icon);
  }
}

class _NoTickets extends StatelessWidget {
  const _NoTickets({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: AppEntrance(
      index: 4,
      child: DashboardSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const DashboardIconTile(
              icon: Icons.inbox_rounded,
              color: AppColors.primary600,
              size: 38,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No requests yet',
                    style: TextStyle(
                      color: AppColors.onSurface(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your support requests and Doctylia’s replies.',
                    style: TextStyle(
                      color: AppColors.mutedText(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            shadcn.OutlineButton(
              onPressed: onCreate,
              size: shadcn.ButtonSize.small,
              child: const Text('New'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Help articles (FAQ) ──────────────────────────────────────────────────

class _FaqFilters extends StatelessWidget {
  const _FaqFilters({
    required this.controller,
    required this.category,
    required this.onSearch,
    required this.onCategory,
  });

  final TextEditingController controller;
  final FaqCategory? category;
  final VoidCallback onSearch;
  final ValueChanged<FaqCategory?> onCategory;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    final theme = shadcn.Theme.of(context);
    final card = AppColors.isDark(context)
        ? AppColors.darkCard
        : AppColors.card;
    const tabs = [null, ...FaqCategory.values];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            controller: controller,
            onChanged: (_) => onSearch(),
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search help articles',
              hintStyle: TextStyle(
                color: AppColors.subtleText(context),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.help_outline_rounded,
                size: 19,
                color: AppColors.subtleText(context),
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onSearch();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: AppColors.isDark(context)
                  ? AppColors.darkCard
                  : AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: border(DashboardTokens.border(context)),
              focusedBorder: border(AppColors.primary, 1.4),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          // The selected tab paints with `background`; lift it to the card
          // colour so it reads as a raised pill on the muted track.
          child: shadcn.Theme(
            data: theme.copyWith(
              colorScheme: () =>
                  theme.colorScheme.copyWith(background: () => card),
            ),
            child: shadcn.Tabs(
              index: tabs.indexOf(category),
              onChanged: (value) => onCategory(tabs[value]),
              theme: shadcn.TabsTheme(
                backgroundColor: AppColors.secondarySurface(context),
                borderRadius: BorderRadius.circular(
                  DashboardTokens.innerRadius,
                ),
                containerPadding: const EdgeInsets.all(4),
                tabPadding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
              ),
              children: [
                for (final tab in tabs)
                  shadcn.TabItem(
                    child: Text(
                      tab?.label ?? 'All topics',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: tab == category
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: tab == category
                            ? AppColors.primary600
                            : AppColors.mutedText(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FaqList extends StatelessWidget {
  const _FaqList({required this.faqs});

  final List<SupportFaq> faqs;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Column(
      children: [
        for (final (i, faq) in faqs.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          AppEntrance(
            index: i < 8 ? i : 0,
            step: const Duration(milliseconds: 30),
            offset: const Offset(0, 0.1),
            child: _FaqCard(faq: faq),
          ),
        ],
      ],
    ),
  );
}

/// Bordered accordion card: the chevron rotates and the answer expands
/// with a smooth height animation.
class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.faq});

  final SupportFaq faq;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    const duration = Duration(milliseconds: 240);
    return AnimatedContainer(
      duration: reduce ? Duration.zero : duration,
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(DashboardTokens.radius - 2),
        border: Border.all(
          color: _open
              ? AppColors.primary.withValues(alpha: 0.35)
              : DashboardTokens.border(context),
        ),
        boxShadow: _open ? DashboardTokens.shadow(context) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  expanded: _open,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.faq.question,
                          style: TextStyle(
                            color: AppColors.onSurface(context),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: reduce ? Duration.zero : duration,
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: _open
                              ? AppColors.primary600
                              : AppColors.subtleText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: reduce ? Duration.zero : duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _open
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            widget.faq.answer,
                            style: TextStyle(
                              color: AppColors.mutedText(context),
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqEmpty extends StatelessWidget {
  const _FaqEmpty({required this.onReset, required this.onAsk});

  final VoidCallback onReset;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    ),
    child: Column(
      children: [
        const Icon(
          Icons.manage_search_rounded,
          size: 34,
          color: AppColors.primary600,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'No matching articles',
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Try other words, or ask our team directly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedText(context), fontSize: 12.5),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            shadcn.OutlineButton(
              onPressed: onReset,
              size: shadcn.ButtonSize.small,
              child: const Text('Reset filters'),
            ),
            shadcn.PrimaryButton(
              onPressed: onAsk,
              size: shadcn.ButtonSize.small,
              child: const Text('Ask support'),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Still need help ──────────────────────────────────────────────────────

class _StillNeedHelp extends StatelessWidget {
  const _StillNeedHelp({required this.version, required this.onSubmit});

  final String? version;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.xl,
    ),
    child: DashboardShadcnScope(
      primary: DashboardTokens.tealDeep,
      child: DashboardSurface(
        padding: const EdgeInsets.all(16),
        fillColor: Color.alphaBlend(
          DashboardTokens.teal.withValues(alpha: 0.06),
          AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
        ),
        borderColor: DashboardTokens.teal.withValues(alpha: 0.25),
        child: Column(
          children: [
            const DashboardIconTile(
              icon: Icons.volunteer_activism_rounded,
              color: DashboardTokens.tealDeep,
              size: 44,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Still need help?',
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Our team replies within ${SupportContacts.responseTime} '
              '(${SupportContacts.hours}).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: shadcn.PrimaryButton(
                onPressed: onSubmit,
                leading: const Icon(Icons.add_comment_rounded, size: 16),
                alignment: Alignment.center,
                child: const Text('Submit a Ticket'),
              ),
            ),
            if (version != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                version!,
                style: TextStyle(
                  color: AppColors.subtleText(context),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ── Loading ──────────────────────────────────────────────────────────────

/// Two 1:1 placeholder ticket cards while tickets load — no spinner.
class _TicketSkeleton extends StatelessWidget {
  const _TicketSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final placeholder = SupportTicket(
      id: '00000000-skeleton',
      doctorId: 'd',
      subject: 'Placeholder support subject line',
      status: SupportTicketStatus.open,
      priority: SupportPriority.normal,
      category: SupportCategory.billing,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      submittedByName: 'Doctor',
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Skeleton(
        semanticsLabel: 'Loading support requests',
        palette: SkeletonPalette(
          surface: isDark ? AppColors.darkCard : AppColors.card,
          surfaceBorder: DashboardTokens.border(context),
          bone: isDark
              ? AppColors.darkBorder
              : AppColors.secondarySurface(context),
          innerSurface: isDark
              ? AppColors.darkSecondary
              : AppColors.secondarySurface(context).withValues(alpha: 0.55),
        ),
        child: Column(
          children: [
            _TicketCard(ticket: placeholder),
            const SizedBox(height: 10),
            _TicketCard(ticket: placeholder),
          ],
        ),
      ),
    );
  }
}

// ── Thread & request sheets (behavior unchanged) ─────────────────────────

class _TicketDetails extends ConsumerWidget {
  const _TicketDetails({required this.initialTicket});
  final SupportTicket initialTicket;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(supportTicketsProvider).value;
    final ticket = page?.items
        .where((item) => item.id == initialTicket.id)
        .firstOrNull;
    final current = ticket ?? initialTicket;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current.subject,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusBadge(status: current.status),
                _Tag(label: current.priority.label, color: AppColors.teal),
                if (current.category != null)
                  _Tag(
                    label: current.category!.label,
                    color: AppColors.primary,
                  ),
                Text(
                  DateFormat('d MMM yyyy').format(current.createdAt),
                  style: TextStyle(color: AppColors.mutedText(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _ThreadMessage(
              label: current.submittedByName.trim().isEmpty
                  ? 'YOU'
                  : current.submittedByName.toUpperCase(),
              message: current.description ?? 'No message.',
              sentAt: current.createdAt,
              fromSupport: false,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (current.reply != null)
              _ThreadMessage(
                label: 'DOCTYLIA SUPPORT',
                message: current.reply!,
                sentAt: current.repliedAt,
                fromSupport: true,
              )
            else
              Text(
                'No response yet — our team will get back to you soon.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.mutedText(context),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'The current support backend stores one support response per request. A follow-up is sent as a new request so it remains visible to the web support team.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _NewRequestSheet(
                    initialSubject: current.subject.startsWith('Re: ')
                        ? current.subject
                        : 'Re: ${current.subject}',
                    initialCategory: current.category,
                    initialPriority: current.priority,
                  ),
                ),
                icon: const Icon(Icons.reply_rounded),
                label: const Text('Send Follow-up Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadMessage extends StatelessWidget {
  const _ThreadMessage({
    required this.label,
    required this.message,
    required this.sentAt,
    required this.fromSupport,
  });

  final String label;
  final String message;
  final DateTime? sentAt;
  final bool fromSupport;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: fromSupport
          ? AppColors.primary.withValues(alpha: .07)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: fromSupport
            ? AppColors.primary.withValues(alpha: .18)
            : Theme.of(context).dividerColor,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (fromSupport) ...[
              const Icon(
                Icons.support_agent_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: fromSupport ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(message),
        if (sentAt != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormat('d MMM yyyy, h:mm a').format(sentAt!),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.subtleText(context),
            ),
          ),
        ],
      ],
    ),
  );
}

class _NewRequestSheet extends ConsumerStatefulWidget {
  const _NewRequestSheet({
    this.initialSubject,
    this.initialCategory,
    this.initialPriority,
  });
  final String? initialSubject;
  final SupportCategory? initialCategory;
  final SupportPriority? initialPriority;
  @override
  ConsumerState<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends ConsumerState<_NewRequestSheet> {
  late final TextEditingController subject;
  final description = TextEditingController();
  late SupportCategory category;
  late SupportPriority priority;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    subject = TextEditingController(text: widget.initialSubject);
    category = widget.initialCategory ?? SupportCategory.other;
    priority = widget.initialPriority ?? SupportPriority.normal;
  }

  @override
  void dispose() {
    subject.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> send() async {
    setState(() => sending = true);
    final error = await ref
        .read(supportTicketsProvider.notifier)
        .create(
          SupportTicketDraft(
            subject: subject.text,
            description: description.text,
            priority: priority,
            category: category,
          ),
        );
    if (!mounted) return;
    setState(() => sending = false);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Support request raised. Our team will get back to you soon.',
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.destructive),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
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
                    Icons.add_comment_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'New Request',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: subject,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                'Subject *',
                hintText: 'What do you need help with?',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<SupportCategory>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: _fieldDecoration('Category'),
                    items: SupportCategory.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => category = value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: DropdownButtonFormField<SupportPriority>(
                    initialValue: priority,
                    isExpanded: true,
                    decoration: _fieldDecoration('Priority'),
                    items: SupportPriority.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => priority = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: description,
              onChanged: (_) => setState(() {}),
              minLines: 5,
              maxLines: 8,
              decoration: _fieldDecoration('Message *'),
            ),
            const SizedBox(height: AppSpacing.md),
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
                onPressed:
                    sending ||
                        subject.text.trim().isEmpty ||
                        description.text.trim().isEmpty
                    ? null
                    : send,
                child: Text(sending ? 'Sending…' : 'Send'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
