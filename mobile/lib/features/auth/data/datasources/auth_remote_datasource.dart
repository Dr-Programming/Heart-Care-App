import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/security_question.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponseModel> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
    List<SecurityAnswer>? securityAnswers,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.register,
      data: <String, dynamic>{
        'phone': phone,
        'pin': pin,
        'name': name,
        'preferredLanguage': preferredLanguage,
        if (securityAnswers != null)
          'securityAnswers': securityAnswers.map((SecurityAnswer a) => a.toJson()).toList(),
      },
    );
    return _unwrap(response, AuthResponseModel.fromJson);
  }

  Future<AuthResponseModel> login({required String phone, required String pin}) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.login,
      data: <String, dynamic>{'phone': phone, 'pin': pin},
    );
    return _unwrap(response, AuthResponseModel.fromJson);
  }

  /// PIN change proven with the current PIN, no session needed (it may be a
  /// change queued while offline). [changeId] makes a retry safe.
  Future<AuthResponseModel> pinChange({
    required String phone,
    required String currentPin,
    required String newPin,
    required String changeId,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.pinChange,
      data: <String, dynamic>{
        'phone': phone,
        'currentPin': currentPin,
        'newPin': newPin,
        'changeId': changeId,
      },
    );
    return _unwrap(response, AuthResponseModel.fromJson);
  }

  /// Forgot PIN: the server checks [answers] and sets [newPin].
  Future<AuthResponseModel> resetPin({
    required String phone,
    required List<SecurityAnswer> answers,
    required String newPin,
    required String changeId,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.resetPin,
      data: <String, dynamic>{
        'phone': phone,
        'answers': answers.map((SecurityAnswer a) => a.toJson()).toList(),
        'newPin': newPin,
        'changeId': changeId,
      },
    );
    return _unwrap(response, AuthResponseModel.fromJson);
  }

  Future<List<SecurityQuestion>> recoveryQuestions(String phone) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.recoveryQuestions,
      data: <String, dynamic>{'phone': phone},
    );
    return _unwrap(response, _questionsFrom);
  }

  /// Whether the signed-in patient has security questions set on the server.
  Future<bool> securityAnswersConfigured() async {
    final Response<dynamic> response = await _dio.get<dynamic>(ApiEndpoints.securityAnswers);
    return _unwrap(response, (Map<String, dynamic> json) => json['configured'] == true);
  }

  Future<void> setSecurityAnswers({
    required String currentPin,
    required List<SecurityAnswer> answers,
  }) async {
    await _dio.put<dynamic>(
      ApiEndpoints.securityAnswers,
      data: <String, dynamic>{
        'currentPin': currentPin,
        'answers': answers.map((SecurityAnswer a) => a.toJson()).toList(),
      },
    );
  }

  static List<SecurityQuestion> _questionsFrom(Map<String, dynamic> json) {
    return <SecurityQuestion>[
      for (final Object? id in (json['questions'] as List<Object?>?) ?? <Object?>[])
        if (id is String) ?SecurityQuestion.fromId(id),
    ];
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
