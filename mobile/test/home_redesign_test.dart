import 'package:nagarik/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:nagarik/features/discovery/domain/home_location.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:nagarik/features/discovery/presentation/widgets/location_access_card.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/shared/widgets/app_search_field.dart';
import 'package:nagarik/shared/widgets/selectable_chip.dart';

/// Home / Search / My Reports redesign: coverage for the new shared pieces
/// whose behavior (not just looks) matters.
void main() {
  Widget wrap(Widget child, {List<Override> overrides = const []}) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,home: Scaffold(body: child)),
      );

  group('LocationAccessCard', () {
    testWidgets('shows the real error and an Enable action when location fails', (tester) async {
      await tester.pumpWidget(
        wrap(
          const LocationAccessCard(),
          overrides: [
            homeLocationProvider.overrideWith(
              (ref) => Future<HomeLocation>.error(
                const LocationException('Location permission was denied.'),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location access'), findsOneWidget);
      expect(find.text('Location permission was denied.'), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget);
    });

    testWidgets('offers Settings when the OS will no longer show the prompt', (tester) async {
      await tester.pumpWidget(
        wrap(
          const LocationAccessCard(),
          overrides: [
            homeLocationProvider.overrideWith(
              (ref) => Future<HomeLocation>.error(
                const LocationException('Permanently denied.', needsAppSettings: true),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Enable'), findsNothing);
    });

    testWidgets('shows the resolved city on success', (tester) async {
      final position = Position(
        latitude: 23.2599,
        longitude: 77.4126,
        timestamp: DateTime(2026),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      await tester.pumpWidget(
        wrap(
          const LocationAccessCard(),
          overrides: [
            homeLocationProvider.overrideWith(
              (ref) async => HomeLocation(position: position, city: 'Bhopal'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bhopal'), findsOneWidget);
      expect(find.text('Enable'), findsNothing);
    });
  });

  group('SelectableChip', () {
    testWidgets('calls onTap and shows a check when selected with showCheckWhenSelected',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          SelectableChip(
            label: 'All (5)',
            selected: true,
            showCheckWhenSelected: true,
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.text('All (5)'));
      expect(taps, 1);
    });

    testWidgets('shows no check when not selected', (tester) async {
      await tester.pumpWidget(
        wrap(
          SelectableChip(
            label: 'Resolved (0)',
            selected: false,
            showCheckWhenSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('AppSearchField', () {
    testWidgets('read-only mode reports taps instead of opening a keyboard', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(AppSearchField(readOnly: true, onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(TextField));
      expect(tapped, isTrue);
    });

    testWidgets('submits typed text', (tester) async {
      String? submitted;
      final controller = TextEditingController();
      await tester.pumpWidget(
        wrap(AppSearchField(controller: controller, onSubmitted: (v) => submitted = v)),
      );

      await tester.enterText(find.byType(TextField), 'pothole');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, 'pothole');
    });
  });
}
