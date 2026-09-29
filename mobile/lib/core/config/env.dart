import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to the values loaded from `.env` by [flutter_dotenv].
///
/// Nothing else in the app should call `dotenv.env[...]` directly — going
/// through this class keeps env-var names in one place and fails fast (with
/// a clear message) if required configuration is missing.
class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get supabaseUrl => _require('SUPABASE_URL');

  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String get apiBaseUrl => _require('API_BASE_URL');

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env var "$key". Did you copy mobile/.env.example '
        'to mobile/.env and fill in real values?',
      );
    }
    return value;
  }
}
