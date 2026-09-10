import 'dart:async';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';
import 'package:doctylia_app/features/inquiries/presentation/providers/inquiry_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class InquiriesScreen extends ConsumerStatefulWidget {
  const InquiriesScreen({super.key});
  @override
  ConsumerState<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends ConsumerState<InquiriesScreen> {
  Timer? _debounce;
  InquiryStatus? _filter;
  String _searchTerm = '';
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inquiriesProvider);
    final stats = ref.watch(inquiryStatsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: stats.when(
            data: (value) => Row(
              children: [
                _Count(
                  'Total',
                  '${value.total}',
                  Icons.mail_rounded,
                  AppColors.primary,
                ),
                _Count(
                  'New',
                  '${value.newCount}',
                  Icons.mark_email_unread_rounded,
                  AppColors.warning,
                ),
                _Count(
                  'Responded',
                  '${value.responded}',
                  Icons.done_all_rounded,
                  AppColors.success,
                ),
              ],
            ),
            loading: () => const SizedBox(height: 70),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() => _searchTerm = value);
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 350),
                      () => ref.read(inquiriesProvider.notifier).search(value),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search inquiries',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.primary.withOpacity(0.045),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _FilterMenu(
                value: _filter,
                onSelected: (value) {
                  setState(() => _filter = value);
                  ref.read(inquiriesProvider.notifier).filter(value);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const AppLoadingView(label: 'Loading inquiries'),
            error: (error, _) => AppErrorView(
              message: error is AppFailure
                  ? error.userMessage
                  : 'Could not load inquiries. This feature may not be active yet.',
              onRetry: () => ref.read(inquiriesProvider.notifier).refresh(),
            ),
            data: (page) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inquiryStatsProvider);
                await ref.read(inquiriesProvider.notifier).refresh();
              },
              child: page.items.isEmpty
                  ? ListView(
                      children: [
                        AppEmptyView(
                          icon: Icons.mail_rounded,
                          title:
                              _filter != null || _searchTerm.trim().isNotEmpty
                              ? 'No matching inquiries'
                              : 'Your inquiry inbox is ready',
                          message:
                              _filter != null || _searchTerm.trim().isNotEmpty
                              ? 'Try a different search or status filter.'
                              : 'New messages sent through your public website contact form will appear here.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      itemCount: page.items.length + 1,
                      itemBuilder: (_, index) => index == page.items.length
                          ? PagedListFooter(
                              hasMore: page.hasMore,
                              onLoadMore: () => ref
                                  .read(inquiriesProvider.notifier)
                                  .loadMore(),
                            )
                          : _InquiryCard(inquiry: page.items[index]),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.value, required this.onSelected});
  final InquiryStatus? value;
  final ValueChanged<InquiryStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    return PopupMenuButton<InquiryStatus?>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('All inquiries')),
        ...InquiryStatus.values.map(
          (v) => PopupMenuItem(value: v, child: Text(v.label)),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(isActive ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(
          Icons.filter_list_rounded,
          size: 20,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.mutedText(context)),
          ),
        ],
      ),
    ),
  );
}

class _InquiryCard extends ConsumerWidget {
  const _InquiryCard({required this.inquiry});
  final PatientInquiry inquiry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (inquiry.status) {
      InquiryStatus.newMessage => AppColors.primary,
      InquiryStatus.read => AppColors.warning,
      InquiryStatus.responded => AppColors.success,
    };
    final isNew = inquiry.status == InquiryStatus.newMessage;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isNew
            ? AppColors.primary.withValues(alpha: .04)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isNew
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.border(context),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
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
          if (context.mounted) {
            _showInquiry(context, ref, openedInquiry);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    foregroundColor: color,
                    child: Text(
                      inquiry.name.trim().isEmpty
                          ? 'P'
                          : inquiry.name.trim()[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inquiry.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          DateFormat(
                            'd MMM · h:mm a',
                          ).format(inquiry.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      inquiry.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                inquiry.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.mutedText(context)),
              ),
              if (inquiry.status != InquiryStatus.responded)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                    ),
                    onPressed: () => _setInquiryStatus(
                      context,
                      ref,
                      inquiry.id,
                      InquiryStatus.responded,
                      successMessage: 'Marked as responded.',
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark responded'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                  backgroundColor: AppColors.primary.withOpacity(0.08),
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
                  backgroundColor: AppColors.primary.withOpacity(0.08),
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
