import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'interceptors/auth_token_interceptor.dart';

/// Builds the app's single configured Dio instance.
///
/// Timeouts are deliberately generous: the target deployment is intermittent
/// Ethiopian mobile data, where a 5-second timeout would fail requests that
/// would otherwise have succeeded.
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
      // Let 4xx through to the mapper rather than having Dio throw its own
      // opaque error before we can read the envelope.
      validateStatus: (int? status) => status != null && status < 400,
    ),
  );

  dio.interceptors.add(AuthTokenInterceptor(readToken));
  return dio;
}

const String _offlineMessage = 'errors.offline';

/// The single place that knows how an HTTP status becomes a `Failure`.
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
      return const NetworkFailure('errors.secureConnection');
    case DioExceptionType.unknown:
    case DioExceptionType.badResponse:
      break;
  }

  if (e.response == null) return const NetworkFailure(_offlineMessage);

  final Response<dynamic>? response = e.response;
  final int status = response?.statusCode ?? 0;
  final String message = _messageFrom(response);

  return switch (status) {
    400 => ValidationFailure(message),
    401 => InvalidCredentialsFailure(message),
    404 => UnknownFailure(message),
    409 => PhoneAlreadyRegisteredFailure(message),
    413 => ValidationFailure(message),
    423 => AccountLockedFailure(message,
        minutesRemaining: parseLockoutMinutes(message)),
    >= 500 => ServerFailure(message),
    _ => UnknownFailure(message),
  };
}

/// Pulls `message` out of the standard envelope, falling back to a translation
/// key if the body is not the shape we expect.
String _messageFrom(Response<dynamic>? response) {
  final dynamic data = response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return 'errors.generic';
}
