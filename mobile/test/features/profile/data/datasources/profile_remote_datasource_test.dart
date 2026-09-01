import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ProfileRemoteDatasource datasource;

  setUp(() {
    dio = MockDio();
    datasource = ProfileRemoteDatasource(dio);
  });

  Response<Map<String, dynamic>> envelopeResponse(
    Map<String, dynamic>? data, {
    int statusCode = 200,
  }) {
    return Response(
      requestOptions: RequestOptions(path: ApiEndpoints.patientMe),
      statusCode: statusCode,
      data: {
        'success': true,
        'data': data,
        'message': '',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  group('getProfile', () {
    test('returns an empty model when the server has no profile yet',
        () async {
      when(() => dio.get(ApiEndpoints.patientMe))
          .thenAnswer((_) async => envelopeResponse(null));

      final result = await datasource.getProfile();

      expect(result.birthYear, isNull);
      expect(result.comorbidities, isEmpty);
    });

    test('decodes a populated profile from the envelope', () async {
      when(() => dio.get(ApiEndpoints.patientMe)).thenAnswer(
        (_) async => envelopeResponse({
          'birthYear': 1965,
          'preferredLanguage': 'am',
          'heightCm': 172.0,
          'chdStage': 'Coronary artery disease',
          'diseaseHistory': null,
          'comorbidities': ['Diabetes'],
          'managementPlan': null,
          'goals': null,
        }),
      );

      final result = await datasource.getProfile();

      expect(result.birthYear, 1965);
      expect(result.preferredLanguage, 'am');
      expect(result.heightCm, 172.0);
      expect(result.comorbidities, ['Diabetes']);
    });

    test('throws a NetworkFailure on a connection error', () async {
      when(() => dio.get(ApiEndpoints.patientMe)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.patientMe),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(() => datasource.getProfile(), throwsA(isA<Exception>()));
    });
  });

  group('saveProfile', () {
    test('sends the full model and returns the server response', () async {
      const model = PatientProfileModel(birthYear: 1965, heightCm: 172.0);

      when(
        () => dio.put(
          ApiEndpoints.patientMe,
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => envelopeResponse({
          'birthYear': 1965,
          'preferredLanguage': null,
          'heightCm': 172.0,
          'chdStage': null,
          'diseaseHistory': null,
          'comorbidities': [],
          'managementPlan': null,
          'goals': null,
        }),
      );

      final result = await datasource.saveProfile(model);

      expect(result.birthYear, 1965);
      expect(result.heightCm, 172.0);

      final captured = verify(
        () => dio.put(ApiEndpoints.patientMe, data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(captured['birthYear'], 1965);
    });

    test('throws on a server error response', () async {
      when(
        () => dio.put(ApiEndpoints.patientMe, data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.patientMe),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.patientMe),
            statusCode: 500,
            data: {'success': false, 'message': 'Server error'},
          ),
        ),
      );

      expect(
        () => datasource.saveProfile(const PatientProfileModel()),
        throwsA(isA<Exception>()),
      );
    });
  });
}