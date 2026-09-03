import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Talks to the auth endpoints. Knows nothing about storage or caching —
/// architectural rule 3 keeps that in `AuthLocalDataSource`.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponseModel> register({
    required String phone,
    required String pin,
    required String name,
    required String languageCode,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.register,
      data: <String, dynamic>{
        'phone': phone, 'pin': pin, 'name': name, 'preferredLanguage': languageCode,
      },
    );
    return _authFrom(response);
  }

  Future<AuthResponseModel> login({
    required String phone,
    required String pin,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.login,
      data: <String, dynamic>{'phone': phone, 'pin': pin},
    );
    return _authFrom(response);
  }

  Future<UserModel> me() async {
    final Response<dynamic> response = await _dio.get<dynamic>(ApiEndpoints.me);
    final ApiResponse<UserModel> envelope = ApiResponse<UserModel>.fromJson(
      response.data as Map<String, dynamic>,
      (Object? data) => UserModel.fromJson(data! as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  AuthResponseModel _authFrom(Response<dynamic> response) {
    final ApiResponse<AuthResponseModel> envelope =
        ApiResponse<AuthResponseModel>.fromJson(
      response.data as Map<String, dynamic>,
      (Object? data) => AuthResponseModel.fromJson(data! as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
