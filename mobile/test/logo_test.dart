import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/startup/splash_screen.dart';
import 'package:nagarik/shared/widgets/logo.dart';

/// Official Logo upgrade: [Logo] is the one widget every branded screen
/// (Login/Signup, the splash, the Home app bar, the drawer, About NAGARIK)
/// renders the mark through, so it's worth pinning its asset path and
/// square-box sizing directly, plus [SplashScreen]'s use of it.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('Logo', () {
    testWidgets('renders the official asset at the requested square size', (tester) async {
      await tester.pumpWidget(wrap(const Logo(size: 64)));

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, Logo.assetPath);
      expect(image.width, 64);
      expect(image.height, 64);
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('defaults to size 96 when none is given', (tester) async {
      await tester.pumpWidget(wrap(const Logo()));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 96);
      expect(image.height, 96);
    });

    testWidgets('clips to the given border radius when provided', (tester) async {
      await tester.pumpWidget(
        wrap(const Logo(size: 32, borderRadius: BorderRadius.all(Radius.circular(8)))),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('has no border radius clipping by default', (tester) async {
      await tester.pumpWidget(wrap(const Logo(size: 32)));

      expect(find.byType(ClipRRect), findsNothing);
    });
  });

  group('SplashScreen', () {
    testWidgets('shows the logo, full screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.byType(Logo), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
