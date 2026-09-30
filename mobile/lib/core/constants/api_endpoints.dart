/// Path fragments for the FastAPI backend, relative to [Env.apiBaseUrl]
/// (which already includes the `/api/v1` prefix).
///
/// Kept as a plain constants class — endpoints are added here as each
/// backend resource is built (Steps 3-8), so feature code never hardcodes
/// a path string.
class ApiEndpoints {
  ApiEndpoints._();

  static const String health = '/health';
  static const String currentUser = '/users/me';
  static const String myAvatar = '/users/me/avatar';
  static const String reports = '/reports';
  static const String reportStats = '/reports/stats';
  static const String reportMarkers = '/reports/markers';
  static const String savedReports = '/reports/saved';
}
