import 'package:geolocator/geolocator.dart';

/// The device's current position, plus a best-effort readable place name
/// for it (e.g. "Bhopal") for the Home screen's location indicator. [city]
/// is nullable because reverse geocoding is best-effort and non-fatal (see
/// `GeocodingService`) — a resolved [position] with no [city] still shows
/// something useful.
class HomeLocation {
  const HomeLocation({required this.position, required this.city});

  final Position position;
  final String? city;
}
