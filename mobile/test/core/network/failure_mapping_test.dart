import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/network/dio_client.dart';

/// Serves a fixed status + envelope so the mapping can be exercised
/// without a live server.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(int status, String message) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = _StubAdapter(status, {
    'success': false,
    'data': null,
    'message': message,
    'timestamp': '2026-09-03T10:00:00Z',
  });
  return dio;
}

Future<Failure> _failureFrom(int status, String message) async {
  try {
    await _dioReturning(status, message).get<dynamic>('/anything');
    fail('expected the request to throw');
  } on DioException catch (e) {
    return failureFromDioException(e);
  }
}

void main() {
  test('400 becomes a ValidationFailure carrying the server message', () async {
    final f = await _failureFrom(400, 'pin: PIN must be exactly 4 digits');
    expect(f, isA<ValidationFailure>());
    expect(f.message, 'pin: PIN must be exactly 4 digits');
  });

  test('401 becomes InvalidCredentialsFailure', () async {
    final f = await _failureFrom(401, 'Invalid phone or PIN');
    expect(f, isA<InvalidCredentialsFailure>());
  });

  test('409 becomes PhoneAlreadyRegisteredFailure', () async {
    final f = await _failureFrom(409, 'Phone already registered');
    expect(f, isA<PhoneAlreadyRegisteredFailure>());
  });

  test('423 becomes AccountLockedFailure with the minutes parsed out', () async {
    final f = await _failureFrom(
        423, 'Too many failed attempts. Try again in 12 minutes.');
    expect(f, isA<AccountLockedFailure>());
    expect((f as AccountLockedFailure).minutesRemaining, 12);
  });

  test('423 on the final minute still parses, despite the singular noun', () async {
    final f = await _failureFrom(
        423, 'Too many failed attempts. Try again in 1 minute.');
    expect((f as AccountLockedFailure).minutesRemaining, 1);
  });

  test('500 becomes ServerFailure', () async {
    final f = await _failureFrom(500, 'An unexpected error occurred');
    expect(f, isA<ServerFailure>());
  });

  test('a connection error becomes NetworkFailure', () {
    final e = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    expect(failureFromDioException(e), isA<NetworkFailure>());
  });

  test('a timeout becomes NetworkFailure', () {
    final e = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.receiveTimeout,
    );
    expect(failureFromDioException(e), isA<NetworkFailure>());
  });
}
