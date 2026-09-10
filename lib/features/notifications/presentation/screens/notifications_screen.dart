import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.dashboard),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  const _NotificationHeader(),
                  SizedBox(
                    height: constraints.maxHeight > 260
                        ? constraints.maxHeight - 180
                        : 180,
                    child: const _EmptyNotifications(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
    ),
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              Icons.notifications_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your notifications',
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Updates about appointments, patients and your practice.',
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No notifications yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You are all caught up. New practice updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    ),
  );
}
