import 'dart:convert';

import 'package:dio/dio.dart';

/// A canned HTTP response.
class FakeResponse {
  const FakeResponse({
    this.statusCode = 200,
    this.body = const <String, dynamic>{},
    this.throwing,
  });

  /// A success envelope: `{success: true, data: ..., message: ...}`.
  factory FakeResponse.ok(Object? data, {String message = 'OK'}) {
    return FakeResponse(
      body: <String, dynamic>{
        'success': true,
        'data': data,
        'message': message,
        'timestamp': '2026-08-22T10:00:00Z',
      },
    );
  }

  /// An error envelope at [statusCode]. Remember the API sends the same
  /// envelope shape for errors as for successes.
  factory FakeResponse.error(int statusCode, String message) {
    return FakeResponse(
      statusCode: statusCode,
      body: <String, dynamic>{
        'success': false,
        'data': null,
        'message': message,
        'timestamp': '2026-08-22T10:00:00Z',
      },
    );
  }

  /// A transport failure — no response at all, the offline case.
  factory FakeResponse.offline() {
    return FakeResponse(
      throwing: DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'No connection',
      ),
    );
  }

  final int statusCode;
  final Object body;
  final DioException? throwing;
}

/// One recorded outbound request, so a test can assert what was sent.
class RecordedRequest {
  const RecordedRequest(
    this.method,
    this.path,
    this.data,
    this.queryParameters,
  );

  final String method;
  final String path;
  final Object? data;
  final Map<String, dynamic> queryParameters;

  /// The request body as a map, for the common JSON case.
  Map<String, dynamic> get json => (data as Map<Object?, Object?>).cast();
}

/// A Dio that never touches the network.
///
/// Preferred over mocking Dio itself: the real client still runs, so the
/// interceptors, the `validateStatus` rule and the `DioException` mapping in
/// `core/network/dio_client.dart` are all exercised. A mocked Dio would skip
/// exactly the code most likely to be wrong.
///
/// ```dart
/// final fake = FakeDio()..stub('/api/v1/vitals', FakeResponse.ok({...}));
/// final repo = VitalsRepositoryImpl(remote: VitalsRemoteDataSource(fake.dio));
/// ...
/// expect(fake.requests.single.json['type'], 'BLOOD_PRESSURE');
/// ```
class FakeDio {
  FakeDio({String baseUrl = 'http://localhost:8080', String? token}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        validateStatus: (int? status) => status != null && status < 400,
      ),
    );
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
    dio.httpClientAdapter = _Adapter(this);
  }

  late final Dio dio;

  final Map<String, FakeResponse> _stubs = <String, FakeResponse>{};
  FakeResponse _fallback = FakeResponse.error(404, 'Not found');

  /// Every request made through [dio], in order.
  final List<RecordedRequest> requests = <RecordedRequest>[];

  /// Answers [path] with [response]. Matches on path only, so a stub covers
  /// every verb and every query string for that path.
  void stub(String path, FakeResponse response) => _stubs[path] = response;

  /// Answers anything not explicitly stubbed.
  void stubAll(FakeResponse response) => _fallback = response;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this._fake);

  final FakeDio _fake;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _fake.requests.add(
      RecordedRequest(
        options.method,
        options.path,
        options.data,
        options.queryParameters,
      ),
    );

    final FakeResponse stub = _fake._stubs[options.path] ?? _fake._fallback;
    if (stub.throwing != null) throw stub.throwing!;

    return ResponseBody.fromString(
      jsonEncode(stub.body),
      stub.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
