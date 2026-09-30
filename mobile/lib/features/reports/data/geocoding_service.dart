import 'package:geocoding/geocoding.dart';

/// Thin wrapper around `geocoding`'s reverse lookup, mirroring
/// `LocationService`'s "one place that owns this package" pattern.
///
/// Unlike [LocationService] (whose failures are shown to the user directly,
/// since without a position there's nothing else to fall back to), a
/// reverse-geocoding failure here is deliberately non-fatal: the Home
/// screen's location indicator can always fall back to showing raw
/// coordinates, so this returns `null` instead of throwing when the device
/// geocoder is unavailable or returns nothing usable. Location itself
/// (permissions, service availability) is unaffected either way.
class GeocodingService {
  /// Best-effort locality name for a coordinate — e.g. "Bhopal" — or `null`
  /// if it can't be determined.
  Future<String?> cityFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      // Prefer `locality` (the city/town) and fall back to progressively
      // broader fields — some regions/devices leave `locality` empty.
      for (final candidate in [
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ]) {
        final trimmed = candidate?.trim();
        if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
