import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/offline_credential_store.dart';
import '../models/auth_response_model.dart';

const String _offlineMessage =
    'You need a connection to sign in the first time';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.offline,
    required this.session,
    required this.isOnline,
    this.fallbackTimeout = const Duration(seconds: 8),
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final OfflineCredentialStore offline;
  final OfflineSession session;

  final Future<bool> Function() isOnline;

  /// How long a sign-in waits for the server before falling back to the
  /// remembered account. Only applies when there is one to fall back to — a
  /// first sign-in has no alternative, so it gets Dio's full timeout.
  final Duration fallbackTimeout;

  /// Online first, so a working server always hands out a fresh token. When
  /// the server cannot be reached — no network, a timeout, a 5xx, a dead
  /// tunnel — a patient who has signed in on this phone before is checked
  /// against [offline] instead. A server that *answers* is authoritative: its
  /// 401 or 423 is never overridden by the local check.
  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    if (!await isOnline()) return _loginOffline(phone: phone, pin: pin);

    final bool canFallBack = (await offline.rememberedUser())?.phone == phone;
    try {
      final Future<AuthResponseModel> request = remote.login(
        phone: phone,
        pin: pin,
      );
      final AuthResponseModel response = canFallBack
          ? await request.timeout(fallbackTimeout)
          : await request;
      return await _startSession(response, pin: pin);
    } on TimeoutException {
      return _loginOffline(phone: phone, pin: pin);
    } on DioException catch (e) {
      final Failure failure = failureFromDioException(e);
      if (failure is NetworkFailure || failure is ServerFailure) {
        return _loginOffline(phone: phone, pin: pin, otherwise: failure);
      }
      throw failure;
    }
  }

  /// Always needs the server — an account only exists once it has been
  /// created there.
  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async {
    if (!await isOnline()) throw const NetworkFailure(_offlineMessage);
    try {
      final response = await remote.register(
        phone: phone,
        pin: pin,
        name: name,
        preferredLanguage: preferredLanguage,
      );
      return await _startSession(response, pin: pin);
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  Future<AuthUser> _startSession(
    AuthResponseModel response, {
    required String pin,
  }) async {
    final user = response.user.toDomain();
    await local.saveSession(token: response.token, user: user);
    await offline.remember(user: user, pin: pin);
    session.end();
    return user;
  }

  Future<AuthUser> _loginOffline({
    required String phone,
    required String pin,
    Failure otherwise = const NetworkFailure(_offlineMessage),
  }) async {
    switch (await offline.verify(phone: phone, pin: pin)) {
      case OfflineCheck.match:
        final AuthUser user = (await offline.rememberedUser())!;
        await local.saveUser(user);
        session.begin(phone: phone, pin: pin);
        return user;
      case OfflineCheck.wrongPin:
        throw const InvalidCredentialsFailure('Invalid phone or PIN');
      case OfflineCheck.locked:
        final int? minutes = await offline.lockedFor();
        throw AccountLockedFailure(
          'Too many attempts. Try again in $minutes minutes',
          minutesRemaining: minutes,
        );
      case OfflineCheck.unknownAccount:
        throw otherwise;
    }
  }

  @override
  Future<bool> refreshSession() async {
    final ({String phone, String pin})? credentials = session.credentials;
    if (credentials == null) return true;
    if (!await isOnline()) return true;
    try {
      final response = await remote.login(
        phone: credentials.phone,
        pin: credentials.pin,
      );
      await _startSession(response, pin: credentials.pin);
      return true;
    } on DioException catch (e) {
      if (failureFromDioException(e) is! InvalidCredentialsFailure) return true;
      // The server no longer accepts this PIN — it was changed from another
      // phone. The remembered one is stale, so it cannot unlock this phone
      // either.
      session.end();
      await offline.forget();
      await local.clearSession();
      return false;
    }
  }

  @override
  Future<AuthUser> getMe() async {
    try {
      final model = await remote.me();
      return model.toDomain();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final dynamic data = e.response?.data;
        final String message = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Session expired';
        throw SessionExpiredFailure(message);
      }
      throw failureFromDioException(e);
    }
  }

  /// Ends the session but keeps the remembered account, so the patient can
  /// sign back in without a connection.
  @override
  Future<void> logout() async {
    session.end();
    await local.clearSession();
  }

  @override
  Future<AuthUser?> cachedUser() => local.cachedUser();

  @override
  Future<bool> isSignedIn() async =>
      session.isActive || await local.isSignedIn();

  @override
  Future<bool> needsOnboarding() => local.needsOnboarding();
}
