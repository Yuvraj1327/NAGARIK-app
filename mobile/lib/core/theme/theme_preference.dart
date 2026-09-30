import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three choices Settings offers (Profile & Settings upgrade). Distinct
/// from Flutter's own [ThemeMode] so this file has no obligation to match
/// that enum's member names/order if Flutter's ever changes.
enum AppThemePreference {
  system,
  light,
  dark;

  String get label => switch (this) {
        AppThemePreference.system => 'System Default',
        AppThemePreference.light => 'Light',
        AppThemePreference.dark => 'Dark',
      };

  ThemeMode get themeMode => switch (this) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };
}

const _prefsKey = 'nagarik.theme_preference';

/// Persists the chosen [AppThemePreference] to on-device storage
/// (`shared_preferences`) so it survives app restarts, and exposes it as
/// Riverpod state so `NagarikApp` (app.dart) can rebuild `MaterialApp.router`
/// immediately when Settings changes it.
///
/// Defaults to [AppThemePreference.light] — light is this app's primary,
/// fully-designed visual language (per the project brief), so a
/// freshly-installed app (or one running where `shared_preferences` can't
/// be read, e.g. a plain `flutter test`) shows that instead of following
/// the device's own theme.
class ThemePreferenceController extends StateNotifier<AppThemePreference> {
  ThemePreferenceController() : super(AppThemePreference.light) {
    _loadSavedPreference();
  }

  Future<void> _loadSavedPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored == null) return;
      state = AppThemePreference.values.firstWhere(
        (preference) => preference.name == stored,
        orElse: () => AppThemePreference.light,
      );
    } catch (_) {
      // Storage unavailable for some reason — keep the light default
      // rather than failing app startup over a cosmetic preference.
    }
  }

  Future<void> setPreference(AppThemePreference preference) async {
    state = preference;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, preference.name);
    } catch (_) {
      // The in-memory state above still applies for this session even if
      // persisting it failed; nothing further to do about a storage error
      // for a non-critical setting like this.
    }
  }
}

final themePreferenceProvider =
    StateNotifierProvider<ThemePreferenceController, AppThemePreference>(
  (ref) => ThemePreferenceController(),
);
