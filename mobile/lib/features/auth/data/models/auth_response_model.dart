import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_model.dart';

part 'auth_response_model.freezed.dart';

@freezed
abstract class AuthResponseModel with _$AuthResponseModel {
  const factory AuthResponseModel({
    required String token,
    required UserModel user,

    /// Renews [token] when it expires. Absent from servers that predate
    /// refresh tokens.
    String? refreshToken,
    DateTime? refreshTokenExpiresAt,
  }) = _AuthResponseModel;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      refreshToken: json['refreshToken'] as String?,
      refreshTokenExpiresAt: DateTime.tryParse(
        json['refreshTokenExpiresAt'] as String? ?? '',
      ),
    );
  }
}
