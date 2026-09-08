import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._remote,
    required this._local,
    required this._isOnline,
  });

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final Future<bool> Function() _isOnline;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    await _requireConnection();
    final UserModel user = await _guard(() async {
      final response = await _remote.login(phone: phone, pin: pin);
      await _local.saveSession(token: response.token, user: response.user);
      return response.user;
    });
    return user.toEntity();
  }

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) async {
    await _requireConnection();
    final UserModel user = await _guard(() async {
      final response = await _remote.register(
        phone: phone,
        pin: pin,
        name: name,
        preferredLanguage: language.code,
      );
      await _local.saveSession(token: response.token, user: response.user);
      return response.user;
    });
    return user.toEntity();
  }

  @override
  Future<AuthUser> getMe() async {
    final UserModel user = await _guard(
      () => _remote.me(),
      unauthorizedMeansExpired: true,
    );
    await _local.cacheUser(user);
    return user.toEntity();
  }

  @override
  Future<void> logout() => _local.clearSession();

  @override
  Future<AuthUser?> cachedUser() async {
    final UserModel? user = await _local.cachedUser();
    return user?.toEntity();
  }

  @override
  Future<bool> hasValidSession() => _local.hasValidSession();

  /// First-time auth is the one part of the app allowed to require
  /// connectivity — no request is attempted while offline.
  Future<void> _requireConnection() async {
    if (!await _isOnline()) {
      throw const NetworkFailure('errors.offline');
    }
  }

  /// Runs [action], translating any [DioException] into a [Failure] the same
  /// way everywhere. [unauthorizedMeansExpired] turns a 401 into
  /// [SessionExpiredFailure] instead of [InvalidCredentialsFailure] — true
  /// only for `getMe`, where a 401 means the 7-day token expired, not that a
  /// PIN was wrong.
  Future<T> _guard<T>(
    Future<T> Function() action, {
    bool unauthorizedMeansExpired = false,
  }) async {
    try {
      return await action();
    } on DioException catch (e) {
      final Failure failure = failureFromDioException(e);
      if (unauthorizedMeansExpired && failure is InvalidCredentialsFailure) {
        throw SessionExpiredFailure(failure.message);
      }
      throw failure;
    }
  }
}
