import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../security/token_store.dart';

enum RefreshResult {
  /// A new pair is stored; retry the request.
  refreshed,

  /// The server refused the refresh token, or there is none. The tokens are
  /// cleared and the patient has to sign in again.
  rejected,

  /// The server could not be reached. Nothing changed; try again later.
  unavailable,
}

/// Trades the stored refresh token for a new pair via `POST /auth/refresh`.
///
/// [dio] must not carry the 401 interceptor, or a refused refresh would try to
/// refresh itself.
class TokenRefresher {
  const TokenRefresher({required this._dio, required this._tokens});

  final Dio _dio;
  final TokenStore _tokens;

  Future<RefreshResult> refresh() async {
    final String? refreshToken = await _tokens.readRefresh();
    if (refreshToken == null) {
      await _tokens.clear();
      return RefreshResult.rejected;
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.refresh,
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
      final Map<String, dynamic> data =
          ((response.data as Map<Object?, Object?>)['data']
                  as Map<Object?, Object?>)
              .cast<String, dynamic>();
      await _tokens.writeSession(
        access: data['token'] as String,
        refresh: data['refreshToken'] as String?,
        refreshExpiresAt: DateTime.tryParse(
          data['refreshTokenExpiresAt'] as String? ?? '',
        ),
      );
      return RefreshResult.refreshed;
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        await _tokens.clear();
        return RefreshResult.rejected;
      }
      return RefreshResult.unavailable;
    }
  }
}
