import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';
import 'package:doctylia_app/features/support/presentation/providers/support_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

InputDecoration _fieldDecoration(String label, {String? hintText}) =>
    InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: AppColors.primary.withOpacity(0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
    );

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportTicketsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const _NewRequestSheet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Request'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Your support requests and Doctylia’s replies.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: tickets.when(
              loading: () =>
                  const AppLoadingView(label: 'Loading support requests'),
              error: (error, _) => AppErrorView(
                message: error is AppFailure
                    ? error.userMessage
                    : 'Could not load your support requests.',
                onRetry: ref.read(supportTicketsProvider.notifier).refresh,
              ),
              data: (page) => RefreshIndicator(
                onRefresh: ref.read(supportTicketsProvider.notifier).refresh,
                child: page.items.isEmpty
                    ? ListView(
                        children: const [
                          AppEmptyView(
                            icon: Icons.support_agent_rounded,
                            title: 'No requests yet',
                            message:
                                'Create a request when you need help from Doctylia.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          100,
                        ),
                        itemCount: page.items.length + 1,
                        itemBuilder: (_, index) => index == page.items.length
                            ? PagedListFooter(
                                hasMore: page.hasMore,
                                onLoadMore: ref
                                    .read(supportTicketsProvider.notifier)
                                    .loadMore,
                              )
                            : _TicketCard(ticket: page.items[index]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border(context)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _TicketDetails(initialTicket: ticket),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _StatusBadge(status: ticket.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (ticket.category != null)
                  _Tag(label: ticket.category!.label, color: AppColors.primary),
                _Tag(label: ticket.priority.label, color: AppColors.teal),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  DateFormat('d MMM yyyy').format(ticket.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.subtleText(context),
                  ),
                ),
                if (ticket.reply != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.circle, size: 7, color: AppColors.success),
                  const SizedBox(width: AppSpacing.xxs),
                  const Text(
                    'Replied',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final SupportTicketStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SupportTicketStatus.open => AppColors.primary,
      SupportTicketStatus.inProgress => AppColors.warning,
      SupportTicketStatus.resolved => AppColors.success,
      SupportTicketStatus.closed => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

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
                  side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
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
                    color: AppColors.primary.withOpacity(0.1),
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
