import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';

/// Hybrid navigation structure (Report Sharing, Saved Reports & Final
/// Feature Polish upgrade): the drawer is the app's one full feature menu,
/// so this pins that every item the brief lists is actually present. Taps
/// aren't exercised here (each one calls `context.go`/`context.push`,
/// which needs a real `GoRouter` in the tree) — this only pins the menu's
/// contents and the profile header, which is what would actually go stale
/// if a route were renamed without updating this list.
void main() {
  testWidgets('lists every feature the hybrid navigation brief calls for', (tester) async {
    // Tall enough that the lazily-built drawer list renders every row.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'user-1',
              email: 'asha@example.com',
              fullName: 'Asha Rao',
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AppDrawer())),
      ),
    );
    await tester.pumpAndSettle();

    // Profile header (stands in for a dedicated "Profile" menu entry).
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);

    for (final label in const [
      'Home',
      'Search / Discover',
      'My Reports',
      'Saved Reports',
      'Report Issue',
      'Map / Nearby',
      'My Profile',
      'Settings',
      'Help & Support',
      'Privacy Policy',
      'Terms & Conditions',
      'About NAGARIK',
      'Logout',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '"$label" should be in the app drawer');
    }

    // Grouped into labelled sections, in order, with Logout pinned last.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final sections = ['MAIN', 'SUPPORT', 'LEGAL', 'ACCOUNT'];
    for (final section in sections) {
      expect(find.text(section), findsOneWidget);
    }
    for (var i = 1; i < sections.length; i++) {
      expect(top(sections[i]), greaterThan(top(sections[i - 1])));
    }
    expect(top('Logout'), greaterThan(top('Settings')));
  });

  testWidgets('does not repeat the email when the user has no full name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) async => const UserProfile(id: 'user-1', email: 'asha@example.com'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AppDrawer())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('asha@example.com'), findsOneWidget);
  });
}
