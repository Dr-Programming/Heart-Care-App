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
    Future<void> Function()? onPatientSwitch,
    Future<int> Function()? unsentRecordCount,
  }) : _onPatientSwitch = onPatientSwitch ?? _noSwitchHandler,
       _unsentRecordCount = unsentRecordCount ?? _noUnsentRecords;

  static Future<void> _noSwitchHandler() async {}
  static Future<int> _noUnsentRecords() async => 0;

  /// How many records on this phone the server hasn't received yet.
  final Future<int> Function() _unsentRecordCount;

  /// Clears the previous patient's local data when someone else signs in.
  final Future<void> Function() _onPatientSwitch;

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final OfflineCredentialStore offline;
  final OfflineSession session;

  /// The PIN change made offline and not yet accepted by the server.
  final PendingPinChangeStore pending;

  static const Uuid _uuid = Uuid();

  SignOutReason? _signOutReason;

  /// Set when an offline session was traded for a server one in the
  /// background (a queued PIN change or reset went through, or the PIN was
  /// re-checked). The app then downloads the patient's records, as after a
  /// sign-in.
  bool _serverSessionStarted = false;

  /// Whether that happened since the last call; reading it clears it.
  bool takeServerSessionStarted() {
    final bool started = _serverSessionStarted;
    _serverSessionStarted = false;
    return started;
  }

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
    await _checkPatientSwitch(phone);

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
    await _checkPatientSwitch(phone);
    try {
      final response = await remote.register(
        phone: phone,
        pin: pin,
        name: name,
        preferredLanguage: preferredLanguage,
        securityAnswers: securityAnswers,
      );
      final AuthUser user = await _startSession(response, pin: pin);
      // A new account goes through the setup wizard (health details,
      // reminders, clinic) once; it can be skipped.
      await local.setNeedsOnboarding(true);
      // Kept here too, so this phone can reset a forgotten PIN offline from day one.
      if (securityAnswers != null) {
        await offline.rememberAnswers(securityAnswers);
      }
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
    await _claimLocalData(user);
    await local.saveSession(
      token: response.token,
      refreshToken: response.refreshToken,
      refreshTokenExpiresAt: response.refreshTokenExpiresAt,
      user: user,
    );
    await offline.remember(user: user, pin: pin);
    session.end();
    return user;
  }

  /// Offline, the patient with [phone] proved who they are. They may be an
  /// earlier patient on this phone: make theirs the active account and clear
  /// the other patient's data, as an online sign-in would.
  Future<AuthUser> _becomeActive(String phone) async {
    await _checkPatientSwitch(phone, online: false);
    await offline.makeActive(phone);
    final AuthUser user = (await offline.rememberedUser())!;
    await _claimLocalData(user);
    await local.saveUser(user);
    return user;
  }

  /// Another patient's records are on this phone. Switching to [phone] would
  /// replace them, so it is allowed only when nothing is lost: online, where
  /// the new patient's records can be downloaded, and with everything the
  /// previous patient recorded already on the server. To go ahead anyway the
  /// app first deletes those records (see `discardUnsentRecordsProvider`).
  Future<void> _checkPatientSwitch(String phone, {bool online = true}) async {
    final String? owner = await local.dataOwner();
    final AuthUser? previous = await offline.rememberedUser();
    if (previous == null || (owner != null && owner != previous.id)) return;
    if (previous.phone == phone) return;
    if (!online) {
      throw PatientSwitchFailure(
        'Connect to the internet to switch to a different patient',
        needsConnection: true,
        previousPatient: previous.name,
      );
    }
    final int unsent = await _unsentRecordCount();
    if (unsent > 0) {
      throw PatientSwitchFailure(
        '${previous.name} has $unsent records that are not on the server yet',
        needsConnection: false,
        previousPatient: previous.name,
        unsentRecords: unsent,
      );
    }
  }

  /// The local tables have no user column, so the phone remembers whose data
  /// it holds. Phones from before that was recorded fall back to the account
  /// remembered for offline sign-in, which is the last one that signed in.
  Future<void> _claimLocalData(AuthUser user) async {
    final String? owner =
        await local.dataOwner() ?? (await offline.rememberedUser())?.id;
    if (owner != null && owner != user.id) await _onPatientSwitch();
    await local.setDataOwner(user.id);
  }

  Future<AuthUser> _loginOffline({
    required String phone,
    required String pin,
    Failure otherwise = const NetworkFailure(_offlineMessage),
  }) async {
    switch (await offline.verify(phone: phone, pin: pin)) {
      case OfflineCheck.match:
        final AuthUser user = await _becomeActive(phone);
        session.begin(phone: phone, pin: pin);
        return user;
      case OfflineCheck.wrongPin:
        throw const InvalidCredentialsFailure('Invalid phone or PIN');
      case OfflineCheck.locked:
        final int? minutes = await offline.lockedFor(phone: phone);
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
        return true;
      case PinSyncResult.applied:
        _serverSessionStarted = true;
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
      _serverSessionStarted = true;
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
        if (failure is! NetworkFailure && failure is! ServerFailure) {
          throw failure;
        }
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
    await pending.recordChange(
      phone: user.phone,
      currentPin: currentPin,
      newPin: newPin,
    );
    if (session.isActive) session.begin(phone: user.phone, pin: newPin);

    if (await isOnline() &&
        await flushPendingPinChange() == PinSyncResult.applied) {
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
        if (failure is! NetworkFailure && failure is! ServerFailure) {
          throw failure;
        }
      }
    }
    final List<SecurityQuestion> stored = await offline.rememberedQuestions(
      phone,
    );
    if (stored.isEmpty) throw const NetworkFailure(_recoveryNeedsConnection);
    return stored;
  }

  @override
  Future<PinChangeOutcome> resetPin({
    required String phone,
    required List<SecurityAnswer> answers,
    required String newPin,
    String? customAnswer,
  }) async {
    // The patient's own question lives on this phone only, so the phone
    // checks it; online, the server then checks the other answers.
    if (await isOnline()) {
      await _throwFor(
        await offline.verifyCustomAnswer(phone: phone, answer: customAnswer),
        phone,
      );
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
        if (failure is! NetworkFailure && failure is! ServerFailure) {
          throw failure;
        }
      }
    }

    await _throwFor(
      await offline.verifyAnswers(
        phone: phone,
        answers: answers,
        customAnswer: customAnswer,
      ),
      phone,
    );
    await _becomeActive(phone);
    await offline.changePin(newPin);
    await pending.recordReset(phone: phone, answers: answers, newPin: newPin);
    session.begin(phone: phone, pin: newPin);
    return PinChangeOutcome.queued;
  }

  /// Turns a recovery check into the failure the patient sees.
  Future<void> _throwFor(OfflineCheck check, String phone) async {
    switch (check) {
      case OfflineCheck.match:
        return;
      case OfflineCheck.wrongPin:
        throw const InvalidCredentialsFailure(_answersDontMatch);
      case OfflineCheck.locked:
        final int? minutes = await offline.recoveryLockedFor(phone: phone);
        throw AccountLockedFailure(
          'Too many attempts. Try again in $minutes minutes',
          minutesRemaining: minutes,
        );
      case OfflineCheck.unknownAccount:
        throw const NetworkFailure(_recoveryNeedsConnection);
    }
  }

  @override
  Future<String?> customRecoveryQuestion(String phone) =>
      offline.customQuestion(phone);

  /// Checks [currentPin] on this phone for the signed-in patient.
  Future<void> _checkCurrentPin(String currentPin) async {
    final AuthUser? user = await offline.rememberedUser();
    if (user == null) throw const SessionExpiredFailure('Not signed in');
    switch (await offline.verify(phone: user.phone, pin: currentPin)) {
      case OfflineCheck.match:
        return;
      case OfflineCheck.locked:
        final int? minutes = await offline.lockedFor(phone: user.phone);
        throw AccountLockedFailure(
          'Too many attempts. Try again in $minutes minutes',
          minutesRemaining: minutes,
        );
      case OfflineCheck.wrongPin:
      case OfflineCheck.unknownAccount:
        throw const InvalidCredentialsFailure('Current PIN is incorrect');
    }
  }

  @override
  Future<void> setCustomQuestion({
    required String currentPin,
    required String question,
    required String answer,
  }) async {
    await _checkCurrentPin(currentPin);
    await offline.rememberCustomQuestion(question: question, answer: answer);
  }

  @override
  Future<void> clearCustomQuestion({required String currentPin}) async {
    await _checkCurrentPin(currentPin);
    await offline.clearCustomQuestion();
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
      if (failure is InvalidCredentialsFailure ||
          failure is ValidationFailure) {
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
    final AuthUser? user =
        await offline.rememberedUser() ?? await local.cachedUser();
    if (user == null) {
      throw const SessionExpiredFailure('Sign in again to change your PIN');
    }
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
    final String? refreshToken = await local.refreshToken();
    if (refreshToken != null && await isOnline()) {
      try {
        // Best effort: the token expires on its own if this never arrives.
        await remote.logout(refreshToken).timeout(fallbackTimeout);
      } on Object {
        // Offline, slow or refused: the session still ends on this phone.
      }
    }
    await local.clearSession();
  }

  /// The server refused to renew the session. A patient signed in offline
  /// keeps going (the next sync signs them in again with their PIN); anyone
  /// else goes back to the sign-in screen.
  Future<void> expireSession() async {
    if (session.isActive) return;
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
