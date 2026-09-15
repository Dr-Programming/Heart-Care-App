import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_model.dart';

part 'auth_response_model.freezed.dart';

@freezed
abstract class AuthResponseModel with _$AuthResponseModel {
  const factory AuthResponseModel({
    required String token,
    required UserModel user,
  }) = _AuthResponseModel;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
