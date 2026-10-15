import 'dart:js_interop';

@JS('nagarikLoadGoogleMaps')
external JSPromise<JSAny?> _load(JSString key);

/// Web: loads the Maps JavaScript API with [webApiKey] (web/maps_loader.js).
/// Returns `false` — instead of throwing — when no key is configured or the
/// script fails, so the rest of the app still starts and map widgets can
/// show their own "map unavailable" state.
Future<bool> ensureGoogleMapsLoaded(String? webApiKey) async {
  if (webApiKey == null) return false;
  try {
    await _load(webApiKey.toJS).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
