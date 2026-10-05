import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/features/discovery/domain/home_location.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:nagarik/features/discovery/presentation/widgets/category_grid.dart';
import 'package:nagarik/features/discovery/presentation/widgets/location_indicator.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_map.dart';

/// Location Discovery & Home upgrade: coverage for the new domain parsing
/// (`ReportMarker.fromJson`), and the widgets whose state directly reflects
/// `homeLocationProvider`'s loading/data/error `AsyncValue` — a wrong
/// mapping here would silently show the wrong location state on Home.
void main() {
  group('ReportMarker.fromJson', () {
    test('parses every field, including numeric coordinates', () {
      final marker = ReportMarker.fromJson({
        'id': 'report-1',
        'reference_id': 'NGR-2026-00001',
        'category': 'road',
        'status': 'in_review',
        'city': 'Pune',
        'latitude': 18.5204,
        'longitude': 73.8567,
      });

      expect(marker.id, 'report-1');
      expect(marker.referenceId, 'NGR-2026-00001');
      expect(marker.category, ReportCategory.road);
      expect(marker.status, ReportStatus.inReview);
      expect(marker.city, 'Pune');
      expect(marker.latitude, 18.5204);
      expect(marker.longitude, 73.8567);
    });

    test('throws a clear error for an unknown status rather than parsing wrong', () {
      expect(
        () => ReportMarker.fromJson({
          'id': 'report-1',
          'reference_id': 'NGR-2026-00001',
          'category': 'road',
          'status': 'archived',
          'city': 'Pune',
          'latitude': 18.5204,
          'longitude': 73.8567,
        }),
        throwsFormatException,
      );
    });
  });

  group('LocationIndicator', () {
    Widget wrap(Widget child, {required List<Override> overrides}) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('shows the resolved city name when location succeeds', (tester) async {
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
          const LocationIndicator(),
          overrides: [
            homeLocationProvider.overrideWith(
              (ref) async => HomeLocation(position: position, city: 'Bhopal'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bhopal'), findsOneWidget);
    });

    testWidgets('shows the location error message with a Retry action', (tester) async {
      await tester.pumpWidget(
        wrap(
          const LocationIndicator(),
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

      expect(find.textContaining('Location permission was denied.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });
  });

  group('CategoryGrid', () {
    testWidgets('tapping a tile reports that category', (tester) async {
      ReportCategory? tapped;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryGrid(onCategoryTap: (category) => tapped = category),
          ),
        ),
      );

      // Let each tile's staggered FadeSlideIn start-delay timer fire.
      await tester.pumpAndSettle();

      await tester.tap(find.text('Water'));
      expect(tapped, ReportCategory.water);
    });
  });

  group('ReportMap', () {
    testWidgets('renders a pin for every marker', (tester) async {
      final markers = [
        ReportMarker(
          id: '1',
          referenceId: 'NGR-2026-00001',
          category: ReportCategory.road,
          status: ReportStatus.submitted,
          city: 'Pune',
          latitude: 18.5204,
          longitude: 73.8567,
        ),
        ReportMarker(
          id: '2',
          referenceId: 'NGR-2026-00002',
          category: ReportCategory.water,
          status: ReportStatus.resolved,
          city: 'Pune',
          latitude: 18.53,
          longitude: 73.86,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportMap(
              markers: markers,
              center: const latlong.LatLng(18.5204, 73.8567),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.location_on), findsNWidgets(2));
    });
  });
}
