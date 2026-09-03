import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/models/auth_response_model.dart';
import 'package:libu_care/features/auth/data/models/user_model.dart';
import 'package:libu_care/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}
class MockLocal extends Mock implements AuthLocalDataSource {}

const UserModel _model = UserModel(
  id: '3f2a9c1e', name: 'Abebe Bekele', phone: '+251911234567',
  preferredLanguage: 'am', role: 'PATIENT',
);
const AuthResponseModel _auth = AuthResponseModel(token: 'jwt-abc', user: _model);

DioException _dioError(int status, String message) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: <String, dynamic>{
          'success': false, 'data': null, 'message': message,
          'timestamp': '2026-09-03T10:00:00Z',
        },
      ),
    );

void main() {
  late MockRemote remote;
  late MockLocal local;

  AuthRepositoryImpl build({bool online = true}) =>
      AuthRepositoryImpl(remote, local, isOnline: () async => online);

  setUp(() {
    remote = MockRemote();
    local = MockLocal();
    registerFallbackValue(_model);
    when(() => local.saveSession(
        token: any(named: 'token'), user: any(named: 'user'))).thenAnswer((_) async {});
    when(() => local.cacheUser(any())).thenAnswer((_) async {});
    when(() => local.clear()).thenAnswer((_) async {});
  });

  group('login', () {
    test('stores the session and returns the user', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenAnswer((_) async => _auth);
      final user = await build().login(phone: '+251911234567', pin: '1234');
      expect(user.name, 'Abebe Bekele');
      verify(() => local.saveSession(token: 'jwt-abc', user: _model)).called(1);
    });

    test('fails fast with NetworkFailure when offline, without calling the API', () async {
      expect(
        () => build(online: false).login(phone: '+251911234567', pin: '1234'),
        throwsA(isA<NetworkFailure>()),
      );
      verifyNever(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')));
    });

    test('maps 401 to InvalidCredentialsFailure', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenThrow(_dioError(401, 'Invalid phone or PIN'));
      expect(
        () => build().login(phone: '+251911234567', pin: '9999'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });

    test('maps 423 to AccountLockedFailure carrying the minutes', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenThrow(_dioError(423, 'Too many failed attempts. Try again in 15 minutes.'));
      try {
        await build().login(phone: '+251911234567', pin: '9999');
        fail('expected a failure');
      } on AccountLockedFailure catch (f) {
        expect(f.minutesRemaining, 15);
      }
    });

    test('does not store a session when login fails', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenThrow(_dioError(401, 'Invalid phone or PIN'));
      await expectLater(
        build().login(phone: '+251911234567', pin: '9999'),
        throwsA(isA<Failure>()),
      );
      verifyNever(() => local.saveSession(
          token: any(named: 'token'), user: any(named: 'user')));
    });
  });

  group('register', () {
    test('sends the language code and auto-logs-in', () async {
      when(() => remote.register(
            phone: any(named: 'phone'), pin: any(named: 'pin'),
            name: any(named: 'name'), languageCode: any(named: 'languageCode'),
          )).thenAnswer((_) async => _auth);
      await build().register(
        phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
        language: AppLanguage.am,
      );
      verify(() => remote.register(
            phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
            languageCode: 'am',
          )).called(1);
      verify(() => local.saveSession(token: 'jwt-abc', user: _model)).called(1);
    });

    test('maps 409 to PhoneAlreadyRegisteredFailure', () async {
      when(() => remote.register(
            phone: any(named: 'phone'), pin: any(named: 'pin'),
            name: any(named: 'name'), languageCode: any(named: 'languageCode'),
          )).thenThrow(_dioError(409, 'Phone already registered'));
      expect(
        () => build().register(
          phone: '+251911234567', pin: '1234', name: 'A', language: AppLanguage.en,
        ),
        throwsA(isA<PhoneAlreadyRegisteredFailure>()),
      );
    });
  });

  group('getMe', () {
    test('refreshes the cache on success', () async {
      when(() => remote.me()).thenAnswer((_) async => _model);
      final user = await build().getMe();
      expect(user.id, '3f2a9c1e');
      verify(() => local.cacheUser(_model)).called(1);
    });

    test('maps 401 to SessionExpiredFailure, not bad credentials', () async {
      when(() => remote.me()).thenThrow(_dioError(401, 'Unauthorized'));
      expect(build().getMe(), throwsA(isA<SessionExpiredFailure>()));
    });
  });

  group('session', () {
    test('cachedUser reads through to local storage', () async {
      when(() => local.readUser()).thenAnswer((_) async => _model);
      expect((await build().cachedUser())!.name, 'Abebe Bekele');
    });

    test('hasValidSession is false with no token', () async {
      when(() => local.readToken()).thenAnswer((_) async => null);
      expect(await build().hasValidSession(), isFalse);
    });

    test('hasValidSession is false for an unreadable token', () async {
      when(() => local.readToken()).thenAnswer((_) async => 'garbage');
      expect(await build().hasValidSession(), isFalse);
    });

    test('logout clears storage', () async {
      await build().logout();
      verify(() => local.clear()).called(1);
    });
  });
}
