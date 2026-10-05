import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:nagarik/core/theme/app_theme.dart';
import 'package:nagarik/features/discovery/domain/home_location.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:nagarik/features/discovery/presentation/screens/home_feed_screen.dart';
import 'package:nagarik/features/discovery/presentation/screens/search_screen.dart';
import 'package:nagarik/features/discovery/presentation/widgets/category_grid.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';

const _emptyPage = ReportsPage(items: [], total: 0, limit: 10, offset: 0);

Widget _home(UserProfile profile, {Future<UserProfile>? pending}) {
  return ProviderScope(
    overrides: [
      currentUserProfileProvider.overrideWith((ref) => pending ?? Future.value(profile)),
      homeFeedProvider.overrideWith((ref) async => _emptyPage),
      nearbyReportsProvider.overrideWith((ref) async => _emptyPage),
      homeLocationProvider.overrideWith(
        (ref) async => HomeLocation(
          position: Position(
            latitude: 0,
            longitude: 0,
            timestamp: DateTime(2026),
            accuracy: 1,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
          city: 'Pune',
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const HomeFeedScreen()),
  );
}

void main() {
  group('Home greeting', () {
    testWidgets('greets the user by full name', (tester) async {
      await tester.pumpWidget(
        _home(const UserProfile(id: '1', email: 'asha@example.com', fullName: 'Asha Rao')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello, Asha Rao 👋'), findsOneWidget);
      expect(find.textContaining('asha@example.com'), findsNothing);
    });

    testWidgets('never falls back to the email address', (tester) async {
      await tester.pumpWidget(_home(const UserProfile(id: '1', email: 'asha@example.com')));
      await tester.pumpAndSettle();

      expect(find.text('Hello there 👋'), findsOneWidget);
      expect(find.textContaining('asha@example.com'), findsNothing);
    });

    testWidgets('shows the neutral greeting while the profile is loading', (tester) async {
      final completer = Completer<UserProfile>();
      await tester.pumpWidget(
        _home(const UserProfile(id: '1', email: 'a@b.co'), pending: completer.future),
      );
      await tester.pump();

      expect(find.text('Hello there 👋'), findsOneWidget);

      completer.complete(const UserProfile(id: '1', email: 'a@b.co', fullName: 'Asha Rao'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Asha Rao 👋'), findsOneWidget);
    });
  });

  group('CategoryGrid', () {
    testWidgets('tiles are no taller than wide, and all the same size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CategoryGrid(onCategoryTap: (_) {})),
        ),
      );
      await tester.pumpAndSettle();

      final tiles = find.byType(Card);
      expect(tiles, findsNWidgets(7));
      final sizes = [for (var i = 0; i < 7; i++) tester.getSize(tiles.at(i))];
      for (final size in sizes) {
        expect(size, sizes.first);
        expect(size.height, lessThanOrEqualTo(size.width + 0.5));
      }
    });
  });

  group('SearchScreen', () {
    Future<void> pumpSearch(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: AppTheme.light, home: const SearchScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('orders search → category → status → location → action', (tester) async {
      await pumpSearch(tester, const Size(390, 844));

      double top(Finder finder) => tester.getTopLeft(finder.first).dy;
      final order = [
        find.byType(TextField).first,
        find.text('Category'),
        find.text('Status'),
        find.text('Location'),
        find.text('Near Me'),
        find.text('City'),
        find.widgetWithText(ElevatedButton, 'Search'),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i], findsWidgets);
        expect(top(order[i]), greaterThan(top(order[i - 1])), reason: 'item $i out of order');
      }
      expect(find.text('PIN code'), findsOneWidget);
    });

    testWidgets('chips share one height and the layout fits a small phone', (tester) async {
      await pumpSearch(tester, const Size(320, 568));

      final chips = find.byType(ChoiceChip);
      expect(chips, findsWidgets);
      final heights = {
        for (var i = 0; i < chips.evaluate().length; i++)
          if (tester.getRect(chips.at(i)).left < 320) tester.getSize(chips.at(i)).height,
      };
      expect(heights.length, 1, reason: 'chip heights differ: $heights');
      expect(tester.takeException(), isNull);
    });
  });
}
