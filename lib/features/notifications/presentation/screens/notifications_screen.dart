import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/notifications/domain/entities/app_notification.dart';
import 'package:doctylia_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Feed filters; categories map from `source_type` (see
/// [AppNotification.category]).
enum _Filter { all, unread, account, support, announcement }

extension on _Filter {
  String get label => switch (this) {
    _Filter.all => 'All',
    _Filter.unread => 'Unread',
    _Filter.account => 'Account',
    _Filter.support => 'Support',
    _Filter.announcement => 'Announcements',
  };

  bool matches(AppNotification item) => switch (this) {
    _Filter.all => true,
    _Filter.unread => !item.isRead,
    _Filter.account => item.category == NotificationCategory.account,
    _Filter.support => item.category == NotificationCategory.support,
    _Filter.announcement => item.category == NotificationCategory.announcement,
  };
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  var _filter = _Filter.all;

  NotificationsController get _controller =>
      ref.read(notificationsProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final items = state.value ?? const <AppNotification>[];

    return DashboardShadcnScope(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(RoutePaths.dashboard),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              // Flexible so large text scales ellipsize instead of
              // overflowing next to the unread badge.
              const Flexible(
                child: Text(
                  'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                DashboardToneBadge(
                  label: '$unread New',
                  color: DashboardTokens.teal,
                  showDot: true,
                ),
              ],
            ],
          ),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: DashboardTokens.border(context)),
          ),
          actions: [
            Tooltip(
              message: 'Mark all as read',
              child: shadcn.IconButton.ghost(
                onPressed: unread == 0 ? null : _markAllRead,
                icon: Icon(
                  Icons.done_all_rounded,
                  size: 20,
                  color: unread == 0
                      ? AppColors.subtleText(context)
                      : DashboardTokens.tealDeep,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: RefreshIndicator(
                onRefresh: _controller.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _FilterBar(
                        selected: _filter,
                        counts: {
                          for (final filter in _Filter.values)
                            filter: items.where(filter.matches).length,
                        },
                        onSelected: (value) => setState(() => _filter = value),
                      ),
                    ),
                    ...state.when(
                      loading: () => const [
                        SliverToBoxAdapter(child: _FeedSkeleton()),
                      ],
                      error: (error, _) => [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppErrorView(
                            message: error is AppFailure
                                ? error.userMessage
                                : 'Could not load notifications.',
                            onRetry: _controller.refresh,
                          ),
                        ),
                      ],
                      data: (all) => _feedSlivers(
                        all.where(_filter.matches).toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(List<AppNotification> items) {
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyFeed(filter: _filter),
        ),
      ];
    }
    final groups = <String, List<AppNotification>>{};
    for (final item in items) {
      groups.putIfAbsent(_groupLabel(item.createdAt), () => []).add(item);
    }
    return [
      for (final entry in groups.entries) ...[
        SliverToBoxAdapter(
          child: _SectionHeader(label: entry.key, count: entry.value.length),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = entry.value[index];
              final action = _actionFor(item);
              return _NotificationCard(
                notification: item,
                actionLabel: action?.label,
                onAction: action == null
                    ? null
                    : () => _runAction(item, action),
                onTap: () => _markRead(item),
                onMarkRead: item.isRead ? null : () => _markRead(item),
              );
            },
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
    ];
  }

  static String _groupLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return 'Earlier this week';
    return 'Earlier';
  }

  static ({String label, String route})? _actionFor(AppNotification item) =>
      switch (item.sourceType) {
        'trial_warning' || 'plan_warning' => (
          label: 'View plans',
          route: '${RoutePaths.settings}?tab=subscription',
        ),
        'ticket_reply' => (label: 'Open ticket', route: RoutePaths.support),
        _ => null,
      };

  Future<void> _runAction(
    AppNotification item,
    ({String label, String route}) action,
  ) async {
    await _markRead(item);
    if (mounted) context.go(action.route);
  }

  Future<void> _markRead(AppNotification item) async {
    if (item.isRead) return;
    final error = await _controller.markRead(item.id);
    if (error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _markAllRead() async {
    final error = await _controller.markAllRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'All notifications marked as read')),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _Filter selected;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        for (final filter in _Filter.values) ...[
          if (filter != _Filter.values.first) const SizedBox(width: 8),
          _FilterPill(
            label: filter.label,
            count: counts[filter] ?? 0,
            selected: filter == selected,
            onTap: () => onSelected(filter),
          ),
        ],
      ],
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 34,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: selected
                  ? DashboardTokens.teal.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? DashboardTokens.teal.withValues(alpha: 0.45)
                    : DashboardTokens.border(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? DashboardTokens.tealDeep
                        : AppColors.mutedText(context),
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? DashboardTokens.teal
                        : AppColors.secondarySurface(context),
                    borderRadius: radius,
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppColors.mutedText(context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md + 2,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Text(
          label.toUpperCase(),
          style: DashboardTokens.eyebrow(
            context,
          ).copyWith(fontSize: 10.5, color: AppColors.mutedText(context)),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: TextStyle(
            color: AppColors.subtleText(context),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: DashboardTokens.border(context)),
        ),
      ],
    ),
  );
}

/// Visual cue per `source_type`.
({IconData icon, Color color, String tag}) _styleFor(String sourceType) =>
    switch (sourceType) {
      'trial_warning' => (
        icon: Icons.hourglass_bottom_rounded,
        color: AppColors.warning,
        tag: 'Trial',
      ),
      'plan_warning' => (
        icon: Icons.workspace_premium_outlined,
        color: AppColors.orange,
        tag: 'Plan',
      ),
      'ticket_reply' => (
        icon: Icons.support_agent_rounded,
        color: DashboardTokens.teal,
        tag: 'Support',
      ),
      'direct_message' => (
        icon: Icons.mark_email_unread_outlined,
        color: AppColors.primary,
        tag: 'Message',
      ),
      'broadcast' => (
        icon: Icons.campaign_outlined,
        color: AppColors.aiPurple,
        tag: 'Announcement',
      ),
      _ => (
        icon: Icons.notifications_none_rounded,
        color: AppColors.textMuted,
        tag: 'Update',
      ),
    };

String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(value);
}

/// Three-tier notification card: category cue, content, inline actions.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    this.actionLabel,
    this.onAction,
    this.onMarkRead,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final style = _styleFor(notification.sourceType);
    final radius = BorderRadius.circular(DashboardTokens.radius);
    final hasActions = onAction != null || onMarkRead != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: unread
            ? DashboardTokens.teal.withValues(
                alpha: AppColors.isDark(context) ? 0.08 : 0.045,
              )
            : Colors.transparent,
        borderRadius: radius,
        border: Border.all(
          color: unread
              ? DashboardTokens.teal.withValues(alpha: 0.3)
              : DashboardTokens.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 12, 12, hasActions ? 6 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unread indicator dot.
                    SizedBox(
                      width: 10,
                      height: 40,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: unread ? 1 : 0,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: DashboardTokens.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: unread ? 1 : 0.7,
                      child: DashboardIconTile(
                        icon: style.icon,
                        color: style.color,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unread
                                        ? AppColors.onSurface(context)
                                        : AppColors.mutedText(context),
                                    fontSize: 14.5,
                                    height: 1.3,
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondarySurface(context),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _timeAgo(notification.createdAt),
                                  style: TextStyle(
                                    color: AppColors.mutedText(context),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread
                                  ? AppColors.mutedText(context)
                                  : AppColors.subtleText(context),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MicroTag(label: style.tag, color: style.color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(66, 0, 10, 10),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (onMarkRead != null)
                    shadcn.GhostButton(
                      onPressed: onMarkRead,
                      size: shadcn.ButtonSize.small,
                      leading: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.mutedText(context),
                      ),
                      child: Text(
                        'Mark read',
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (onAction != null)
                    shadcn.PrimaryButton(
                      onPressed: onAction,
                      size: shadcn.ButtonSize.small,
                      trailing: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                      ),
                      child: Text(actionLabel ?? 'Open'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MicroTag extends StatelessWidget {
  const _MicroTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.filter});

  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    final allClear = filter == _Filter.all || filter == _Filter.unread;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DashboardTokens.teal.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.isDark(context)
                        ? AppColors.darkCard
                        : AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: DashboardTokens.border(context)),
                    boxShadow: DashboardTokens.shadow(context),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 28,
                    color: DashboardTokens.tealDeep,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              allClear ? 'All caught up!' : 'Nothing in ${filter.label}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              allClear
                  ? 'No new notifications at this time.'
                  : 'Notifications of this type will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            height: 92,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface(context),
              borderRadius: BorderRadius.circular(DashboardTokens.radius),
            ),
          ),
      ],
    ),
  );
}
