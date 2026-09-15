import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';

import '../../../../helpers/fake_dio.dart';

void main() {
  test('getProfile parses the all-null skeleton without throwing', () async {
    final fake = FakeDio();
    fake.stub('/api/v1/patients/me', FakeResponse.ok(const <String, dynamic>{
      'birthYear': null, 'preferredLanguage': null, 'heightCm': null,
      'chdStage': null, 'diseaseHistory': null, 'comorbidities': <dynamic>[],
      'managementPlan': null, 'goals': null,
    }));
    final ds = ProfileRemoteDataSource(fake.dio);

    final result = await ds.getProfile();

    expect(result.birthYear, isNull);
    expect(result.comorbidities, isEmpty);
    expect(fake.requests.single.method, 'GET');
  });

  test('saveProfile PUTs every field, including the ones that are null', () async {
    final fake = FakeDio();
    fake.stub('/api/v1/patients/me', FakeResponse.ok(const <String, dynamic>{
      'birthYear': 1968, 'preferredLanguage': 'en', 'heightCm': 172.0,
      'chdStage': 'Coronary artery disease', 'diseaseHistory': null,
      'comorbidities': <dynamic>['diabetes'], 'managementPlan': null, 'goals': null,
    }));
    final ds = ProfileRemoteDataSource(fake.dio);
    const model = PatientProfileModel(
      birthYear: 1968, preferredLanguage: 'en', heightCm: 172,
      chdStage: 'Coronary artery disease', diseaseHistory: null,
      comorbidities: <String>['diabetes'], managementPlan: null, goals: null,
    );

    final result = await ds.saveProfile(model);

    expect(result.birthYear, 1968);
    expect(fake.requests.single.method, 'PUT');
    expect(fake.requests.single.json.containsKey('diseaseHistory'), isTrue);
    expect(fake.requests.single.json.containsKey('managementPlan'), isTrue);
  });

  test('saveProfile propagates a DioException on a 400', () async {
    final fake = FakeDio();
    fake.stub('/api/v1/patients/me', FakeResponse.error(400, 'birthYear: must be between 1900 and 2100'));
    final ds = ProfileRemoteDataSource(fake.dio);
    const model = PatientProfileModel(
      birthYear: 1500, preferredLanguage: null, heightCm: null, chdStage: null,
      diseaseHistory: null, comorbidities: <String>[], managementPlan: null, goals: null,
    );

    await expectLater(() => ds.saveProfile(model), throwsA(isA<DioException>()));
  });
}
