import 'package:doctylia_app/core/widgets/app_empty_view.dart';
import 'package:flutter/material.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      icon: Icons.cloud_off_outlined,
      title: 'Couldn’t load this',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Try again'),
      ),
    );
  }
}
