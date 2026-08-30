import 'package:dio/dio.dart';

/// Attaches the stored JWT to every outgoing request.
///
/// Takes a reader function rather than the storage object so `core/network`
/// stays ignorant of where the token lives — the auth feature owns that.
class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor(this._readToken);

  final Future<String?> Function() _readToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final String? token = await _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
