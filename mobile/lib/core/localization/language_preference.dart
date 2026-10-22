import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/features/onboarding/data/onboarding_service.dart';
import 'package:nagarik/features/onboarding/domain/onboarding_language.dart';

/// The app's selected display language. Reuses [OnboardingService]'s
/// existing on-device storage key, so the choice made on the onboarding
/// Language step is the same value Settings → Language reads and changes.
/// It is device-local (not tied to an account), so it survives restarts,
/// logout and login.
///
/// `NagarikApp` watches this to set `MaterialApp.locale`, which makes a
/// change apply immediately everywhere.
class LanguageController extends StateNotifier<OnboardingLanguage> {
  LanguageController(this._service) : super(OnboardingLanguage.english);

  final OnboardingService _service;

  /// Loads the saved language; awaited once at startup before the first
  /// real frame so there's no flash of English.
  Future<void> load() async {
    final saved = await _service.getLanguage();
    if (saved != null) state = saved;
  }

  Future<void> setLanguage(OnboardingLanguage language) async {
    state = language;
    await _service.setLanguage(language);
  }
}

final languageProvider = StateNotifierProvider<LanguageController, OnboardingLanguage>(
  (ref) => LanguageController(OnboardingService()),
);

/// Convenience for the current [Locale].
extension OnboardingLanguageLocale on OnboardingLanguage {
  Locale get locale => Locale(switch (this) {
        OnboardingLanguage.english => 'en',
        OnboardingLanguage.hindi => 'hi',
        OnboardingLanguage.marathi => 'mr',
      });
}
