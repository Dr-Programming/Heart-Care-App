/// The envelope every Heart-Care endpoint returns, success or error:
/// `{ "success": bool, "data": T|null, "message": string, "timestamp": string }`.
///
/// The API returns **200 for creates as well** — there is no 201 anywhere — so
/// callers must never treat 201 as the success case.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.data,
    required this.message,
    required this.timestamp,
  });

  final bool success;
  final T? data;
  final String message;
  final DateTime? timestamp;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) fromData,
  ) {
    final Object? raw = json['data'];
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: raw == null ? null : fromData(raw),
      message: json['message'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }
}
