/// A normalized error shape for anything that goes wrong talking to the
/// FastAPI backend, so UI code never has to know about Dio internals.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
