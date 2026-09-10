import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DoctyliaLogo extends StatelessWidget {
  const DoctyliaLogo({
    this.width = 140,
    this.height = 44,
    this.fit = BoxFit.contain,
    super.key,
  });

  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark
        ? 'assets/logo/doctylia-logo-dark.png'
        : 'assets/logo/doctylia-logo.png';
    return Semantics(
      label: 'Doctylia',
      image: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Image.asset(
          asset,
          key: ValueKey(asset),
          width: width,
          height: height,
          alignment: Alignment.centerLeft,
          fit: fit,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class DoctyliaBrandMark extends StatelessWidget {
  const DoctyliaBrandMark({this.size = 64, this.showName = true, super.key});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    if (showName) {
      return DoctyliaLogo(width: size * 2.8, height: size);
    }
    return Semantics(
      label: 'Doctylia',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.24),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.health_and_safety_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}
