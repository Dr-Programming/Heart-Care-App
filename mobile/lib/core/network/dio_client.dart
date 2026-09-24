import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'interceptors/auth_token_interceptor.dart';

Dio buildDio({
  required String baseUrl,
  required Future<String?> Function() readToken,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,

      validateStatus: (int? status) => status != null && status < 400,
    ),
  );

  dio.interceptors.add(AuthTokenInterceptor(readToken));

  return dio;
}

const String _offlineMessage =
    'No connection. Check your network and try again.';

Failure failureFromDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure(_offlineMessage);
    case DioExceptionType.cancel:
      return const UnknownFailure('Request cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('Could not establish a secure connection.');
    case DioExceptionType.unknown:
    case DioExceptionType.badResponse:
      break;
  }

  if (e.response == null) return const NetworkFailure(_offlineMessage);

  // A tunnel that is no longer forwarding (the dev setup runs behind ngrok)
  // answers with its own error page. That is "cannot reach the server", not
  // a reply from it.
  if (e.response?.headers.value('ngrok-error-code') != null) {
    return const NetworkFailure(_offlineMessage);
  }

  final Response<dynamic>? response = e.response;
  final int status = response?.statusCode ?? 0;
  final String message = _messageFrom(response);

  return switch (status) {
    400 => ValidationFailure(message),
    401 => InvalidCredentialsFailure(message),
    404 => UnknownFailure(message),
    409 => PhoneAlreadyRegisteredFailure(message),
    413 => ValidationFailure(message),
    423 => AccountLockedFailure(
      message,
      minutesRemaining: parseLockoutMinutes(message),
    ),
    >= 500 => ServerFailure(message),
    _ => UnknownFailure(message),
  };
}

String _messageFrom(Response<dynamic>? response) {
  final dynamic data = response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return 'Something went wrong. Please try again.';
}
