import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _envelope(Object? data, {String message = 'OK'}) => {
      'success': true, 'data': data, 'message': message,
      'timestamp': '2026-09-03T10:00:00Z',
    };

const Map<String, dynamic> _userJson = {
  'id': '3f2a9c1e', 'name': 'Abebe Bekele', 'phone': '+251911234567',
  'preferredLanguage': 'am', 'role': 'PATIENT',
};

void main() {
  late Dio dio;
  late _StubAdapter adapter;
  late AuthRemoteDataSource source;

  void serve(Map<String, dynamic> body, {int status = 200}) {
    adapter = _StubAdapter(status, body);
    dio.httpClientAdapter = adapter;
  }

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://test.local',
      validateStatus: (int? s) => s != null && s < 400,
    ));
    source = AuthRemoteDataSource(dio);
  });

  test('register posts the four identity fields and unwraps token + user', () async {
    serve(_envelope({'token': 'jwt-abc', 'user': _userJson}, message: 'Registered'));
    final result = await source.register(
      phone: '+251911234567', pin: '1234', name: 'Abebe Bekele', languageCode: 'am',
    );
    expect(result.token, 'jwt-abc');
    expect(result.user.name, 'Abebe Bekele');
    final sent = adapter.lastRequest!;
    expect(sent.path, '/api/v1/auth/register');
    expect(sent.data, {
      'phone': '+251911234567', 'pin': '1234', 'name': 'Abebe Bekele',
      'preferredLanguage': 'am',
    });
  });

  test('register accepts 200, because this API never returns 201', () async {
    serve(_envelope({'token': 't', 'user': _userJson}), status: 200);
    expect((await source.register(
      phone: '+251911234567', pin: '1234', name: 'A', languageCode: 'en',
    )).token, 't');
  });

  test('login posts only phone and pin', () async {
    serve(_envelope({'token': 'jwt-xyz', 'user': _userJson}, message: 'Logged in'));
    final result = await source.login(phone: '+251911234567', pin: '1234');
    expect(result.token, 'jwt-xyz');
    expect(adapter.lastRequest!.path, '/api/v1/auth/login');
    expect(adapter.lastRequest!.data, {'phone': '+251911234567', 'pin': '1234'});
  });

  test('me unwraps the user directly from data', () async {
    serve(_envelope(_userJson));
    final user = await source.me();
    expect(user.id, '3f2a9c1e');
    expect(user.preferredLanguage, 'am');
    expect(adapter.lastRequest!.path, '/api/v1/auth/me');
  });
}
