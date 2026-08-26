import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/datasources/medication_remote_datasource.dart';

import '../../../../helpers/fake_dio.dart';

void main() {
  late FakeDio fake;
  late MedicationRemoteDataSource datasource;

  setUp(() {
    fake = FakeDio();
    datasource = MedicationRemoteDataSource(fake.dio);
  });

  test('create sends the documented body and unwraps a 200', () async {
    fake.stub(
      '/api/v1/medications',
      FakeResponse.ok(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Atorvastatin',
        'doseMg': 20.0,
        'frequency': 'ONCE_DAILY',
        'scheduleTimes': <String>['08:00'],
        'active': true,
        'clientRecordId': 'client-1',
        'createdAt': '2026-08-25T08:00:00Z',
        'updatedAt': '2026-08-25T08:00:00Z',
      }, message: 'Medication created'),
    );

    final result = await datasource.create(
      name: 'Atorvastatin',
      doseMg: 20,
      frequency: 'ONCE_DAILY',
      scheduleTimes: const <String>['08:00'],
      clientRecordId: 'client-1',
    );

    expect(result.id, 'srv-1');
    final sent = fake.requests.single;
    expect(sent.method, 'POST');
    expect(sent.json['name'], 'Atorvastatin');
    expect(sent.json['clientRecordId'], 'client-1');
  });

  test('update PUTs a full replace to /medications/{id}', () async {
    fake.stub(
      '/api/v1/medications/srv-1',
      FakeResponse.ok(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Atorvastatin 40mg',
        'doseMg': 40.0,
        'frequency': 'ONCE_DAILY',
        'scheduleTimes': <String>['08:00'],
        'active': true,
        'clientRecordId': 'client-1',
      }, message: 'Medication updated'),
    );

    final result = await datasource.update(
      'srv-1',
      name: 'Atorvastatin 40mg',
      doseMg: 40,
      frequency: 'ONCE_DAILY',
      scheduleTimes: const <String>['08:00'],
      active: true,
    );

    expect(result.doseMg, 40.0);
    expect(fake.requests.single.method, 'PUT');
  });

  test('deactivate DELETEs /medications/{id}', () async {
    fake.stub(
      '/api/v1/medications/srv-1',
      FakeResponse.ok(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Atorvastatin',
        'doseMg': 20.0,
        'frequency': 'ONCE_DAILY',
        'scheduleTimes': <String>['08:00'],
        'active': false,
        'clientRecordId': 'client-1',
      }, message: 'Medication deactivated'),
    );

    final result = await datasource.deactivate('srv-1');

    expect(result.active, isFalse);
    expect(fake.requests.single.method, 'DELETE');
  });

  test('logDose POSTs to /medications/{id}/doses', () async {
    fake.stub(
      '/api/v1/medications/srv-1/doses',
      FakeResponse.ok(<String, dynamic>{
        'id': 'dose-1',
        'medicationId': 'srv-1',
        'scheduledDate': '2026-08-25',
        'status': 'TAKEN',
        'clientRecordId': 'dose-client-1',
      }, message: 'Dose logged'),
    );

    final result = await datasource.logDose(
      'srv-1',
      status: 'TAKEN',
      scheduledDate: '2026-08-25',
      clientRecordId: 'dose-client-1',
    );

    expect(result.status, 'TAKEN');
    expect(fake.requests.single.method, 'POST');
  });

  test('doseLogs with an unknown-but-valid medication id returns an empty list, not an error', () async {
    fake.stub('/api/v1/dose-logs', FakeResponse.ok(<dynamic>[]));

    final result = await datasource.doseLogs(medicationId: 'no-such-id');

    expect(result, isEmpty);
  });

  test('list passes includeInactive as a query parameter', () async {
    fake.stub('/api/v1/medications', FakeResponse.ok(<dynamic>[]));

    await datasource.list(includeInactive: true);

    expect(fake.requests.single.queryParameters['includeInactive'], 'true');
  });
}
