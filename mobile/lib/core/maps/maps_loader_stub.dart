/// Android/iOS: the native Maps SDKs are configured at build time (see
/// mobile/README.md "Google Maps setup"), so there's nothing to load.
Future<bool> ensureGoogleMapsLoaded(String? webApiKey) async => true;
