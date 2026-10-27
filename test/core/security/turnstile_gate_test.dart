import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/security/turnstile.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:doctylia_app/features/auth/domain/entities/account_lookup.dart';
import 'package:doctylia_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_preferences_store.dart';

/// Records the captcha token each OTP request carried.
final class _RecordingAuth implements AuthRepository {
  final tokens = <String?>[];

  @override
  Future<Result<AccountLookup?>> restoreSession() async => const Success(null);

  @override
  Future<Result<void>> sendPhoneOtp(String phone, {String? captchaToken}) =>
      RepositoryGuard.run(() {
        tokens.add(captchaToken);
        // Always refuse, so the screen stays put (no router in this test).
        throw const AuthFailure('refused');
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(AuthRepository auth, {String? siteKey}) => ProviderScope(
  overrides: [
    appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
    preferencesStoreProvider.overrideWithValue(FakePreferencesStore()),
    authRepositoryProvider.overrideWithValue(auth),
    turnstileSiteKeyProvider.overrideWithValue(siteKey),
    turnstileWebViewProvider.overrideWithValue(false),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
);

void main() {
  test('Supabase captcha_failed maps to a clear instruction', () {
    const error = AuthApiException(
      'captcha protection: request disallowed (no captcha_token found)',
      statusCode: '400',
      code: 'captcha_failed',
    );
    for (final failure in [
      SupabaseAuthErrorMapper.mapPhoneOtp(error, StackTrace.empty),
      SupabaseAuthErrorMapper.map(error, StackTrace.empty),
    ]) {
      expect(
        failure.userMessage,
        'Security check failed. Please complete the verification and try '
        'again.',
      );
    }
  });

  testWidgets('blocks Send OTP until the check passes, then sends the token '
      'once and re-arms', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);
    final auth = _RecordingAuth();
    await tester.pumpWidget(_app(auth, siteKey: 'site-key'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    // No token yet: nothing is sent, the web's message is shown.
    expect(auth.tokens, isEmpty);
    expect(
      find.text('Please complete the verification check.'),
      findsOneWidget,
    );

    // Cloudflare's callback delivers a token (same path as the WebView).
    tester.widget<TurnstileWidget>(find.byType(TurnstileWidget)).onToken('t1');
    await tester.pump();
    expect(find.text('Please complete the verification check.'), findsNothing);
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(auth.tokens, ['t1']);

    // Single-use: a second send needs a new check.
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(auth.tokens, ['t1']);
    expect(
      find.text('Please complete the verification check.'),
      findsOneWidget,
    );
  });

  testWidgets('without a sitekey (tests / mock) no check is required', (
    tester,
  ) async {
    final auth = _RecordingAuth();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();
    expect(find.byType(TurnstileWidget), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.ensureVisible(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(auth.tokens, [null]);
  });
}
