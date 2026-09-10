import 'dart:async';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppointmentCapBanner extends StatelessWidget {
  const AppointmentCapBanner({
    required this.used,
    required this.cap,
    super.key,
  });
  final int used;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final ratio = cap == 0 ? 0.0 : (used / cap).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You have used $used/$cap appointments this month.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.warning.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class TrialPlanBanner extends StatefulWidget {
  const TrialPlanBanner({required this.status, super.key});

  final TrialStatusSnapshot status;

  @override
  State<TrialPlanBanner> createState() => _TrialPlanBannerState();
}

class _TrialPlanBannerState extends State<TrialPlanBanner> {
  bool _trialEndingDismissed = false;

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    if (status.isTrialEndingSoon && !_trialEndingDismissed) {
      return _BannerSurface(
        color: AppColors.destructive,
        icon: Icons.warning_amber_rounded,
        message:
            'Your free trial ends in less than 24 hours — upgrade now to '
            'avoid losing access to your dashboard.',
        onDismiss: () => setState(() => _trialEndingDismissed = true),
      );
    }
    if (status.isExpired && status.accessLevel == TrialAccessLevel.grace) {
      final hours =
          status.graceEndsAt?.difference(DateTime.now()).inHours.clamp(0, 48) ??
          0;
      return _BannerSurface(
        color: AppColors.warning,
        icon: Icons.hourglass_bottom_rounded,
        message:
            'Your trial has ended. You have about $hours hours of grace '
            'access remaining before the dashboard is locked.',
      );
    }
    if (status.isCancelled) {
      return const _BannerSurface(
        color: AppColors.destructive,
        icon: Icons.block_rounded,
        message:
            'Your subscription is cancelled. Reactivate a plan to keep '
            'using the dashboard.',
      );
    }
    return const SizedBox.shrink();
  }
}

class _BannerSurface extends StatelessWidget {
  const _BannerSurface({
    required this.color,
    required this.icon,
    required this.message,
    this.onDismiss,
  });

  final Color color;
  final IconData icon;
  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ),
        if (onDismiss != null)
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
      ],
    ),
  );
}

class GrowthTipCard extends StatefulWidget {
  const GrowthTipCard({super.key});

  @override
  State<GrowthTipCard> createState() => _GrowthTipCardState();
}

class _GrowthTipCardState extends State<GrowthTipCard> {
  static const _tips = [
    _GrowthTip(
      'Add your services to get more bookings',
      Icons.medical_services_outlined,
      RoutePaths.myWebsite,
    ),
    _GrowthTip(
      'Write a blog post to boost your SEO ranking',
      Icons.article_outlined,
      RoutePaths.blog,
    ),
    _GrowthTip(
      'Upload clinic photos to build patient trust',
      Icons.visibility_outlined,
      RoutePaths.myWebsite,
    ),
    _GrowthTip(
      'Share your website link on WhatsApp groups',
      Icons.send_outlined,
      null,
    ),
    _GrowthTip(
      'Add your qualifications to increase credibility',
      Icons.auto_awesome_outlined,
      RoutePaths.settings,
    ),
  ];

  Timer? _timer;
  var _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tips[_tipIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(_tipIndex),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.spark.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.spark.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warning.withValues(alpha: 0.16),
              ),
              child: Icon(tip.icon, size: 19, color: AppColors.warning),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Growth tip',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            if (tip.path != null)
              TextButton(
                onPressed: () => context.go(tip.path!),
                child: const Text('Do it'),
              ),
          ],
        ),
      ),
    );
  }
}

class _GrowthTip {
  const _GrowthTip(this.message, this.icon, this.path);

  final String message;
  final IconData icon;
  final String? path;
}
