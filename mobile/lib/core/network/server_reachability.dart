import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';

/// Whether the app can reach the API *right now*.
///
/// Most of the app does not need this: readings, doses and check-ins are
/// written locally and queued, so the `OfflineBanner` showing the radio state
/// is enough. Registration is the exception — an account only exists once the
/// server has created it, so a sign-up form the patient can fill in while
/// nothing is listening just wastes their typing. That flow needs the stronger
/// answer this enum gives: not "does the phone have a signal" but "did our
/// server actually answer".
enum ServerReachability {
  /// The probe has not come back yet. Treated as "not usable" on purpose —
  /// it is better to hold input for a moment than to accept a form that is
  /// about to be rejected.
  checking,

  /// The server answered.
  online,

  /// The phone has no network at all.
  noInternet,

  /// The phone has a network but the server did not answer it.
  noServer;

  bool get isOnline => this == ServerReachability.online;

  /// Translation key for the message shown when this state blocks an action,
  /// or `null` when nothing is blocked.
  String? get messageKey => switch (this) {
    ServerReachability.online => null,
    ServerReachability.checking => 'errors.checkingConnection',
    ServerReachability.noInternet => 'errors.noInternet',
    ServerReachability.noServer => 'errors.serverUnreachable',
  };
}

/// One round-trip to [ApiEndpoints.health], reduced to a [ServerReachability].
class ServerProbe {
  const ServerProbe({
    required this.dio,
    required this.hasConnectivity,
    this.timeout = const Duration(seconds: 6),
  });

  final Dio dio;
  final Future<bool> Function() hasConnectivity;

  /// Deliberately shorter than the 20s `Dio` uses for real calls. This runs
  /// while someone is looking at a form waiting to be told whether they may
  /// type, so a slow answer is as good as a "no".
  final Duration timeout;

  Future<ServerReachability> check() async {
    // The radio check is only a fast path: if it is unavailable (desktop, or a
    // widget test with no plugin behind the channel) fall through to the
    // request, which answers the same question more directly.
    try {
      if (!await hasConnectivity()) return ServerReachability.noInternet;
    } on Object {
      // Fall through to the request.
    }

    try {
      final Response<dynamic> response = await dio
          .get<dynamic>(
            ApiEndpoints.health,
            options: Options(
              // Any status is a useful answer here — see [_answeredByServer].
              validateStatus: (int? _) => true,
              sendTimeout: timeout,
              receiveTimeout: timeout,
            ),
          )
          // `Options` cannot narrow the connect timeout, only the send and
          // receive ones, so the whole call is bounded here as well.
          .timeout(timeout);
      return _answeredByServer(response)
          ? ServerReachability.online
          : ServerReachability.noServer;
    } on Object {
      // A timeout, a DNS failure, a refused connection or a dropped socket all
      // mean the same thing to the caller.
      return ServerReachability.noServer;
    }
  }

  /// A 401 or a 404 still proves something of ours is listening — an older
  /// deployment without `/health` answers exactly that, and blocking sign-up
  /// against a server that is merely out of date would be the worse failure.
  /// 5xx does not count: the server is up but cannot create an account.
  bool _answeredByServer(Response<dynamic> response) {
    // A tunnel that is no longer forwarding (the dev setup runs behind ngrok)
    // serves ngrok's own error page, and this header is the only thing that
    // separates it from a reply our backend wrote.
    if (response.headers.value('ngrok-error-code') != null) return false;

    final int status = response.statusCode ?? 0;
    return status > 0 && status < 500;
  }
}
