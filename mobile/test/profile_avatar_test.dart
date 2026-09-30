import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/shared/widgets/profile_avatar.dart';

/// User Profile Photo upgrade: [ProfileAvatar] is the one place the
/// "no photo yet" fallback is decided, so it's worth pinning directly
/// rather than re-testing it on every screen that uses the widget. The
/// "has a photo" path isn't exercised here — it goes through
/// `CachedNetworkImage`'s real network fetch, which isn't available in a
/// widget test, and the widget's own `errorWidget` already falls back to
/// the same initial-letter avatar tested below.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the initial-letter avatar when there is no photo', (tester) async {
    await tester.pumpWidget(
      wrap(const ProfileAvatar(avatarUrl: null, displayName: 'Asha Rao')),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('treats an empty avatarUrl the same as no photo', (tester) async {
    await tester.pumpWidget(
      wrap(const ProfileAvatar(avatarUrl: '', displayName: 'Asha Rao')),
    );

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('falls back to "?" for an empty display name', (tester) async {
    await tester.pumpWidget(
      wrap(const ProfileAvatar(avatarUrl: null, displayName: '')),
    );

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('honors the given radius', (tester) async {
    await tester.pumpWidget(
      wrap(const ProfileAvatar(avatarUrl: null, displayName: 'Asha Rao', radius: 20)),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.radius, 20);
  });
}
