import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/settings/domain/entities/settings_models.dart';
import 'package:doctylia_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

Future<void> showPlanCheckout(
  BuildContext context,
  WidgetRef ref,
  PlanTier tier,
  SubscriptionDetails subscription,
) async {
  final label = tier.displayLabel;
  final price = tier == PlanTier.premium
      ? subscription.premiumPrice
      : subscription.proPrice;
  final scheduled =
      subscription.status == PlanStatus.active && subscription.planEnd != null;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subscription.status == PlanStatus.active
                  ? '${scheduled ? 'Schedule' : 'Upgrade to'} $label'
                  : 'Reactivate on $label',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '₹${price.toStringAsFixed(0)}/month · ${scheduled ? 'activates when the current plan ends' : 'activates immediately after verified payment'}',
            ),
            const SizedBox(height: AppSpacing.md),
            ..._features(tier).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Continue to Razorpay · ₹${price.toStringAsFixed(0)}',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  if (ref.read(settingsCheckoutBusyProvider)) return;
  ref.read(settingsCheckoutBusyProvider.notifier).setBusy(true);

  try {
    _message(context, 'Creating a secure checkout…');
    final order = await ref.read(settingsProvider.notifier).createOrder(tier);
    if (!context.mounted) return;
    final CheckoutVerification? verification;
    if (order.isMock) {
      final simulate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _MockRazorpayDialog(order: order),
      );
      if (simulate != true) {
        if (context.mounted) _message(context, 'Test payment cancelled.');
        return;
      }
      verification = await ref
          .read(settingsProvider.notifier)
          .simulateMockPayment(order);
    } else {
      verification = await _openRazorpay(order, label);
      if (verification == null) {
        if (context.mounted) _message(context, 'Payment was not completed.');
        return;
      }
    }
    if (!context.mounted) return;
    _message(context, 'Verifying payment…');
    final error = await ref
        .read(settingsProvider.notifier)
        .verify(order, verification);
    if (!context.mounted) return;
    _message(
      context,
      error ??
          (scheduled
              ? '$label plan scheduled successfully.'
              : 'You are now on $label.'),
      error: error != null,
    );
  } catch (error) {
    if (!context.mounted) return;
    _message(
      context,
      error is AppFailure
          ? error.userMessage
          : 'Could not complete checkout. Please try again.',
      error: true,
    );
  } finally {
    ref.read(settingsCheckoutBusyProvider.notifier).setBusy(false);
  }
}

Future<CheckoutVerification?> _openRazorpay(
  CheckoutOrder order,
  String label,
) async {
  final razorpay = Razorpay();
  final completer = Completer<CheckoutVerification?>();
  void finish(CheckoutVerification? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse value) {
    final orderId = value.orderId;
    final paymentId = value.paymentId;
    final signature = value.signature;
    if (orderId == null || paymentId == null || signature == null) {
      finish(null);
      return;
    }
    finish(
      CheckoutVerification(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      ),
    );
  });
  razorpay.on(
    Razorpay.EVENT_PAYMENT_ERROR,
    (PaymentFailureResponse _) => finish(null),
  );
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  try {
    razorpay.open({
      'key': order.keyId,
      'amount': order.amountPaise,
      'currency': order.currency,
      'order_id': order.orderId,
      'name': 'Doctylia',
      'description': 'Upgrade to $label',
      'theme': {'color': '#1e3a8a'},
      'retry': {'enabled': true},
    });
    return await completer.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () => null,
    );
  } finally {
    razorpay.clear();
  }
}

void _message(BuildContext context, String value, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? AppColors.destructive : null,
      ),
    );
}

List<String> _features(PlanTier tier) => tier == PlanTier.premium
    ? [
        'Everything in Pro',
        'Unlimited appointments',
        'Online consultation',
        'Patient records',
        'Staff roles & access',
      ]
    : [
        'Branded website',
        '100 appointments/month',
        'AI blog writer',
        'Billing & invoices',
      ];

class _MockRazorpayDialog extends StatelessWidget {
  const _MockRazorpayDialog({required this.order});
  final CheckoutOrder order;

  @override
  Widget build(BuildContext context) => AlertDialog(
    titlePadding: EdgeInsets.zero,
    title: Container(
      color: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: Colors.white),
          SizedBox(width: AppSpacing.xs),
          Text('Mock Payment Gateway', style: TextStyle(color: Colors.white)),
          Spacer(),
          Text(
            'TEST MODE',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No real money will move in this checkout.'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          ).format(order.amountRupees),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Order: ${order.orderId}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text('Payment Successful'),
      ),
    ],
  );
}
