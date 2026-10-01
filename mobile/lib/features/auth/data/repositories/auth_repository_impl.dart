import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/security_question.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/offline_credential_store.dart';
import '../datasources/pending_pin_change_store.dart';
import '../models/auth_response_model.dart';

const String _offlineMessage =
    'You need a connection to sign in the first time';
const String _answersDontMatch = "The answers don't match";
const String _recoveryNeedsConnection =
    'Connect to the internet to reset your PIN on this phone';

class AuthRepositoryImpl implements AuthRepository, PinRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.offline,
    required this.session,
    required this.pending,
    required this.isOnline,
    this.fallbackTimeout = const Duration(seconds: 8),
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final OfflineCredentialStore offline;
  final OfflineSession session;

  /// The PIN change made offline and not yet accepted by the server.
  final PendingPinChangeStore pending;

  static const Uuid _uuid = Uuid();

  SignOutReason? _signOutReason;

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

    // A PIN changed on this phone while offline isn't on the server yet, so an
    // ordinary sign-in with it would be refused. Send the change first.
    final PendingPinChange? queued = await pending.read();
    if (queued != null && queued.phone == phone) {
      final PinSyncResult result = await flushPendingPinChange();
      if (result == PinSyncResult.applied && pin == queued.newPin) {
        return (await local.cachedUser())!;
      }
      if (result == PinSyncResult.kept) {
        return _loginOffline(phone: phone, pin: pin);
      }
    }

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
    List<SecurityAnswer>? securityAnswers,
  }) async {
    if (!await isOnline()) throw const NetworkFailure(_offlineMessage);
    try {
      final response = await remote.register(
        phone: phone,
        pin: pin,
        name: name,
        preferredLanguage: preferredLanguage,
        securityAnswers: securityAnswers,
      );
      final AuthUser user = await _startSession(response, pin: pin);
      // Kept here too, so this phone can reset a forgotten PIN offline from day one.
      if (securityAnswers != null) await offline.rememberAnswers(securityAnswers);
      return user;
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
    if (!await isOnline()) return true;
    // A PIN change made offline goes first. While it waits, the server still
    // has the old PIN, so re-signing-in with the new one below would be
    // refused and would wrongly wipe this phone's credentials.
    switch (await flushPendingPinChange()) {
      case PinSyncResult.conflict:
        return false;
      case PinSyncResult.kept:
      case PinSyncResult.applied:
        return true;
      case PinSyncResult.nothingPending:
        break;
    }

    final ({String phone, String pin})? credentials = session.credentials;
    if (credentials == null) return true;
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

  // ---- PinRepository ----------------------------------------------------

  @override
  Future<PinChangeOutcome> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final AuthUser user = await _rememberedOrCached();

    if (await pending.read() == null && await isOnline()) {
      try {
        final AuthResponseModel response = await remote.pinChange(
          phone: user.phone,
          currentPin: currentPin,
          newPin: newPin,
          changeId: _uuid.v4(),
        );
        await _startSession(response, pin: newPin);
        return PinChangeOutcome.applied;
      } on DioException catch (e) {
        final Failure failure = failureFromDioException(e);
        if (failure is InvalidCredentialsFailure) {
          throw const InvalidCredentialsFailure('Current PIN is incorrect');
        }
        if (failure is! NetworkFailure && failure is! ServerFailure) throw failure;
        // Unreachable: fall through to the offline path.
      }
    }

    switch (await offline.verify(phone: user.phone, pin: currentPin)) {
      case OfflineCheck.match:
        break;
      case OfflineCheck.wrongPin:
        throw const InvalidCredentialsFailure('Current PIN is incorrect');
      case OfflineCheck.locked:
        final int? minutes = await offline.lockedFor();
        throw AccountLockedFailure(
          'Too many attempts. Try again in $minutes minutes',
          minutesRemaining: minutes,
        );
      case OfflineCheck.unknownAccount:
        throw const NetworkFailure(_offlineMessage);
    }
    await offline.changePin(newPin);
    await pending.recordChange(phone: user.phone, currentPin: currentPin, newPin: newPin);
    if (session.isActive) session.begin(phone: user.phone, pin: newPin);

    if (await isOnline() && await flushPendingPinChange() == PinSyncResult.applied) {
      return PinChangeOutcome.applied;
    }
    return PinChangeOutcome.queued;
  }

  @override
  Future<List<SecurityQuestion>> recoveryQuestions(String phone) async {
    if (await isOnline()) {
      try {
        return await remote.recoveryQuestions(phone);
      } on DioException catch (e) {
        final Failure failure = failureFromDioException(e);
        if (failure is! NetworkFailure && failure is! ServerFailure) throw failure;
      }
    }
    final List<SecurityQuestion> stored = await offline.rememberedQuestions(phone);
    if (stored.isEmpty) throw const NetworkFailure(_recoveryNeedsConnection);
    return stored;
  }

  @override
  Future<PinChangeOutcome> resetPin({
    required String phone,
    required List<SecurityAnswer> answers,
    required String newPin,
  }) async {
    if (await isOnline()) {
      try {
        final AuthResponseModel response = await remote.resetPin(
          phone: phone,
          answers: answers,
          newPin: newPin,
          changeId: _uuid.v4(),
        );
        // The server's reset supersedes anything this phone still had queued.
        await pending.clear();
        await _startSession(response, pin: newPin);
        await offline.rememberAnswers(answers);
        return PinChangeOutcome.applied;
      } on DioException catch (e) {
        final Failure failure = failureFromDioException(e);
        if (failure is ValidationFailure) {
          throw const InvalidCredentialsFailure(_answersDontMatch);
        }
        if (failure is! NetworkFailure && failure is! ServerFailure) throw failure;
      }
    }

    switch (await offline.verifyAnswers(phone: phone, answers: answers)) {
      case OfflineCheck.match:
        break;
      case OfflineCheck.wrongPin:
        throw const InvalidCredentialsFailure(_answersDontMatch);
      case OfflineCheck.locked:
        final int? minutes = await offline.recoveryLockedFor();
        throw AccountLockedFailure(
          'Too many attempts. Try again in $minutes minutes',
          minutesRemaining: minutes,
        );
      case OfflineCheck.unknownAccount:
        throw const NetworkFailure(_recoveryNeedsConnection);
    }
    await offline.changePin(newPin);
    await pending.recordReset(phone: phone, answers: answers, newPin: newPin);
    final AuthUser user = (await offline.rememberedUser())!;
    await local.saveUser(user);
    session.begin(phone: phone, pin: newPin);
    return PinChangeOutcome.queued;
  }

  @override
  Future<void> setSecurityAnswers({
    required String currentPin,
    required List<SecurityAnswer> answers,
  }) async {
    if (!await isOnline()) throw const NetworkFailure(_recoveryNeedsConnection);
    try {
      await remote.setSecurityAnswers(currentPin: currentPin, answers: answers);
    } on DioException catch (e) {
      final Failure failure = failureFromDioException(e);
      if (failure is ValidationFailure) {
        throw const InvalidCredentialsFailure('Current PIN is incorrect');
      }
      throw failure;
    }
    await offline.rememberAnswers(answers);
  }

  @override
  Future<bool?> securityQuestionsStatus() async {
    if (!await isOnline()) return null;
    try {
      return await remote.securityAnswersConfigured();
    } on DioException {
      return null;
    }
  }

  @override
  Future<List<SecurityQuestion>> configuredQuestions() async {
    final AuthUser? user = await offline.rememberedUser();
    if (user == null) return const <SecurityQuestion>[];
    return offline.rememberedQuestions(user.phone);
  }

  @override
  Future<bool> hasPendingPinChange() async => await pending.read() != null;

  @override
  Future<PinSyncResult> flushPendingPinChange() async {
    final PendingPinChange? queued = await pending.read();
    if (queued == null) return PinSyncResult.nothingPending;
    try {
      final AuthResponseModel response = switch (queued.kind) {
        PendingPinChangeKind.change => await remote.pinChange(
          phone: queued.phone,
          currentPin: queued.currentPin ?? '',
          newPin: queued.newPin,
          changeId: queued.changeId,
        ),
        PendingPinChangeKind.reset => await remote.resetPin(
          phone: queued.phone,
          answers: queued.answers,
          newPin: queued.newPin,
          changeId: queued.changeId,
        ),
      };
      // Session first, then clear: if the app dies in between, the next sync
      // resends the same changeId and the server answers it as a replay.
      await _startSession(response, pin: queued.newPin);
      await pending.clear();
      return PinSyncResult.applied;
    } on DioException catch (e) {
      final Failure failure = failureFromDioException(e);
      if (failure is InvalidCredentialsFailure || failure is ValidationFailure) {
        // The server's PIN (or answers) changed elsewhere first: it wins.
        await pending.clear();
        session.end();
        await offline.forget();
        await local.clearSession();
        _signOutReason = SignOutReason.pinChangedElsewhere;
        return PinSyncResult.conflict;
      }
      return PinSyncResult.kept;
    }
  }

  @override
  SignOutReason? takeSignOutReason() {
    final SignOutReason? reason = _signOutReason;
    _signOutReason = null;
    return reason;
  }

  Future<AuthUser> _rememberedOrCached() async {
    final AuthUser? user = await offline.rememberedUser() ?? await local.cachedUser();
    if (user == null) throw const SessionExpiredFailure('Sign in again to change your PIN');
    return user;
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
