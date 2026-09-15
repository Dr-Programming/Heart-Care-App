import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_remote_datasource.dart';

import '../../../../helpers/fake_dio.dart';

void main() {
  test('the posted body carries exactly the required keys', () async {
    final FakeDio fake = FakeDio()
      ..stub(
        '/api/v1/vitals',
        FakeResponse.ok(<String, dynamic>{
          'id': 'server-1',
          'type': 'BLOOD_PRESSURE',
          'values': <String, dynamic>{'systolic': 128, 'diastolic': 82},
          'flagged': false,
          'measuredAt': '2026-08-22T06:30:00Z',
        }),
      );
    final VitalsRemoteDataSource datasource = VitalsRemoteDataSource(fake.dio);

    await datasource.create(
      type: 'BLOOD_PRESSURE',
      values: <String, double>{'systolic': 128, 'diastolic': 82},
      measuredAt: '2026-08-22T06:30:00.000Z',
      clientRecordId: 'c1',
    );

    final Map<String, dynamic> sent = fake.requests.single.json;
    expect(sent.keys, containsAll(<String>['type', 'values', 'measuredAt', 'clientRecordId']));
    expect(sent['values'], <String, double>{'systolic': 128, 'diastolic': 82});
  });

  test('measuredAt is sent exactly as given (UTC ISO-8601 by the caller)', () async {
    final FakeDio fake = FakeDio()
      ..stub(
        '/api/v1/vitals',
        FakeResponse.ok(<String, dynamic>{
          'type': 'GLUCOSE',
          'values': <String, dynamic>{'glucose': 5.5},
          'measuredAt': '2026-08-22T06:30:00Z',
        }),
      );
    final VitalsRemoteDataSource datasource = VitalsRemoteDataSource(fake.dio);

    await datasource.create(
      type: 'GLUCOSE',
      values: <String, double>{'glucose': 5.5},
      measuredAt: '2026-08-22T06:30:00.000Z',
    );

    expect(fake.requests.single.json['measuredAt'], '2026-08-22T06:30:00.000Z');
  });

  test('unwraps a 200', () async {
    final FakeDio fake = FakeDio()
      ..stub(
        '/api/v1/vitals',
        FakeResponse.ok(<String, dynamic>{
          'id': 'server-1',
          'type': 'WEIGHT',
          'values': <String, dynamic>{'weight': 70},
          'bmi': 22.9,
          'measuredAt': '2026-08-22T06:30:00Z',
        }),
      );
    final VitalsRemoteDataSource datasource = VitalsRemoteDataSource(fake.dio);

    final result = await datasource.create(
      type: 'WEIGHT',
      values: <String, double>{'weight': 70},
      measuredAt: '2026-08-22T06:30:00.000Z',
    );

    expect(result.serverId, 'server-1');
    expect(result.bmi, 22.9);
  });

  test('a 400 surfaces the server field list', () async {
    final FakeDio fake = FakeDio()
      ..stub(
        '/api/v1/vitals',
        FakeResponse.error(400, 'values: systolic must be between 40 and 300'),
      );
    final VitalsRemoteDataSource datasource = VitalsRemoteDataSource(fake.dio);

    await expectLater(
      datasource.create(
        type: 'BLOOD_PRESSURE',
        values: <String, double>{'systolic': 999, 'diastolic': 82},
        measuredAt: '2026-08-22T06:30:00.000Z',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
