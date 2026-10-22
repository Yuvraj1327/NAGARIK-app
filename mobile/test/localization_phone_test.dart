import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nagarik/core/localization/language_preference.dart';
import 'package:nagarik/features/onboarding/data/onboarding_service.dart';
import 'package:nagarik/features/onboarding/domain/onboarding_language.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';
import 'package:nagarik/l10n/app_localizations.dart';

void main() {
  test('UserProfile reads phone and treats blank as absent', () {
    final withPhone = UserProfile.fromJson({'id': '1', 'email': 'a@b.c', 'phone': '+919876543210'});
    expect(withPhone.phoneOrNull, '+919876543210');
    final blank = UserProfile.fromJson({'id': '1', 'email': 'a@b.c', 'phone': '  '});
    expect(blank.phoneOrNull, isNull);
    expect(UserProfile.fromJson({'id': '1', 'email': null}).phoneOrNull, isNull);
  });

  test('language choice persists and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final first = LanguageController(OnboardingService());
    await first.setLanguage(OnboardingLanguage.marathi);
    final second = LanguageController(OnboardingService());
    await second.load();
    expect(second.state, OnboardingLanguage.marathi);
    expect(second.state.locale, const Locale('mr'));
  });

  test('every supported locale has translations', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final hi = await AppLocalizations.delegate.load(const Locale('hi'));
    final mr = await AppLocalizations.delegate.load(const Locale('mr'));
    expect(hi.navHome, isNot(en.navHome));
    expect(mr.navHome, isNotEmpty);
  });
}
