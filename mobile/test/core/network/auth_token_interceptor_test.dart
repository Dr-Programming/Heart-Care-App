import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/network/interceptors/auth_token_interceptor.dart';

void main() {
  Future<RequestOptions> capture({required String? token}) async {
    final interceptor = AuthTokenInterceptor(() async => token);
    final options = RequestOptions(path: '/api/v1/auth/me');
    final handler = RequestInterceptorHandler();
    interceptor.onRequest(options, handler);
    return options;
  }

  test('attaches the bearer token when one is stored', () async {
    final options = await capture(token: 'jwt-abc');
    expect(options.headers['Authorization'], 'Bearer jwt-abc');
  });

  test('sends no Authorization header when there is no token', () async {
    final options = await capture(token: null);
    expect(options.headers.containsKey('Authorization'), isFalse);
  });
}
