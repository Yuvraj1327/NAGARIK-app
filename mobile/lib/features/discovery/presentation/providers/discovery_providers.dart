import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/features/discovery/domain/home_location.dart';
import 'package:nagarik/features/reports/data/geocoding_service.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';

final geocodingServiceProvider = Provider<GeocodingService>((ref) => GeocodingService());

/// Resolves the device's current position and, best-effort, a readable
/// city name for it — the Home screen's location indicator.
///
/// Modeled as a plain `FutureProvider` rather than a hand-rolled state
/// machine because Riverpod's `AsyncValue` (loading/data/error) already
/// covers exactly the "Permission request / Loading / Location unavailable
/// / Retry" states the Home screen brief asks for:
/// `LocationService.getCurrentPosition()` already throws a
/// `LocationException` carrying a message that's ready to show directly
/// for every failure mode (permission denied, denied forever, location
/// services disabled, timeout) — see that class — so any of those becomes
/// this provider's `AsyncError` automatically, and "Retry" is just
/// `ref.invalidate(homeLocationProvider)`.
final homeLocationProvider = FutureProvider.autoDispose<HomeLocation>((ref) async {
  final position = await ref.watch(locationServiceProvider).getCurrentPosition();
  final city = await ref
      .watch(geocodingServiceProvider)
      .cityFromCoordinates(position.latitude, position.longitude);
  return HomeLocation(position: position, city: city);
});

/// A short preview of reports near the resolved [homeLocationProvider]
/// position, for Home's "Nearby Issues" section.
///
/// Depends on `homeLocationProvider.future` (not `.watch`) so this
/// provider's own `AsyncValue` mirrors the location lookup's loading/error
/// state exactly: if location fails, this section shows that same
/// permission/unavailable state rather than a second, disconnected error.
/// That failure never reaches `homeFeedProvider` (Home's "Recent Reports"
/// section), which has no location dependency at all — matching the
/// brief's "if location permission is unavailable, the normal feed should
/// still work".
final nearbyReportsProvider = FutureProvider.autoDispose<ReportsPage>((ref) async {
  final location = await ref.watch(homeLocationProvider.future);
  return ref.watch(reportsRepositoryProvider).getReports(
        latitude: location.position.latitude,
        longitude: location.position.longitude,
        limit: 10,
      );
});
