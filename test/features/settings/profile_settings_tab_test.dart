import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/core/theme/theme_mode_provider.dart';
import 'package:doctylia_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../support/fake_preferences_store.dart';

final class _RecordingLinks implements ExternalLinkService {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

Widget _app(ExternalLinkService links) => ProviderScope(
  overrides: [
    appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
    preferencesStoreProvider.overrideWithValue(FakePreferencesStore()),
    externalLinkServiceProvider.overrideWithValue(links),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: SettingsScreen()),
  ),
);

Future<void> _pump(WidgetTester tester, ExternalLinkService links) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(links));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _fullName => find.widgetWithText(TextFormField, 'Full Name');

void main() {
  testWidgets('editors start collapsed and expand / collapse on tap', (
    tester,
  ) async {
    await _pump(tester, _RecordingLinks());
    expect(find.text('CLINICAL PRACTICE & ACCOUNT'), findsOneWidget);
    expect(_fullName.hitTestable(), findsNothing);

    await _tap(tester, find.text('Your Details'));
    expect(_fullName.hitTestable(), findsOneWidget);

    await _tap(tester, find.text('Your Details'));
    expect(_fullName.hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save reopens the details editor', (tester) async {
    await _pump(tester, _RecordingLinks());
    await _tap(tester, find.text('Your Details'));
    await tester.enterText(_fullName, '');
    await _tap(tester, find.text('Your Details'));
    expect(_fullName.hitTestable(), findsNothing);

    await _tap(tester, find.text('Save Profile & Clinic Settings'));
    await tester.ensureVisible(_fullName);
    await tester.pumpAndSettle();
    expect(_fullName.hitTestable(), findsOneWidget);
    expect(find.text('Profile saved.'), findsNothing);
  });

  testWidgets('dark mode switch updates the theme preference', (tester) async {
    await _pump(tester, _RecordingLinks());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    await _tap(tester, find.byType(shadcn.Switch));
    expect(container.read(themeModeProvider), ThemeMode.dark);
    await _tap(tester, find.byType(shadcn.Switch));
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('legal rows open the web pages', (tester) async {
    final links = _RecordingLinks();
    await _pump(tester, links);
    await _tap(tester, find.text('Privacy Policy'));
    await _tap(tester, find.text('Terms of Service'));
    await _tap(tester, find.text('Refund Policy'));
    expect(links.opened.map((uri) => uri.path), [
      '/privacy',
      '/terms',
      '/refund-policy',
    ]);
  });

  testWidgets('Log Out asks for confirmation', (tester) async {
    await _pump(tester, _RecordingLinks());
    await _tap(tester, find.text('Log Out'));
    expect(find.text('Log out of Doctylia?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of Doctylia?'), findsNothing);
  });
}
