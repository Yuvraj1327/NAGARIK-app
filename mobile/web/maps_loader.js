// Loads the Google Maps JavaScript API on demand with a key supplied at
// runtime (from mobile/.env's GOOGLE_MAPS_WEB_API_KEY via lib/core/maps/),
// so no key is ever hardcoded or committed in this file or index.html.
window.nagarikLoadGoogleMaps = function (key) {
  return new Promise(function (resolve, reject) {
    if (window.google && window.google.maps) return resolve();
    var script = document.createElement('script');
    script.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(key);
    script.async = true;
    script.onload = function () { resolve(); };
    script.onerror = function () { reject(new Error('Google Maps JS failed to load')); };
    document.head.appendChild(script);
  });
};
