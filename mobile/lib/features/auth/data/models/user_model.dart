import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart';
import '../../domain/entities/auth_user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Wire format of the `user` object returned by register / login / me.
/// Stays inside the auth data layer — everything outside sees `AuthUser`.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String name,
    required String phone,
    required String preferredLanguage,
    required String role,
  }) = _UserModel;

  const UserModel._();

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  AuthUser toEntity() => AuthUser(
        id: id, name: name, phone: phone,
        preferredLanguage: preferredLanguage, role: role,
      );

  CachedUsersCompanion toCompanion() => CachedUsersCompanion(
        id: Value<String>(id),
        name: Value<String>(name),
        phone: Value<String>(phone),
        preferredLanguage: Value<String>(preferredLanguage),
        role: Value<String>(role),
      );

  static UserModel fromCached(CachedUser row) => UserModel(
        id: row.id, name: row.name, phone: row.phone,
        preferredLanguage: row.preferredLanguage, role: row.role,
      );
}
