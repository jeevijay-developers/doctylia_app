import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/core/widgets/paged_list_footer.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_member.dart';
import 'package:doctylia_app/features/staff/domain/entities/staff_permission.dart';
import 'package:doctylia_app/features/staff/presentation/providers/staff_providers.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

InputDecoration _fieldDecoration(String label, {String? helperText}) =>
    InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: AppColors.primary.withOpacity(0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
    );

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeatureGate(
    feature: FeatureKey.staffManagement,
    lockedChild: _LockedStaffView(),
    child: _StaffManagementContent(),
  );
}

class _StaffManagementContent extends ConsumerWidget {
  const _StaffManagementContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffMembersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Staff'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              onSubmitted: ref.read(staffMembersProvider.notifier).search,
              decoration: InputDecoration(
                hintText: 'Search staff or username',
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
          Expanded(
            child: staff.when(
              loading: () => const AppLoadingView(label: 'Loading staff'),
              error: (error, _) => AppErrorView(
                message: error is AppFailure
                    ? error.userMessage
                    : 'Could not load staff accounts.',
                onRetry: ref.read(staffMembersProvider.notifier).refresh,
              ),
              data: (page) => RefreshIndicator(
                onRefresh: ref.read(staffMembersProvider.notifier).refresh,
                child: page.items.isEmpty
                    ? ListView(
                        children: const [
                          AppEmptyView(
                            icon: Icons.manage_accounts_rounded,
                            title: 'No staff accounts yet',
                            message:
                                'Add an account and choose exactly what they can see and do.',
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
                                    .read(staffMembersProvider.notifier)
                                    .loadMore,
                              )
                            : _StaffCard(staff: page.items[index]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedStaffView extends StatelessWidget {
  const _LockedStaffView();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Staff Management is a Premium feature',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Upgrade to add clinic staff and control their permissions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText(context)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard({required this.staff});
  final StaffMember staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = staff.status == StaffStatus.active;
    final statusColor = active ? AppColors.success : AppColors.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: .12),
                foregroundColor: AppColors.primary,
                child: Text(
                  staff.staffName.isEmpty
                      ? '?'
                      : staff.staffName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.staffName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      staff.username,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: AppSpacing.lg, color: AppColors.border(context)),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${staff.permissions.length} permissions',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _openEditor(context, staff),
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _action(context, ref, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset password'),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Text(active ? 'Deactivate' : 'Activate'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              staff.lastLoginAt == null
                  ? 'Never logged in'
                  : 'Last login ${DateFormat('d MMM yyyy').format(staff.lastLoginAt!)}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.subtleText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    String? error;
    if (value == 'status') {
      error = await ref
          .read(staffMembersProvider.notifier)
          .setStatus(
            staff.id,
            staff.status == StaffStatus.active
                ? StaffStatus.inactive
                : StaffStatus.active,
          );
    } else if (value == 'reset') {
      final password = await showDialog<String>(
        context: context,
        builder: (_) => _PasswordDialog(name: staff.staffName),
      );
      if (password == null) return;
      error = await ref
          .read(staffMembersProvider.notifier)
          .resetPassword(staff.id, password);
    } else {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: const Text('Delete staff account?'),
          content: Text(
            'This permanently removes ${staff.staffName}\'s login and access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (yes != true) return;
      error = await ref.read(staffMembersProvider.notifier).delete(staff.id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Staff account updated.'),
          backgroundColor: error == null ? null : AppColors.destructive,
        ),
      );
    }
  }
}

Future<void> _openEditor(BuildContext context, [StaffMember? staff]) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StaffEditor(staff: staff),
    );

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.name});
  final String name;
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    title: Text('Reset password — ${widget.name}'),
    content: TextField(
      controller: controller,
      obscureText: true,
      onChanged: (_) => setState(() {}),
      decoration: _fieldDecoration(
        'New password',
        helperText: 'At least 8 characters',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: controller.text.length < 8
            ? null
            : () => Navigator.pop(context, controller.text),
        child: const Text('Reset'),
      ),
    ],
  );
}

class _StaffEditor extends ConsumerStatefulWidget {
  const _StaffEditor({this.staff});
  final StaffMember? staff;
  @override
  ConsumerState<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends ConsumerState<_StaffEditor> {
  late final TextEditingController name;
  late final TextEditingController username;
  final password = TextEditingController();
  final confirm = TextEditingController();
  late Set<StaffPermission> permissions;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.staff?.staffName);
    username = TextEditingController(text: widget.staff?.username);
    permissions = {...?widget.staff?.permissions};
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (widget.staff == null && password.text != confirm.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }
    setState(() => saving = true);
    final error = await ref
        .read(staffMembersProvider.notifier)
        .save(
          StaffDraft(
            id: widget.staff?.id,
            staffName: name.text,
            username: username.text,
            password: widget.staff == null ? password.text : null,
            permissions: permissions,
          ),
        );
    if (!mounted) return;
    setState(() => saving = false);
    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.destructive),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.staff == null ? 'Add Staff' : 'Edit Staff',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${permissions.length} selected',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                TextField(
                  controller: name,
                  decoration: _fieldDecoration('Staff name *'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: username,
                  decoration: _fieldDecoration('Username *'),
                ),
                if (widget.staff == null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: _fieldDecoration(
                      'Password *',
                      helperText: 'At least 8 characters',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: _fieldDecoration('Confirm password *'),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Permissions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Everything not selected stays hidden and blocked.',
                  style: TextStyle(color: AppColors.mutedText(context)),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final module in staffPermissionModules)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          module.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${module.permissions.where(permissions.contains).length}/${module.permissions.length} enabled',
                        ),
                        children: [
                          for (final permission in module.permissions)
                            CheckboxListTile(
                              activeColor: AppColors.primary,
                              value: permissions.contains(permission),
                              title: Text(permission.label),
                              onChanged: (value) => setState(() {
                                value ?? false
                                    ? permissions.add(permission)
                                    : permissions.remove(permission);
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save Staff'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
