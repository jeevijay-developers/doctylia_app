import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:doctylia_app/features/settings/presentation/widgets/profile_settings_tab.dart';
import 'package:doctylia_app/features/settings/presentation/widgets/subscription_settings_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({this.initialTab = 'profile', super.key});
  final String initialTab;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final initialIndex = switch (initialTab) {
      'subscription' => 1,
      'account' => 2,
      _ => 0,
    };
    return settings.when(
      loading: () => const AppLoadingView(label: 'Loading settings'),
      error: (error, _) => AppErrorView(
        message: error is AppFailure
            ? error.userMessage
            : 'Could not load settings.',
        onRetry: () => ref.read(settingsProvider.notifier).refresh(),
      ),
      data: (snapshot) => DefaultTabController(
        initialIndex: initialIndex,
        length: 3,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: _SettingsTabBar(),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ProfileSettingsTab(snapshot: snapshot),
                  SubscriptionSettingsTab(
                    subscription: snapshot.subscription,
                    paymentMode: snapshot.paymentMode,
                  ),
                  _AccountTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-style segmented tab switcher — matches the same treatment used on
/// the billing and medical-record screens, for a consistent feel app-wide.
class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(11),
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.mutedText(context),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(
            height: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Profile'),
                ],
              ),
            ),
          ),
          Tab(
            height: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Subscription'),
                ],
              ),
            ),
          ),
          Tab(
            height: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Icon(Icons.shield_rounded, size: 15),
                  SizedBox(width: 6),
                  Text('Account'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  Future<void> _requestDeletion(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: const Text('Request permanent account deletion?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your profile, patients, appointments, staff, billing records, and public site may be permanently removed after support verifies the request. This cannot be undone.',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Type DELETE to continue.'),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  labelText: 'DELETE',
                  filled: true,
                  fillColor: AppColors.destructive.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Account'),
            ),
            FilledButton(
              onPressed: controller.text == 'DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text('Continue to Support'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'For account safety, support must verify and complete deletion.',
        ),
      ),
    );
    context.go('/app/support');
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.destructive.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.destructive.withValues(alpha: 0.14),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.destructive,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Danger Zone',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.destructive,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Account deletion is permanent and requires support '
              'verification, matching the web flow.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  side: BorderSide(
                    color: AppColors.destructive.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => _requestDeletion(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete Account'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
