/// A normalized error shape for anything that goes wrong talking to the
/// FastAPI backend, so UI code never has to know about Dio internals.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  /// True when the request never got a response from the server at all
  /// (no connectivity, DNS failure, timeout, connection refused) — as
  /// opposed to the server responding with an error status. `ApiClient`
  /// only ever sets [statusCode] from a real HTTP response
  /// (`error.response?.statusCode`), so its absence is exactly this case.
  /// Used to show a distinct "check your connection" state instead of a
  /// generic "something went wrong" one (Final Feature Polish upgrade).
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
