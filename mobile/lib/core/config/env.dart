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

  /// Google OAuth "Web" client ID (Google Cloud Console → Credentials),
  /// also set as the Google provider's Client ID in the Supabase dashboard.
  /// Needed on Android so the ID token Google returns carries the `aud`
  /// claim Supabase expects; also passed as iOS's `serverClientId` for the
  /// same reason. Deliberately optional (`null`, not a thrown error, when
  /// unset) — "Continue with Google" (NAGARIK Theme upgrade) is additive,
  /// so an unconfigured project still has fully working Email/Password
  /// auth; see mobile/README.md's "Google sign-in" section for setup.
  static String? get googleWebClientId => _optional('GOOGLE_WEB_CLIENT_ID');

  /// Google OAuth iOS client ID (Google Cloud Console → Credentials → iOS
  /// client), passed to `GoogleSignIn(clientId: ...)`. This project has no
  /// native `ios/` folder yet (see mobile/README.md), so there's no
  /// `Info.plist` for the `google_sign_in` package to read it from
  /// automatically — it has to come from here instead. Unused on Android.
  static String? get googleIosClientId => _optional('GOOGLE_IOS_CLIENT_ID');

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

  static String? _optional(String key) {
    final value = dotenv.env[key];
    return (value == null || value.isEmpty) ? null : value;
  }
}
