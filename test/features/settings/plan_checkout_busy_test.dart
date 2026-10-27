import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:doctylia_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_preferences_store.dart';

void main() {
  testWidgets('only the plan being purchased shows Processing…', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
          preferencesStoreProvider.overrideWithValue(FakePreferencesStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SettingsScreen(initialTab: 'subscription'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Processing…'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    // A Premium checkout is in progress (as set by showPlanCheckout).
    container.read(settingsCheckoutBusyProvider.notifier).setBusy(true);
    container.read(settingsCheckoutTierProvider.notifier).set(PlanTier.premium);
    await tester.pump();

    expect(find.text('Processing…'), findsOneWidget);
    final premiumCard = find.ancestor(
      of: find.text('Processing…'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: premiumCard, matching: find.text('Premium')),
      findsOneWidget,
    );
    // Every checkout button stays locked meanwhile.
    for (final button in tester.widgetList<FilledButton>(
      find.descendant(
        of: find.byType(Card),
        matching: find.byType(FilledButton),
      ),
    )) {
      expect(button.onPressed, isNull);
    }

    container.read(settingsCheckoutBusyProvider.notifier).setBusy(false);
    container.read(settingsCheckoutTierProvider.notifier).set(null);
    await tester.pump();
    expect(find.text('Processing…'), findsNothing);
  });
}
