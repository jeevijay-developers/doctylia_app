import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/pagination/paged_state.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/core/widgets/whatsapp_icon.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';
import 'package:doctylia_app/features/inquiries/presentation/providers/inquiry_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Unanswered inquiries older than this are flagged "Reply overdue". There
/// is no priority data, so urgency is signalled by response time alone.
const _replyWindow = Duration(hours: 24);

bool _isOverdue(PatientInquiry inquiry, DateTime now) =>
    inquiry.status != InquiryStatus.responded &&
    now.difference(inquiry.createdAt) > _replyWindow;

/// Status tabs, each mapping 1:1 to a stored status.
enum _Tab {
  all('All', null),
  newMessage('New', InquiryStatus.newMessage),
  pending('Pending Reply', InquiryStatus.read),
  responded('Responded', InquiryStatus.responded);

  const _Tab(this.label, this.status);

  final String label;
  final InquiryStatus? status;
}

(String, Color, IconData) _statusStyle(
  BuildContext context,
  InquiryStatus status,
) => switch (status) {
  InquiryStatus.newMessage => (
    'New',
    DashboardTokens.tealDeep,
    Icons.fiber_new_rounded,
  ),
  InquiryStatus.read => (
    'Pending Reply',
    AppColors.warning,
    Icons.schedule_rounded,
  ),
  InquiryStatus.responded => (
    'Responded',
    AppColors.mutedText(context),
    Icons.done_all_rounded,
  ),
};

/// 10-digit national number for the booking form, or the raw value.
String? _bookingPhone(String? phone) {
  if (phone == null) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return digits.substring(2);
  }
  return digits.length == 10 ? digits : phone;
}

/// wa.me needs the full international number without "+".
String _whatsAppNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length == 10 ? '91$digits' : digits;
}

class InquiriesScreen extends ConsumerStatefulWidget {
  const InquiriesScreen({super.key});
  @override
  ConsumerState<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends ConsumerState<InquiriesScreen> {
  Timer? _debounce;
  _Tab _tab = _Tab.all;
  bool _overdueOnly = false;
  final _searchController = TextEditingController();

  /// Card entrances already played for the current results.
  final Set<String> _animated = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(inquiriesProvider.notifier).search(value),
    );
  }

  /// Clearing applies at once (no typing debounce).
  void _clearSearch() {
    _debounce?.cancel();
    setState(_searchController.clear);
    ref.read(inquiriesProvider.notifier).search('');
  }

  void _setTab(_Tab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _animated.clear();
    });
    ref.read(inquiriesProvider.notifier).filter(tab.status);
  }

  void _toggleOverdue() => setState(() {
    _overdueOnly = !_overdueOnly;
    _animated.clear();
  });

  void _resetFilters() {
    if (_searchController.text.isNotEmpty) _clearSearch();
    if (_overdueOnly) _toggleOverdue();
    _setTab(_Tab.all);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inquiriesProvider);
    // A new query is loading: its results should cascade in again.
    if (state.isLoading && !state.isRefreshing) _animated.clear();
    final stats = ref.watch(inquiryStatsProvider);
    return DashboardShadcnScope(
      child: AppMotion(
        enabled: true,
        child: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(inquiryStatsProvider);
                  await ref.read(inquiriesProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _StatStrip(stats: stats)),
                    SliverToBoxAdapter(
                      child: _StatusTabs(selected: _tab, onChanged: _setTab),
                    ),
                    ..._listSlivers(state),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _listSlivers(
    AsyncValue<PagedState<PatientInquiry>> state,
  ) => state.when(
    loading: () => const [SliverToBoxAdapter(child: _ListSkeleton())],
    error: (error, _) => [
      SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(
          message: error is AppFailure
              ? error.userMessage
              : 'Could not load inquiries. This feature may not be active yet.',
          onRetry: () => ref.read(inquiriesProvider.notifier).refresh(),
        ),
      ),
    ],
    data: (page) {
      final now = DateTime.now();
      final overdueCount = page.items.where((i) => _isOverdue(i, now)).length;
      final visible = _overdueOnly
          ? page.items.where((i) => _isOverdue(i, now)).toList(growable: false)
          : page.items;
      final results = SliverToBoxAdapter(
        child: _ResultsRow(
          text: _overdueOnly
              ? '${visible.length} overdue of ${page.items.length} loaded'
              : '${visible.length}${page.hasMore ? '+' : ''} '
                    '${visible.length == 1 ? 'inquiry' : 'inquiries'}',
          overdueCount: overdueCount,
          overdueOnly: _overdueOnly,
          onToggleOverdue: _toggleOverdue,
        ),
      );
      if (visible.isEmpty) {
        final overdueEmpty = _overdueOnly && page.items.isNotEmpty;
        final filtered =
            _searchController.text.trim().isNotEmpty ||
            _tab != _Tab.all ||
            _overdueOnly;
        return [
          if (page.items.isNotEmpty) results,
          SliverToBoxAdapter(
            child: _EmptyState(
              title: overdueEmpty
                  ? 'No overdue inquiries'
                  : 'No Inquiries Found',
              message: overdueEmpty
                  ? 'Every loaded inquiry was answered within '
                        '${_replyWindow.inHours} hours. You\'re all caught up.'
                  : filtered
                  ? 'No inquiry matches this search or filter.'
                  : 'Messages sent through your public website contact '
                        'form will appear here.',
              actionLabel: filtered ? 'Reset filters' : null,
              onAction: _resetFilters,
            ),
          ),
        ];
      }
      return [
        results,
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
              child: _InquiryCard(inquiry: visible[index], now: now),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: PagedListFooter(
            hasMore: page.hasMore,
            onLoadMore: () => ref.read(inquiriesProvider.notifier).loadMore(),
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
          hintText: 'Search inquiries',
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

// ── Metric glance strip ──────────────────────────────────────────────────

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  final AsyncValue<InquiryStats> stats;

  static const _placeholder = InquiryStats(
    total: 24,
    newCount: 4,
    responded: 18,
  );

  @override
  Widget build(BuildContext context) {
    final value = stats.value;
    if (value == null && stats.hasError) return const SizedBox.shrink();
    final s = value ?? _placeholder;
    final awaiting = (s.total - s.responded).clamp(0, s.total);
    final rate = s.total == 0 ? 0 : (s.responded * 100 / s.total).round();
    final strip = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatTile(
            order: 0,
            icon: Icons.inbox_rounded,
            color: AppColors.primary600,
            value: s.total,
            label: 'Total inquiries',
            caption: 'Via website',
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatTile(
            order: 1,
            icon: Icons.mark_email_unread_rounded,
            color: AppColors.warning,
            value: awaiting,
            label: 'Awaiting reply',
            caption: '${s.newCount} unopened',
            highlight: awaiting > 0,
          ),
          const SizedBox(width: AppSpacing.xs),
          _StatTile(
            order: 2,
            icon: Icons.done_all_rounded,
            color: AppColors.success,
            value: s.responded,
            label: 'Responded',
            caption: '$rate% answered',
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: value == null ? _skeleton(context, strip) : strip,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.order,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.caption,
    this.highlight = false,
  });

  final int order;
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final String caption;

  /// Tints the tile (Awaiting reply with items pending).
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AppEntrance(
      index: order,
      step: const Duration(milliseconds: 60),
      child: DashboardSurface(
        padding: const EdgeInsets.all(10),
        fillColor: highlight
            ? Color.alphaBlend(
                color.withValues(alpha: 0.07),
                AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
              )
            : null,
        borderColor: highlight ? color.withValues(alpha: 0.35) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DashboardIconTile(icon: icon, color: color, size: 28),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppCountUp(
              value: value.toDouble(),
              format: (v) => '${v.round()}',
              delay: Duration(milliseconds: 150 + 60 * order),
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.subtleText(context),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Filters ──────────────────────────────────────────────────────────────

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.onChanged});

  final _Tab selected;
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
            tabPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          ),
          children: [
            for (final tab in _Tab.values)
              shadcn.TabItem(
                child: Text(
                  tab.label,
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
              ),
          ],
        ),
      ),
    );
  }
}

/// Result count + the "Reply overdue" response-time chip filter.
class _ResultsRow extends StatelessWidget {
  const _ResultsRow({
    required this.text,
    required this.overdueCount,
    required this.overdueOnly,
    required this.onToggleOverdue,
  });

  final String text;
  final int overdueCount;
  final bool overdueOnly;
  final VoidCallback onToggleOverdue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (overdueCount > 0 || overdueOnly)
          Tooltip(
            message: 'Unanswered for more than ${_replyWindow.inHours} hours',
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onToggleOverdue,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: overdueOnly
                        ? AppColors.destructive
                        : AppColors.destructive.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.destructive.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        overdueOnly
                            ? Icons.close_rounded
                            : Icons.priority_high_rounded,
                        size: 13,
                        color: overdueOnly
                            ? Colors.white
                            : AppColors.destructive,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply overdue ($overdueCount)',
                        style: TextStyle(
                          color: overdueOnly
                              ? Colors.white
                              : AppColors.destructive,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ── 3-tier inquiry card ──────────────────────────────────────────────────

class _InquiryCard extends ConsumerWidget {
  const _InquiryCard({required this.inquiry, required this.now});

  final PatientInquiry inquiry;
  final DateTime now;

  /// Unchanged behavior: opening a new inquiry marks it read first.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    var openedInquiry = inquiry;
    if (inquiry.status == InquiryStatus.newMessage) {
      final updated = await _setInquiryStatus(
        context,
        ref,
        inquiry.id,
        InquiryStatus.read,
        successMessage: 'Marked as read.',
      );
      if (updated) {
        openedInquiry = inquiry.copyWith(status: InquiryStatus.read);
      }
    }
    if (context.mounted) _showInquiry(context, ref, openedInquiry);
  }

  void _book(BuildContext context, WidgetRef ref) => showAppointmentForm(
    context,
    ref,
    prefill: AppointmentPrefill(
      name: inquiry.name,
      phone: _bookingPhone(inquiry.phone),
      email: inquiry.email,
      complaint: inquiry.message.trim(),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = _isOverdue(inquiry, now);
    final (label, color, icon) = overdue
        ? ('Reply overdue', AppColors.destructive, null)
        : _statusStyle(context, inquiry.status);
    final isNew = inquiry.status == InquiryStatus.newMessage;
    final links = ref.read(externalLinkServiceProvider);
    final phone = inquiry.phone?.trim();
    final email = inquiry.email?.trim();
    return AppPressScale(
      builder: (onHighlight) => shadcn.Card(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(DashboardTokens.radius),
        borderColor: overdue
            ? AppColors.destructive.withValues(alpha: 0.35)
            : isNew
            ? DashboardTokens.teal.withValues(alpha: 0.4)
            : DashboardTokens.border(context),
        boxShadow: DashboardTokens.shadow(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _open(context, ref),
                onHighlightChanged: onHighlight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shadcn.Avatar(
                            initials: shadcn.Avatar.getInitials(
                              inquiry.name.trim().isEmpty
                                  ? 'Patient'
                                  : inquiry.name,
                            ),
                            size: 40,
                            backgroundColor: color.withValues(alpha: 0.14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isNew) ...[
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: DashboardTokens.teal,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(
                                        inquiry.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.onSurface(context),
                                          fontSize: 15,
                                          fontWeight: isNew
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const _ChannelBadge(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              DashboardToneBadge(
                                label: label,
                                color: color,
                                icon: icon,
                                showDot: overdue,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _age(inquiry.createdAt, now),
                                style: TextStyle(
                                  color: AppColors.subtleText(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
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
                              inquiry.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.onSurface(context),
                                fontSize: 13.5,
                                height: 1.5,
                                fontWeight: isNew
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: [
                                if (phone != null && phone.isNotEmpty)
                                  _MetaTag(
                                    icon: Icons.phone_rounded,
                                    text: phone,
                                  ),
                                if (email != null && email.isNotEmpty)
                                  _MetaTag(
                                    icon: Icons.alternate_email_rounded,
                                    text: email,
                                  ),
                                _MetaTag(
                                  icon: Icons.schedule_rounded,
                                  text: DateFormat(
                                    'd MMM, h:mm a',
                                  ).format(inquiry.createdAt),
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
              padding: const EdgeInsets.fromLTRB(6, 7, 10, 8),
              child: Row(
                children: [
                  if (phone != null && phone.isNotEmpty) ...[
                    _ContactButton(
                      tooltip: 'Call',
                      icon: const Icon(Icons.call_rounded, size: 18),
                      onPressed: () =>
                          links.open(Uri(scheme: 'tel', path: phone)),
                    ),
                    _ContactButton(
                      tooltip: 'WhatsApp',
                      icon: const WhatsAppIcon(size: 18),
                      onPressed: () => links.open(
                        Uri.parse('https://wa.me/${_whatsAppNumber(phone)}'),
                      ),
                    ),
                  ],
                  if (email != null && email.isNotEmpty)
                    _ContactButton(
                      tooltip: 'Email',
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      onPressed: () =>
                          links.open(Uri(scheme: 'mailto', path: email)),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    // Scales down rather than overflowing on narrow phones
                    // or with large accessibility text.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (inquiry.status != InquiryStatus.responded) ...[
                            shadcn.OutlineButton(
                              onPressed: () => _setInquiryStatus(
                                context,
                                ref,
                                inquiry.id,
                                InquiryStatus.responded,
                                successMessage: 'Marked as responded.',
                              ),
                              size: shadcn.ButtonSize.small,
                              leading: const Icon(
                                Icons.done_all_rounded,
                                size: 14,
                              ),
                              child: const Text('Mark Responded'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          shadcn.PrimaryButton(
                            onPressed: () => _book(context, ref),
                            size: shadcn.ButtonSize.small,
                            leading: const Icon(
                              Icons.event_available_rounded,
                              size: 14,
                            ),
                            child: const Text('Book'),
                          ),
                        ],
                      ),
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

  static String _age(DateTime value, DateTime now) {
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(value);
  }
}

class _ChannelBadge extends StatelessWidget {
  const _ChannelBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.language_rounded, size: 11, color: AppColors.primary600),
        SizedBox(width: 4),
        Flexible(
          child: Text(
            'Website form',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.primary600,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: DashboardTokens.border(context)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.mutedText(context)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
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
  );
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: shadcn.IconButton.ghost(
      onPressed: onPressed,
      density: shadcn.ButtonDensity.icon,
      icon: icon,
    ),
  );
}

// ── Loading & empty states ───────────────────────────────────────────────

/// Renders [child]'s real layout as a soft pulsing skeleton.
Widget _skeleton(BuildContext context, Widget child) {
  final isDark = AppColors.isDark(context);
  return Skeleton(
    semanticsLabel: 'Loading inquiries',
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

/// Three 1:1 placeholder cards while the list loads — no spinner.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: _skeleton(
        context,
        Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _InquiryCard(
                now: now,
                inquiry: PatientInquiry(
                  id: 'skeleton-$i',
                  name: 'Patient Name',
                  phone: '98765 43210',
                  email: 'patient@example.com',
                  message:
                      'Placeholder inquiry message that spans about two '
                      'lines of text in the card.',
                  status: InquiryStatus.read,
                  createdAt: now,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  static const _step = Duration(milliseconds: 80);

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
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
                  AppColors.primary.withValues(alpha: 0.12),
                  DashboardTokens.teal.withValues(alpha: 0.08),
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
                  Icons.forum_rounded,
                  size: 26,
                  color: AppColors.primary600,
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
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppEntrance(
            index: 4,
            step: _step,
            child: shadcn.PrimaryButton(
              onPressed: onAction,
              leading: const Icon(Icons.filter_alt_off_rounded, size: 16),
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    ),
  );
}

// ── Details sheet & status updates (behavior unchanged) ──────────────────

Future<void> _showInquiry(
  BuildContext context,
  WidgetRef ref,
  PatientInquiry inquiry,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inquiry.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            DateFormat('d MMM yyyy · h:mm a').format(inquiry.createdAt),
            style: TextStyle(color: AppColors.mutedText(context)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              if (inquiry.phone != null)
                ActionChip(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  avatar: const Icon(
                    Icons.phone_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(inquiry.phone!),
                  onPressed: () => ref
                      .read(externalLinkServiceProvider)
                      .open(Uri(scheme: 'tel', path: inquiry.phone)),
                ),
              if (inquiry.email != null)
                ActionChip(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  avatar: const Icon(
                    Icons.email_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(inquiry.email!),
                  onPressed: () => ref
                      .read(externalLinkServiceProvider)
                      .open(Uri(scheme: 'mailto', path: inquiry.email)),
                ),
            ],
          ),
          Divider(height: AppSpacing.xl, color: AppColors.border(context)),
          Text(inquiry.message),
          const SizedBox(height: AppSpacing.md),
          if (inquiry.status != InquiryStatus.responded)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () async {
                  final updated = await _setInquiryStatus(
                    context,
                    ref,
                    inquiry.id,
                    InquiryStatus.responded,
                    successMessage: 'Marked as responded.',
                  );
                  if (updated && context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Mark as Responded'),
              ),
            ),
        ],
      ),
    ),
  ),
);

Future<bool> _setInquiryStatus(
  BuildContext context,
  WidgetRef ref,
  String id,
  InquiryStatus status, {
  required String successMessage,
}) async {
  final error = await ref
      .read(inquiriesProvider.notifier)
      .setStatus(id, status);
  if (!context.mounted) return error == null;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error ?? successMessage)));
  return error == null;
}
