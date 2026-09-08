import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/models/auth_response_model.dart';
import 'package:libu_care/features/auth/data/models/user_model.dart';

import '../../../helpers/fake_dio.dart';

void main() {
  group('AuthRemoteDataSource.register', () {
    test('sends all four fields and unwraps a 200 response', () async {
      final FakeDio fake = FakeDio();
      fake.stub(
        '/api/v1/auth/register',
        FakeResponse.ok(<String, dynamic>{
          'token': 'jwt-token',
          'user': <String, dynamic>{
            'id': 'u1',
            'name': 'Abebe Girma',
            'phone': '+251911234567',
            'preferredLanguage': 'en',
            'role': 'PATIENT',
          },
        }, message: 'Registered'),
      );
      final AuthRemoteDataSource ds = AuthRemoteDataSource(fake.dio);

      final AuthResponseModel result = await ds.register(
        phone: '+251911234567',
        pin: '1234',
        name: 'Abebe Girma',
        preferredLanguage: 'en',
      );

      expect(fake.requests.single.method, 'POST');
      expect(fake.requests.single.json, <String, dynamic>{
        'phone': '+251911234567',
        'pin': '1234',
        'name': 'Abebe Girma',
        'preferredLanguage': 'en',
      });
      expect(result.token, 'jwt-token');
      expect(result.user.id, 'u1');
      expect(result.user.role, 'PATIENT');
    });
  });

  group('AuthRemoteDataSource.login', () {
    test('sends only phone and pin, and unwraps a 200 response', () async {
      final FakeDio fake = FakeDio();
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.ok(<String, dynamic>{
          'token': 'jwt-token',
          'user': <String, dynamic>{
            'id': 'u1',
            'name': 'Abebe Girma',
            'phone': '+251911234567',
            'preferredLanguage': 'en',
            'role': 'PATIENT',
          },
        }, message: 'Logged in'),
      );
      final AuthRemoteDataSource ds = AuthRemoteDataSource(fake.dio);

      final AuthResponseModel result = await ds.login(
        phone: '+251911234567',
        pin: '1234',
      );

      expect(fake.requests.single.method, 'POST');
      expect(fake.requests.single.json, <String, dynamic>{
        'phone': '+251911234567',
        'pin': '1234',
      });
      expect(result.token, 'jwt-token');
      expect(result.user.name, 'Abebe Girma');
    });
  });

  group('AuthRemoteDataSource.me', () {
    test('fetches and unwraps the current user', () async {
      final FakeDio fake = FakeDio();
      fake.stub(
        '/api/v1/auth/me',
        FakeResponse.ok(<String, dynamic>{
          'id': 'u1',
          'name': 'Abebe Girma',
          'phone': '+251911234567',
          'preferredLanguage': 'en',
          'role': 'PATIENT',
        }),
      );
      final AuthRemoteDataSource ds = AuthRemoteDataSource(fake.dio);

      final UserModel result = await ds.me();

      expect(fake.requests.single.method, 'GET');
      expect(result.id, 'u1');
      expect(result.phone, '+251911234567');
    });
  });
}
