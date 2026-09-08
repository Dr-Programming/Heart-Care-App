import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/activity/data/datasources/activity_remote_datasource.dart';
import 'package:libu_care/features/activity/data/models/activity_model.dart';

import '../../../helpers/fake_dio.dart';

ActivityModel _model({String clientRecordId = 'a'}) => ActivityModel(
  clientRecordId: clientRecordId,
  type: 'WALKING',
  durationMinutes: 30,
  intensity: 'MODERATE',
  steps: 3200,
  distanceMeters: 2400,
  measuredAt: DateTime.utc(2026, 7, 16, 6, 30),
  note: 'morning walk to the market',
);

Map<String, dynamic> _serverEcho({
  String id = 'e5c30011-1234-5678-9abc-def012345678',
  String clientRecordId = 'a',
  Map<String, dynamic> data = const <String, dynamic>{
    'type': 'WALKING',
    'durationMinutes': 30,
    'intensity': 'MODERATE',
    'steps': 3200,
    'distanceMeters': 2400,
  },
}) => <String, dynamic>{
  'id': id,
  'data': data,
  'measuredAt': '2026-07-16T06:30:00Z',
  'note': 'morning walk to the market',
  'clientRecordId': clientRecordId,
  'createdAt': '2026-07-16T06:30:02Z',
};

void main() {
  group('ActivityRemoteDatasource.log', () {
    test('POSTs exactly the whitelisted request shape', () async {
      final FakeDio fake = FakeDio()
        ..stub(
          ApiEndpoints.activities,
          FakeResponse.ok(_serverEcho(), message: 'Activity logged'),
        );
      final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
        fake.dio,
      );

      await datasource.log(_model());

      final Map<String, dynamic> sent = fake.requests.single.json;
      expect(sent.keys.toSet(), <String>{
        'clientRecordId',
        'measuredAt',
        'note',
        'data',
      });
      final Map<String, dynamic> data = (sent['data'] as Map).cast();
      expect(data.keys.toSet(), <String>{
        'type',
        'durationMinutes',
        'intensity',
        'steps',
        'distanceMeters',
      });
      expect(data['type'], 'WALKING');
      expect(data['durationMinutes'], 30);
      expect(data['intensity'], 'MODERATE');
      expect(data['steps'], 3200);
      expect(data['distanceMeters'], 2400);
    });

    test('omits steps, distance and note when the session has none', () async {
      final FakeDio fake = FakeDio()
        ..stub(
          ApiEndpoints.activities,
          FakeResponse.ok(
            _serverEcho(
              data: const <String, dynamic>{
                'type': 'STRETCHING',
                'durationMinutes': 10,
                'intensity': 'LIGHT',
              },
            ),
          ),
        );
      final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
        fake.dio,
      );
      final ActivityModel bare = ActivityModel(
        clientRecordId: 'a',
        type: 'STRETCHING',
        durationMinutes: 10,
        intensity: 'LIGHT',
        measuredAt: DateTime.utc(2026, 7, 16, 6, 30),
      );

      await datasource.log(bare);

      final Map<String, dynamic> sent = fake.requests.single.json;
      expect(sent.containsKey('note'), isFalse);
      final Map<String, dynamic> data = (sent['data'] as Map).cast();
      expect(data.containsKey('steps'), isFalse);
      expect(data.containsKey('distanceMeters'), isFalse);
    });

    test('unwraps the 200 envelope into the server-assigned model', () async {
      final FakeDio fake = FakeDio()
        ..stub(
          ApiEndpoints.activities,
          FakeResponse.ok(
            _serverEcho(
              id: 'server-id',
              data: const <String, dynamic>{
                'type': 'CYCLING',
                'durationMinutes': 45,
                'intensity': 'VIGOROUS',
              },
            ),
          ),
        );
      final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
        fake.dio,
      );

      final ActivityModel result = await datasource.log(_model());

      expect(result.serverId, 'server-id');
      expect(result.type, 'CYCLING');
      expect(result.durationMinutes, 45);
      expect(result.intensity, 'VIGOROUS');
      expect(result.steps, isNull);
    });

    test(
      'a 400 (e.g. duration out of range) throws a ValidationFailure',
      () async {
        final FakeDio fake = FakeDio()
          ..stub(
            ApiEndpoints.activities,
            FakeResponse.error(
              400,
              'durationMinutes: must be between 1 and 1440',
            ),
          );
        final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
          fake.dio,
        );

        await expectLater(
          () => datasource.log(_model()),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test('a transport failure throws a NetworkFailure', () async {
      final FakeDio fake = FakeDio()
        ..stub(ApiEndpoints.activities, FakeResponse.offline());
      final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
        fake.dio,
      );

      await expectLater(
        () => datasource.log(_model()),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('ActivityRemoteDatasource.fetchHistory', () {
    test('GETs with the from/to window formatted as plain dates', () async {
      final FakeDio fake = FakeDio()
        ..stub(ApiEndpoints.activities, FakeResponse.ok(<dynamic>[]));
      final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
        fake.dio,
      );

      await datasource.fetchHistory(
        from: DateTime.utc(2026, 7, 1),
        to: DateTime.utc(2026, 7, 31),
      );

      final RecordedRequest request = fake.requests.single;
      expect(request.queryParameters['from'], '2026-07-01');
      expect(request.queryParameters['to'], '2026-07-31');
    });

    test('omits from/to entirely when not given', () async {
      final FakeDio fake = FakeDio()
        ..stub(ApiEndpoints.activities, FakeResponse.ok(<dynamic>[]));
      final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
        fake.dio,
      );

      await datasource.fetchHistory();

      expect(fake.requests.single.queryParameters, isEmpty);
    });

    test(
      'parses each item in the list the same way as a logged echo',
      () async {
        final FakeDio fake = FakeDio()
          ..stub(
            ApiEndpoints.activities,
            FakeResponse.ok(<dynamic>[
              _serverEcho(
                id: 'id-2',
                clientRecordId: 'b',
                data: const <String, dynamic>{
                  'type': 'JOGGING',
                  'durationMinutes': 25,
                  'intensity': 'MODERATE',
                },
              ),
            ]),
          );
        final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
          fake.dio,
        );

        final List<ActivityModel> history = await datasource.fetchHistory();

        expect(history, hasLength(1));
        expect(history.single.type, 'JOGGING');
        expect(history.single.serverId, 'id-2');
        expect(history.single.clientRecordId, 'b');
      },
    );

    test(
      'an empty history responds with an empty list, not an error',
      () async {
        final FakeDio fake = FakeDio()
          ..stub(ApiEndpoints.activities, FakeResponse.ok(<dynamic>[]));
        final ActivityRemoteDatasource datasource = ActivityRemoteDatasource(
          fake.dio,
        );

        final List<ActivityModel> history = await datasource.fetchHistory();

        expect(history, isEmpty);
      },
    );
  });
}
