import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/auth_user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// The `user` object as the backend sends it — see `backend/docs/API.md` §1.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String name,
    required String phone,
    required String preferredLanguage,
    required String role,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

extension UserModelMapper on UserModel {
  AuthUser toEntity() => AuthUser(
    id: id,
    name: name,
    phone: phone,
    preferredLanguage: preferredLanguage,
    role: role,
  );
}
