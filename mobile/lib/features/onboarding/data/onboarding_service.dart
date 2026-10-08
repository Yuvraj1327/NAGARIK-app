import 'package:shared_preferences/shared_preferences.dart';

import 'package:nagarik/features/onboarding/domain/age_group.dart';
import 'package:nagarik/features/onboarding/domain/onboarding_language.dart';

const _donePrefsKey = 'nagarik.onboarding.done';
const _languagePrefsKey = 'nagarik.onboarding.language';
const _ageGroupPrefsKey = 'nagarik.onboarding.age_group';
const _pendingPhonePrefsKey = 'nagarik.onboarding.pending_phone';

/// Local-only persistence for the first-run onboarding flow
/// (`presentation/screens/onboarding_screen.dart`) — everything here lives
/// purely on-device via `shared_preferences` (the same package
/// `ThemePreferenceController` already uses for the theme setting), never
/// sent to the backend. Reads/writes are defensively wrapped the same way
/// that controller is, since none of this should ever be able to crash
/// the onboarding flow or app startup over a storage hiccup.
///
/// Two different kinds of state live here:
/// - [hasFinishedOnboarding]/[markFinished] decide whether the flow should
///   be shown again. Set once — either from the Welcome page's "Skip" or
///   from finishing/skipping the last step — and never unset by this app.
/// - Everything else is what the person actually chose along the way.
///   [getPendingPhoneNumber] is the one value with a real destination:
///   `AuthRepository` reads it the first time a real session exists after
///   onboarding (a confirmed sign-up, a sign-in, or "Continue with
///   Google") and writes it into that account's real Supabase
///   `user_metadata`, then calls [clearPendingPhoneNumber] so it's never
///   written twice. The language and age bracket have no backend field to
///   sync to by design (see `docs/ARCHITECTURE.md`'s write-up for this
///   step) — they're saved here only so Step 7 (Preferences) can show the
///   language choice back and let the person change it.
class OnboardingService {
  Future<bool> hasFinishedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_donePrefsKey) ?? false;
    } catch (_) {
      // Storage unavailable — safer to show onboarding again than to risk
      // never showing it at all.
      return false;
    }
  }

  Future<void> markFinished() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_donePrefsKey, true);
    } catch (_) {
      // If this fails, onboarding simply shows again next launch — not
      // worth failing the "Skip"/"Finish" action itself over.
    }
  }

  Future<void> setLanguage(OnboardingLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePrefsKey, language.name);
    } catch (_) {
      // Non-critical preference — safe to drop on a storage error.
    }
  }

  Future<OnboardingLanguage?> getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_languagePrefsKey);
      if (stored == null) return null;
      for (final value in OnboardingLanguage.values) {
        if (value.name == stored) return value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setAgeGroup(AgeGroup ageGroup) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ageGroupPrefsKey, ageGroup.name);
    } catch (_) {
      // Non-critical preference — safe to drop on a storage error.
    }
  }

  /// Saved only when the phone step's Continue is tapped with a non-empty
  /// value — see [OnboardingDraft]'s doc comment for why Skip never calls
  /// this.
  Future<void> setPendingPhoneNumber(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPhonePrefsKey, phone);
    } catch (_) {
      // If this fails to save, `AuthRepository` simply has nothing to
      // sync later — not worth surfacing an error for an optional field.
    }
  }

  Future<String?> getPendingPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pendingPhonePrefsKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingPhonePrefsKey);
    } catch (_) {
      // Worst case this is read (and a no-op re-saved) again next sign-in.
    }
  }
}
