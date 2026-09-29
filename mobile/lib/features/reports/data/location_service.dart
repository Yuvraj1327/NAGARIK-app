import 'package:geolocator/geolocator.dart';

/// Thrown for any location failure, carrying a message that's already
/// safe to show the user directly (permission denied, service disabled,
/// timeout, etc.) — callers don't need their own switch over failure modes.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around `geolocator`. This is the only place in the app
/// that calls it directly, so every failure mode (service disabled,
/// permission denied, denied forever, unavailable) is handled once, here.
class LocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Location services are turned off. Please enable them and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission was denied. Allow location access to use this feature.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it from your device settings.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      throw const LocationException(
        'Could not determine your current location. Please try again.',
      );
    }
  }
}
