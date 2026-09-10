import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/domain/entities/doctor_session.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionBlockedScreen extends ConsumerWidget {
  const SubscriptionBlockedScreen({required this.session, super.key});

  final DoctorSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelled = session.planStatus == PlanStatus.cancelled;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_clock_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    cancelled
                        ? 'Account access paused'
                        : 'Your trial has ended',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    cancelled
                        ? 'Your subscription is cancelled. Reactivate it from the Doctylia web app to continue.'
                        : 'Choose a plan from the Doctylia web app to continue managing your practice.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    child: const Text('Log out'),
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
