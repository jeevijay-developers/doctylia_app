import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountRejectionScreen extends ConsumerWidget {
  const AccountRejectionScreen({
    required this.isStaffAccount,
    this.message,
    super.key,
  });

  final bool isStaffAccount;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isStaffAccount
                              ? Icons.badge_outlined
                              : Icons.person_off_outlined,
                          color: AppColors.warning,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        isStaffAccount
                            ? 'Doctor accounts only'
                            : 'Account setup incomplete',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        isStaffAccount
                            ? 'This app is for doctor accounts only. '
                                  'Staff can continue using the Doctylia web panel.'
                            : message ??
                                  'We could not link this account to a doctor profile. '
                                      'Please contact Doctylia support.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .returnToLogin(),
                        child: const Text('Return to login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
