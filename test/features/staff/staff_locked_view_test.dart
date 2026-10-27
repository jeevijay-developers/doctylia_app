import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/features/staff/presentation/screens/staff_management_screen.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('locked Staff Management offers an upgrade to Subscription', (
    tester,
  ) async {
    String? openedTab;
    final router = GoRouter(
      initialLocation: '/staff',
      routes: [
        GoRoute(
          path: '/staff',
          builder: (_, _) => const Scaffold(body: StaffManagementScreen()),
        ),
        GoRoute(
          path: RoutePaths.settings,
          builder: (_, state) {
            openedTab = state.uri.queryParameters['tab'];
            return const Scaffold(body: Text('Settings'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // No plan includes staff management.
          featureAccessProvider.overrideWithValue(FeatureAccessSnapshot([])),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff Management is a Premium feature'), findsOneWidget);
    await tester.tap(find.text('Upgrade Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(openedTab, 'subscription');

    // Back returns to the locked Staff page.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Upgrade Plan'), findsOneWidget);
  });
}
