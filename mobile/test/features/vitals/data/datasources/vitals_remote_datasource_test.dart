import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_remote_datasource.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';

import '../../../../helpers/fake_dio.dart';

void main() {
  late FakeDio fakeDio;
  late VitalsRemoteDataSource dataSource;

  setUp(() {
    fakeDio = FakeDio();
    dataSource = VitalsRemoteDataSource(fakeDio.dio);
  });

  group('post', () {
    final VitalModel model = VitalModel(
      clientRecordId: 'crid-1',
      type: 'BLOOD_PRESSURE',
      values: <String, double>{'systolic': 190, 'diastolic': 100},
      flagged: true,
      measuredAt: DateTime.utc(2026, 8, 30, 8, 15),
    );

    test(
      'posts exactly the required keys, with UTC ISO-8601 measuredAt',
      () async {
        fakeDio.stub(
          '/api/v1/vitals',
          FakeResponse.ok(<String, dynamic>{
            'id': 'server-uuid',
            'clientRecordId': 'crid-1',
            'type': 'BLOOD_PRESSURE',
            'values': <String, dynamic>{'systolic': 190, 'diastolic': 100},
            'flagged': true,
            'measuredAt': '2026-08-30T08:15:00Z',
          }),
        );

        await dataSource.post(model);

        final Map<String, dynamic> sent = fakeDio.requests.single.json;
        expect(sent.keys, <String>{
          'clientRecordId',
          'type',
          'values',
          'measuredAt',
        });
        expect(sent['measuredAt'], '2026-08-30T08:15:00.000Z');
      },
    );

    test('unwraps a 200 into a VitalModel', () async {
      fakeDio.stub(
        '/api/v1/vitals',
        FakeResponse.ok(<String, dynamic>{
          'id': 'server-uuid',
          'clientRecordId': 'crid-1',
          'type': 'BLOOD_PRESSURE',
          'values': <String, dynamic>{'systolic': 190, 'diastolic': 100},
          'flagged': true,
          'measuredAt': '2026-08-30T08:15:00Z',
        }),
      );

      final VitalModel result = await dataSource.post(model);
      expect(result.serverId, 'server-uuid');
      expect(result.flagged, isTrue);
    });

    test(
      "a 400 surfaces the server's field list as a ValidationFailure",
      () async {
        fakeDio.stub(
          '/api/v1/vitals',
          FakeResponse.error(400, 'systolic: must exceed diastolic'),
        );

        await expectLater(
          dataSource.post(model),
          throwsA(
            isA<ValidationFailure>().having(
              (ValidationFailure f) => f.message,
              'message',
              'systolic: must exceed diastolic',
            ),
          ),
        );
      },
    );
  });

  group('getHistory', () {
    test('unwraps a 200 list into VitalModels', () async {
      fakeDio.stub(
        '/api/v1/vitals',
        FakeResponse.ok(<dynamic>[
          <String, dynamic>{
            'id': 's1',
            'clientRecordId': 'c1',
            'type': 'GLUCOSE',
            'values': <String, dynamic>{'glucose': 5.5},
            'flagged': false,
            'measuredAt': '2026-08-29T08:00:00Z',
          },
        ]),
      );

      final List<VitalModel> results = await dataSource.getHistory();
      expect(results, hasLength(1));
      expect(results.single.type, 'GLUCOSE');
    });

    test('sends type/from/to as query parameters when given', () async {
      fakeDio.stub('/api/v1/vitals', FakeResponse.ok(const <dynamic>[]));

      await dataSource.getHistory(
        type: 'WEIGHT',
        from: '2026-08-01',
        to: '2026-08-30',
      );

      expect(fakeDio.requests.single.queryParameters, <String, dynamic>{
        'type': 'WEIGHT',
        'from': '2026-08-01',
        'to': '2026-08-30',
      });
    });
  });
}
