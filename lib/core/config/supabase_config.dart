import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class SupabaseConfig {
  static const _definedUrl = String.fromEnvironment('SUPABASE_URL');
  static const _definedPublishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get url =>
      _required(name: 'SUPABASE_URL', definedValue: _definedUrl);

  static String get publishableKey => _required(
    name: 'SUPABASE_ANON_KEY',
    definedValue: _definedPublishableKey,
  );

  static const passwordResetRedirectUrl = 'https://doctylia.com/reset-password';

  static String _required({
    required String name,
    required String definedValue,
  }) {
    final value = definedValue.isNotEmpty ? definedValue : dotenv.env[name];
    if (value == null || value.trim().isEmpty) {
      throw StateError('$name is missing from .env or --dart-define.');
    }
    return value.trim();
  }
}
