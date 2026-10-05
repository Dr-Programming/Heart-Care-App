import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/core/network/dio_client.dart';
import 'package:libu_care/core/network/token_refresher.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_dio.dart';

void main() {
  late FakeDio http;
  late FakeTokenStore tokens;
  late int expiredCalls;
  late Dio dio;

  FakeResponse refreshed(String access, String refresh) =>
      FakeResponse.ok(<String, dynamic>{
        'token': access,
        'refreshToken': refresh,
        'refreshTokenExpiresAt': '2099-01-01T00:00:00Z',
        'user': <String, dynamic>{},
      });

  setUp(() async {
    http = FakeDio();
    tokens = FakeTokenStore();
    expiredCalls = 0;
    await tokens.writeSession(access: 'old-access', refresh: 'refresh-1');
    dio = buildDio(
      baseUrl: 'http://localhost:8080',
      readToken: tokens.read,
      refresh: (Dio plain) =>
          TokenRefresher(dio: plain, tokens: tokens).refresh(),
      onSessionExpired: () async => expiredCalls++,
      adapter: http.dio.httpClientAdapter,
    );
  });

  test('a 401 refreshes once and retries with the new token', () async {
    http.stubSequence(ApiEndpoints.me, <FakeResponse>[
      FakeResponse.error(401, 'Expired'),
      FakeResponse.ok(<String, dynamic>{'id': 'u1'}),
    ]);
    http.stub(ApiEndpoints.refresh, refreshed('new-access', 'refresh-2'));

    final Response<dynamic> response = await dio.get<dynamic>(ApiEndpoints.me);

    expect(response.statusCode, 200);
    expect(http.requests.map((RecordedRequest r) => r.path), <String>[
      ApiEndpoints.me,
      ApiEndpoints.refresh,
      ApiEndpoints.me,
    ]);
    expect(http.requests[1].json['refreshToken'], 'refresh-1');
    expect(http.requests.last.headers['Authorization'], 'Bearer new-access');
    expect(await tokens.read(), 'new-access');
    expect(await tokens.readRefresh(), 'refresh-2');
  });

  test('a refused refresh ends the session and clears the tokens', () async {
    http.stub(ApiEndpoints.me, FakeResponse.error(401, 'Expired'));
    http.stub(
      ApiEndpoints.refresh,
      FakeResponse.error(401, 'Invalid refresh token'),
    );

    await expectLater(
      dio.get<dynamic>(ApiEndpoints.me),
      throwsA(isA<DioException>()),
    );

    expect(expiredCalls, 1);
    expect(await tokens.read(), isNull);
    expect(await tokens.readRefresh(), isNull);
  });

  test('an unreachable refresh keeps the session for later', () async {
    http.stub(ApiEndpoints.me, FakeResponse.error(401, 'Expired'));
    http.stub(ApiEndpoints.refresh, FakeResponse.offline());

    await expectLater(
      dio.get<dynamic>(ApiEndpoints.me),
      throwsA(isA<DioException>()),
    );

    expect(expiredCalls, 0);
    expect(await tokens.readRefresh(), 'refresh-1');
  });

  test('a wrong PIN on sign-in is not treated as an expired token', () async {
    http.stub(
      ApiEndpoints.login,
      FakeResponse.error(401, 'Invalid credentials'),
    );

    await expectLater(
      dio.post<dynamic>(ApiEndpoints.login, data: <String, dynamic>{}),
      throwsA(isA<DioException>()),
    );

    expect(http.requests.map((RecordedRequest r) => r.path), <String>[
      ApiEndpoints.login,
    ]);
    expect(expiredCalls, 0);
  });

  test('without a refresh token the session ends instead of looping', () async {
    await tokens.clear();
    await tokens.write('old-access');
    http.stub(ApiEndpoints.me, FakeResponse.error(401, 'Expired'));

    await expectLater(
      dio.get<dynamic>(ApiEndpoints.me),
      throwsA(isA<DioException>()),
    );

    expect(expiredCalls, 1);
    expect(
      http.requests.where(
        (RecordedRequest r) => r.path == ApiEndpoints.refresh,
      ),
      isEmpty,
    );
  });

  test('two requests failing together refresh only once', () async {
    http.stubSequence(ApiEndpoints.me, <FakeResponse>[
      FakeResponse.error(401, 'Expired'),
      FakeResponse.error(401, 'Expired'),
      FakeResponse.ok(<String, dynamic>{'id': 'u1'}),
    ]);
    http.stub(ApiEndpoints.refresh, refreshed('new-access', 'refresh-2'));

    await Future.wait(<Future<Response<dynamic>>>[
      dio.get<dynamic>(ApiEndpoints.me),
      dio.get<dynamic>(ApiEndpoints.me),
    ]);

    expect(
      http.requests.where(
        (RecordedRequest r) => r.path == ApiEndpoints.refresh,
      ),
      hasLength(1),
    );
  });
}
