import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';

import '../../../../helpers/fake_dio.dart';

void main() {
  test('register sends the documented body and unwraps a 200 envelope', () async {
    final fake = FakeDio();
    fake.stub(
      '/api/v1/auth/register',
      FakeResponse.ok(<String, dynamic>{
        'token': 'header.payload.signature',
        'user': <String, dynamic>{
          'id': 'u1',
          'name': 'Abebe Girma',
          'phone': '+251911234567',
          'preferredLanguage': 'en',
          'role': 'PATIENT',
        },
      }),
    );
    final ds = AuthRemoteDataSource(fake.dio);

    final result = await ds.register(
      phone: '+251911234567',
      pin: '1234',
      name: 'Abebe Girma',
      preferredLanguage: 'en',
    );

    expect(result.token, 'header.payload.signature');
    expect(result.user.name, 'Abebe Girma');
    expect(fake.requests.single.method, 'POST');
    expect(fake.requests.single.json, <String, dynamic>{
      'phone': '+251911234567',
      'pin': '1234',
      'name': 'Abebe Girma',
      'preferredLanguage': 'en',
    });
  });

  test('register does not treat a 201 as anything special (there is none)', () async {
    
    
    
  });

  test('login sends phone and pin, unwraps a 200 envelope', () async {
    final fake = FakeDio();
    fake.stub(
      '/api/v1/auth/login',
      FakeResponse.ok(<String, dynamic>{
        'token': 'header.payload.signature',
        'user': <String, dynamic>{
          'id': 'u1',
          'name': 'Abebe Girma',
          'phone': '+251911234567',
          'preferredLanguage': 'en',
          'role': 'PATIENT',
        },
      }),
    );
    final ds = AuthRemoteDataSource(fake.dio);

    final result = await ds.login(phone: '+251911234567', pin: '1234');

    expect(result.token, 'header.payload.signature');
    expect(fake.requests.single.json, <String, dynamic>{
      'phone': '+251911234567',
      'pin': '1234',
    });
  });

  test('login propagates a DioException on a non-2xx response', () async {
    final fake = FakeDio();
    fake.stub('/api/v1/auth/login', FakeResponse.error(401, 'Invalid phone or PIN'));
    final ds = AuthRemoteDataSource(fake.dio);

    await expectLater(
      () => ds.login(phone: '+251911234567', pin: '0000'),
      throwsA(isA<DioException>()),
    );
  });

  test('me attaches the bearer token and unwraps a UserModel', () async {
    final fake = FakeDio(token: 'header.payload.signature');
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
    final ds = AuthRemoteDataSource(fake.dio);

    final result = await ds.me();

    expect(result.id, 'u1');
    expect(fake.requests.single.method, 'GET');
  });
}
