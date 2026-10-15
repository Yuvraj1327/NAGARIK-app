/// Whether Google Maps can be shown on this platform right now. Only ever
/// `false` on web when the Maps JavaScript API couldn't load (no or bad
/// key); native platforms always report `true` (a bad native key shows
/// Google's own blank/watermarked map, which can't be detected from Dart).
/// Map widgets check this to show a friendly fallback instead of a broken map.
class MapsAvailability {
  MapsAvailability._();
  static bool isAvailable = true;
}
