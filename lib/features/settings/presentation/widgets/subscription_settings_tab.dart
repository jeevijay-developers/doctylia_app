import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:doctylia_app/features/settings/presentation/widgets/mock_razorpay_checkout.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SubscriptionSettingsTab extends ConsumerWidget {
  const SubscriptionSettingsTab({
    required this.subscription,
    required this.paymentMode,
    super.key,
  });
  final SubscriptionDetails subscription;
  final PaymentMode paymentMode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = subscription.status.name;
    final end = subscription.planEnd;
    final days = end?.difference(DateTime.now()).inDays.clamp(0, 999);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (paymentMode == PaymentMode.mock) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Badge(label: Text('TEST MODE')),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Current Subscription',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Badge(
                      backgroundColor: AppColors.primary50,
                      label: Text(
                        '${status.toUpperCase()} · ${subscription.tier.displayLabel}',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (subscription.status == PlanStatus.active)
                  Text(
                    'Active until ${DateFormat('d MMM yyyy').format(end ?? DateTime.now().add(const Duration(days: 30)))} · $days days remaining',
                  ),
                if (subscription.status == PlanStatus.trial)
                  Text(
                    '${subscription.trialEnd?.difference(DateTime.now()).inDays.clamp(0, 7) ?? 7} days remaining in your free trial',
                  ),
                if (subscription.status == PlanStatus.expired ||
                    subscription.status == PlanStatus.cancelled)
                  const Text(
                    'Your subscription is inactive.',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                if (subscription.tier != PlanTier.premium) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${subscription.appointmentsUsed}/${subscription.appointmentsCap} appointments used this month',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: subscription.appointmentsCap == 0
                        ? 0
                        : subscription.appointmentsUsed /
                              subscription.appointmentsCap,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (subscription.pendingPlan case final pending?) ...[
          const SizedBox(height: AppSpacing.md),
          _PendingPlanCard(pending: pending),
        ],
        const SizedBox(height: AppSpacing.md),
        _PlanCard(
          tier: PlanTier.pro,
          price: subscription.proPrice,
          current:
              subscription.tier == PlanTier.pro &&
              subscription.status == PlanStatus.active,
          subscription: subscription,
        ),
        const SizedBox(height: AppSpacing.md),
        _PlanCard(
          tier: PlanTier.premium,
          price: subscription.premiumPrice,
          current:
              subscription.tier == PlanTier.premium &&
              subscription.status == PlanStatus.active,
          subscription: subscription,
        ),
      ],
    );
  }
}

class _PendingPlanCard extends ConsumerWidget {
  const _PendingPlanCard({required this.pending});
  final PendingPlan pending;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(settingsCheckoutBusyProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_repeat_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Upcoming Scheduled Plan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Badge(label: Text(pending.targetTier.displayLabel)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${pending.targetTier.displayLabel} activates on ${DateFormat('d MMM yyyy').format(pending.activationDate)}.',
            ),
            Text('Advance payment: ₹${pending.amount.toStringAsFixed(0)}'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel scheduled plan?'),
                          content: const Text(
                            'The payment will be marked for refund.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Keep plan'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Cancel plan'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref
                            .read(settingsCheckoutBusyProvider.notifier)
                            .setBusy(true);
                        final String? error;
                        try {
                          error = await ref
                              .read(settingsProvider.notifier)
                              .cancelScheduled(pending.id);
                        } finally {
                          ref
                              .read(settingsCheckoutBusyProvider.notifier)
                              .setBusy(false);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error ?? 'Scheduled plan cancelled.',
                              ),
                              backgroundColor: error == null
                                  ? null
                                  : AppColors.destructive,
                            ),
                          );
                        }
                      }
                    },
              child: Text(busy ? 'Cancelling…' : 'Cancel Scheduled Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.tier,
    required this.price,
    required this.current,
    required this.subscription,
  });
  final PlanTier tier;
  final double price;
  final bool current;
  final SubscriptionDetails subscription;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkoutBusy = ref.watch(settingsCheckoutBusyProvider);
    final features = tier == PlanTier.premium
        ? [
            'Everything in Pro',
            'Unlimited appointments',
            'Online consultation',
            'Patient records and reminders',
            'Staff roles & access',
          ]
        : [
            'Branded website and booking',
            'Up to 100 appointments/month',
            'Basic analytics',
            'AI blog writer',
            'Billing & invoices',
          ];
    final button = current
        ? 'Renew / Schedule'
        : subscription.status == PlanStatus.active
        ? (tier == PlanTier.premium ? 'Upgrade to Premium' : 'Switch to Pro')
        : 'Reactivate';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: current ? AppColors.primary : Theme.of(context).dividerColor,
          width: current ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.displayLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        tier == PlanTier.premium
                            ? 'For growing practices that need everything'
                            : 'Perfect for solo doctors going digital',
                      ),
                    ],
                  ),
                ),
                if (current)
                  const Badge(
                    backgroundColor: AppColors.primary,
                    label: Text(
                      'CURRENT',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '₹${price.toStringAsFixed(0)}/month',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: checkoutBusy
                    ? null
                    : () => showPlanCheckout(context, ref, tier, subscription),
                child: Text(checkoutBusy ? 'Processing…' : button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
