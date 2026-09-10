import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_error_view.dart';
import 'package:doctylia_app/core/widgets/app_loading_view.dart';
import 'package:doctylia_app/features/foundation/domain/entities/foundation_status.dart';
import 'package:doctylia_app/features/foundation/presentation/providers/foundation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FoundationScreen extends ConsumerWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(foundationStatusProvider);
    return Scaffold(
      body: SafeArea(
        child: status.when(
          loading: () => const AppLoadingView(label: 'Checking app foundation'),
          error: (error, _) => AppErrorView(
            message: foundationErrorMessage(error),
            onRetry: () => ref.invalidate(foundationStatusProvider),
          ),
          data: (value) => _FoundationReady(status: value),
        ),
      ),
    );
  }
}

class _FoundationReady extends StatelessWidget {
  const _FoundationReady({required this.status});
  final FoundationStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_outlined,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Doctylia',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Mobile foundation ready',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    status.layers.join(' → '),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Chip(
                    avatar: const Icon(Icons.storage_outlined, size: 18),
                    label: Text('${status.dataMode} data mode'),
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
