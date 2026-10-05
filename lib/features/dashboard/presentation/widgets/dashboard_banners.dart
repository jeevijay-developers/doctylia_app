import 'dart:async';

import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

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
    return DashboardShadcnScope(
      child: _BannerShell(
        color: AppColors.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DashboardIconTile(
                  icon: Icons.speed_rounded,
                  color: AppColors.warning,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'You have used $used/$cap appointments this month.',
                    style: TextStyle(
                      color: AppColors.onSurface(context),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                DashboardToneBadge(
                  label: '${(ratio * 100).round()}%',
                  color: const Color(0xFFB96700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            shadcn.LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: AppColors.warning,
              backgroundColor: AppColors.warning.withValues(alpha: 0.16),
              showSparks: false,
            ),
          ],
        ),
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
  Widget build(BuildContext context) => DashboardShadcnScope(
    child: _BannerShell(
      color: color,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        onDismiss == null ? AppSpacing.sm : AppSpacing.xxs,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardIconTile(icon: icon, color: color, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (onDismiss != null)
            Semantics(
              button: true,
              label: 'Dismiss',
              child: shadcn.IconButton.ghost(
                onPressed: onDismiss,
                size: shadcn.ButtonSize.small,
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.mutedText(context),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Soft tinted gradient container shared by the dashboard banners.
class _BannerShell extends StatelessWidget {
  const _BannerShell({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    super.key,
  });

  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.13), color.withValues(alpha: 0.04)],
      ),
      borderRadius: BorderRadius.circular(DashboardTokens.radius),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: child,
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
    return DashboardShadcnScope(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _BannerShell(
          key: ValueKey(_tipIndex),
          color: DashboardTokens.teal,
          child: Row(
            children: [
              DashboardIconTile(
                icon: tip.icon,
                color: DashboardTokens.tealDeep,
                size: 38,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GROWTH TIP',
                      style: DashboardTokens.eyebrow(
                        context,
                      ).copyWith(color: DashboardTokens.tealDeep),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tip.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (tip.path != null) ...[
                const SizedBox(width: AppSpacing.xs),
                shadcn.OutlineButton(
                  onPressed: () => context.go(tip.path!),
                  size: shadcn.ButtonSize.small,
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 14),
                  child: const Text('Do it'),
                ),
              ],
            ],
          ),
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
