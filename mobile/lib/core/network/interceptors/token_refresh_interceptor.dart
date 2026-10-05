import 'package:dio/dio.dart';

import '../../constants/api_endpoints.dart';
import '../token_refresher.dart';

/// Renews an expired access token and retries the request once.
///
/// A [QueuedInterceptor], so requests that fail together wait for a single
/// refresh: each refresh token works once, and a second refresh with the same
/// token would look like theft to the server and sign the patient out.
///
/// The retry goes through [_plain] (no 401 handling). Retrying through the
/// queued Dio itself would deadlock if the retry failed too.
class TokenRefreshInterceptor extends QueuedInterceptor {
  TokenRefreshInterceptor({
    required this._plain,
    required this._readToken,
    required this._refresh,
    required this._onSessionExpired,
  });

  final Dio _plain;
  final Future<String?> Function() _readToken;
  final Future<RefreshResult> Function() _refresh;
  final Future<void> Function() _onSessionExpired;

  /// Endpoints that answer 401 for a wrong PIN or token, not an expired one.
  static const Set<String> _exempt = <String>{
    ApiEndpoints.login,
    ApiEndpoints.register,
    ApiEndpoints.refresh,
    ApiEndpoints.logout,
    ApiEndpoints.pinChange,
    ApiEndpoints.resetPin,
    ApiEndpoints.recoveryQuestions,
  };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions request = err.requestOptions;
    final Object? sent = request.headers['Authorization'];
    if (err.response?.statusCode != 401 ||
        sent == null ||
        _exempt.contains(request.path)) {
      return handler.next(err);
    }

    // Another request already refreshed while this one waited in the queue.
    final String? current = await _readToken();
    final bool alreadyRenewed = current != null && sent != 'Bearer $current';

    if (!alreadyRenewed) {
      switch (await _refresh()) {
        case RefreshResult.refreshed:
          break;
        case RefreshResult.rejected:
          await _onSessionExpired();
          return handler.next(err);
        case RefreshResult.unavailable:
          return handler.next(err);
      }
    }

    try {
      handler.resolve(await _plain.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
