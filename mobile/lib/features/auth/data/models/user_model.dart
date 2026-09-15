import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/auth_user.dart';

part 'user_model.freezed.dart';

@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String name,
    required String phone,
    required String preferredLanguage,
    required String role,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      preferredLanguage: json['preferredLanguage'] as String,
      role: json['role'] as String,
    );
  }

  AuthUser toDomain() => AuthUser(
    id: id,
    name: name,
    phone: phone,
    preferredLanguage: preferredLanguage,
    role: role,
  );
}
