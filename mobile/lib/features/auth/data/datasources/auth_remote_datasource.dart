import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Talks to `/api/v1/auth/*` and nothing else. Errors surface as the raw
/// [DioException] — mapping them to a [Failure] is the repository's job.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponseModel> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.register,
      data: <String, dynamic>{
        'phone': phone,
        'pin': pin,
        'name': name,
        'preferredLanguage': preferredLanguage,
      },
    );
    return _unwrap(response, AuthResponseModel.fromJson);
  }

  Future<AuthResponseModel> login({
    required String phone,
    required String pin,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.login,
      data: <String, dynamic>{'phone': phone, 'pin': pin},
    );
    return _unwrap(response, AuthResponseModel.fromJson);
  }

  Future<UserModel> me() async {
    final Response<dynamic> response = await _dio.get<dynamic>(ApiEndpoints.me);
    return _unwrap(response, UserModel.fromJson);
  }

  T _unwrap<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final ApiResponse<T> envelope = ApiResponse<T>.fromJson(
      response.data as Map<String, dynamic>,
      (Object? data) => fromJson(data as Map<String, dynamic>),
    );
    return envelope.data as T;
  }
}
