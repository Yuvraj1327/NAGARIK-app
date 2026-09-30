import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/theme/theme_preference.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';
import 'package:nagarik/features/reports/domain/report_stats.dart';

/// Profile & Settings upgrade: pure-Dart coverage of the new wire-format
/// parsing (`ReportStats.fromJson`, matching `GET /reports/stats`) and the
/// theme-preference <-> ThemeMode mapping, same reasoning as
/// `report_parsing_test.dart` — no widget pump needed for plain data
/// mapping, and a wrong key/mapping here would silently mis-render the
/// Profile stats strip or the wrong theme.
void main() {
  group('ReportStats.fromJson', () {
    test('parses all four counts', () {
      final stats = ReportStats.fromJson({
        'total': 7,
        'submitted': 3,
        'in_review': 2,
        'resolved': 2,
      });

      expect(stats.total, 7);
      expect(stats.submitted, 3);
      expect(stats.inReview, 2);
      expect(stats.resolved, 2);
    });

    test('ReportStats.zero is all zeroes', () {
      expect(ReportStats.zero.total, 0);
      expect(ReportStats.zero.submitted, 0);
      expect(ReportStats.zero.inReview, 0);
      expect(ReportStats.zero.resolved, 0);
    });
  });

  group('AppThemePreference', () {
    test('maps to the matching Flutter ThemeMode', () {
      expect(AppThemePreference.system.themeMode, ThemeMode.system);
      expect(AppThemePreference.light.themeMode, ThemeMode.light);
      expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
    });

    test('has a human-readable label for every value', () {
      expect(AppThemePreference.system.label, 'System Default');
      expect(AppThemePreference.light.label, 'Light');
      expect(AppThemePreference.dark.label, 'Dark');
    });

    test('name round-trips through values.firstWhere, as the controller relies on', () {
      for (final preference in AppThemePreference.values) {
        final restored = AppThemePreference.values.firstWhere(
          (p) => p.name == preference.name,
        );
        expect(restored, preference);
      }
    });
  });

  group('UserProfile.displayName', () {
    test('prefers full name when present', () {
      const profile = UserProfile(id: 'u1', email: 'a@example.com', fullName: 'Asha Rao');
      expect(profile.displayName, 'Asha Rao');
    });

    test('falls back to email when full name is missing', () {
      const profile = UserProfile(id: 'u1', email: 'a@example.com');
      expect(profile.displayName, 'a@example.com');
    });

    test('falls back to "Citizen" when neither is available', () {
      const profile = UserProfile(id: 'u1', email: null);
      expect(profile.displayName, 'Citizen');
    });
  });

  group('UserProfile.fromJson', () {
    test('parses avatar_url when present (User Profile Photo upgrade)', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'email': 'a@example.com',
        'full_name': 'Asha Rao',
        'avatar_url': 'https://example.com/signed/avatar.jpg',
      });

      expect(profile.avatarUrl, 'https://example.com/signed/avatar.jpg');
    });

    test('avatar_url is null when the user has no photo', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'email': 'a@example.com',
        'full_name': 'Asha Rao',
        'avatar_url': null,
      });

      expect(profile.avatarUrl, isNull);
    });
  });
}
