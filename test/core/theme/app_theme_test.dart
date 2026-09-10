import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the approved Doctylia primary and typography', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(AppColors.primary.toARGB32(), 0xFF3C83FC);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Plus Jakarta Sans');
  });
}
