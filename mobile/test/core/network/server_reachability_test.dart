import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/core/network/server_reachability.dart';

import '../../helpers/fake_dio.dart';

/// The probe is what decides whether a patient may start filling in the
/// sign-up form, so both ways it can be wrong cost something real: a false
/// "down" locks someone out of registering on a server that works, and a false
/// "up" lets them type three fields into nothing.
void main() {
  late FakeDio fake;

  ServerProbe probeWith({
    bool connected = true,
    bool connectivityThrows = false,
    Duration timeout = const Duration(seconds: 6),
  }) => ServerProbe(
    dio: fake.dio,
    hasConnectivity: () async {
      if (connectivityThrows) throw StateError('no plugin');
      return connected;
    },
    timeout: timeout,
  );

  setUp(() => fake = FakeDio());

  test('no radio is answered without spending a request', () async {
    fake.stub(ApiEndpoints.health, FakeResponse.ok(<String, String>{}));

    expect(
      await probeWith(connected: false).check(),
      ServerReachability.noInternet,
    );
    expect(fake.requests, isEmpty);
  });

  test(
    'an unavailable connectivity plugin falls through to the request',
    () async {
      fake.stub(ApiEndpoints.health, FakeResponse.ok(<String, String>{}));

      // Desktop and `flutter test` have no plugin behind the channel. The
      // request answers the same question anyway, so the probe must not report
      // "no internet" just because the shortcut failed.
      expect(
        await probeWith(connectivityThrows: true).check(),
        ServerReachability.online,
      );
      expect(fake.requests.single.path, ApiEndpoints.health);
    },
  );

  test('a healthy server is online', () async {
    fake.stub(
      ApiEndpoints.health,
      FakeResponse.ok(<String, String>{'status': 'UP'}),
    );

    expect(await probeWith().check(), ServerReachability.online);
  });

  // The registration form is blocked on this answer, so "something of ours
  // replied" has to count — a deployment that predates `/health` answers 401
  // or 404, and refusing sign-up against a working server would be worse than
  // letting the request itself report the problem.
  for (final int status in <int>[401, 403, 404, 405]) {
    test('$status still proves the server is listening', () async {
      fake.stub(ApiEndpoints.health, FakeResponse.error(status, 'nope'));

      expect(await probeWith().check(), ServerReachability.online);
    });
  }

  for (final int status in <int>[500, 502, 503]) {
    test('$status counts as unreachable — no account can be created', () async {
      fake.stub(ApiEndpoints.health, FakeResponse.error(status, 'boom'));

      expect(await probeWith().check(), ServerReachability.noServer);
    });
  }

  test('a refused connection is noServer, not noInternet', () async {
    // The phone has a network — it is the server that is missing, and the
    // message the patient sees differs on exactly this.
    fake.stub(ApiEndpoints.health, FakeResponse.offline());

    expect(await probeWith().check(), ServerReachability.noServer);
  });

  test('a timeout is noServer', () async {
    fake.stub(
      ApiEndpoints.health,
      FakeResponse(
        throwing: DioException.receiveTimeout(
          timeout: const Duration(seconds: 6),
          requestOptions: RequestOptions(path: ApiEndpoints.health),
        ),
      ),
    );

    expect(await probeWith().check(), ServerReachability.noServer);
  });

  test('a dead ngrok tunnel is not mistaken for our server', () async {
    // ngrok answers for a tunnel that is no longer forwarding, and its 404
    // would otherwise sail through the "under 500 means listening" rule.
    fake.stub(
      ApiEndpoints.health,
      const FakeResponse(
        statusCode: 404,
        headers: <String, String>{'ngrok-error-code': 'ERR_NGROK_3200'},
      ),
    );

    expect(await probeWith().check(), ServerReachability.noServer);
  });

  test('only online unblocks a screen', () {
    expect(ServerReachability.online.isOnline, isTrue);
    expect(ServerReachability.checking.isOnline, isFalse);
    expect(ServerReachability.noInternet.isOnline, isFalse);
    expect(ServerReachability.noServer.isOnline, isFalse);
  });

  test('every blocking state has something to say, and online does not', () {
    expect(ServerReachability.online.messageKey, isNull);
    for (final ServerReachability state in <ServerReachability>[
      ServerReachability.checking,
      ServerReachability.noInternet,
      ServerReachability.noServer,
    ]) {
      expect(state.messageKey, isNotNull, reason: '$state needs a message');
    }
  });
}
