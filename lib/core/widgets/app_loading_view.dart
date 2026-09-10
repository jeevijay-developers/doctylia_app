import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({this.label = 'Loading', super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
