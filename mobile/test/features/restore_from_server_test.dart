import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/core/sync/history_window.dart';
import 'package:libu_care/features/activity/data/datasources/activity_local_datasource.dart';
import 'package:libu_care/features/activity/data/datasources/activity_remote_datasource.dart';
import 'package:libu_care/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:libu_care/features/activity/domain/entities/activity_entry.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_local_datasource.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_remote_datasource.dart';
import 'package:libu_care/features/symptoms/data/repositories/symptom_repository_impl.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_local_datasource.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_remote_datasource.dart';
import 'package:libu_care/features/vitals/data/repositories/vitals_repository_impl.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

import '../helpers/fake_dio.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncQueueDao queue;
  late FakeDio http;
  late bool online;

  setUp(() {
    db = testDatabase();
    queue = SyncQueueDao(db);
    http = FakeDio();
    online = true;
  });

  tearDown(() => db.close());

  group('vitals', () {
    VitalsRepositoryImpl repo() => VitalsRepositoryImpl(
      local: VitalsLocalDataSource(db),
      syncEnqueuer: queue,
      remote: VitalsRemoteDataSource(http.dio),
      isOnline: () async => online,
    );

    test('readings on the server come back to the phone, once', () async {
      http.stub(
        '/api/v1/vitals',
        FakeResponse.ok(<dynamic>[
          <String, dynamic>{
            'id': 'srv-v1',
            'type': 'BLOOD_PRESSURE',
            'values': <String, dynamic>{'systolic': 182, 'diastolic': 100},
            'flagged': true,
            'measuredAt': '2026-10-01T11:40:00Z',
            'clientRecordId': 'v1',
          },
        ]),
      );

      await repo().restoreFromServer();
      await repo().restoreFromServer();

      final List<VitalReading> readings = await repo().history();
      expect(readings, hasLength(1));
      expect(readings.single.type, VitalType.bloodPressure);
      expect(readings.single.values['systolic'], 182);
      expect(await queue.pending(), isEmpty);
    });

    test('asks for the last week first, then the rest of the month', () async {
      http.stub('/api/v1/vitals', FakeResponse.ok(<dynamic>[]));

      await repo().restoreFromServer();

      final List<DayRange> ranges = restoreRanges();
      final List<RecordedRequest> asked = http.requests
          .where((RecordedRequest r) => r.path.endsWith('/vitals'))
          .toList();
      expect(asked.map((RecordedRequest r) => r.queryParameters), <
        Map<String, dynamic>
      >[
        <String, dynamic>{'from': ranges[0].fromParam, 'to': ranges[0].toParam},
        <String, dynamic>{'from': ranges[1].fromParam, 'to': ranges[1].toParam},
      ]);
    });

    test('offline does nothing', () async {
      online = false;
      await repo().restoreFromServer();
      expect(http.requests, isEmpty);
    });
  });

  group('symptoms', () {
    SymptomRepositoryImpl repo() => SymptomRepositoryImpl(
      local: SymptomLocalDataSource(db),
      syncEnqueuer: queue,
      remote: SymptomRemoteDataSource(http.dio),
      isOnline: () async => online,
    );

    test(
      'check-ins come back with their assessment worked out again',
      () async {
        http.stub(
          '/api/v1/symptoms',
          FakeResponse.ok(<dynamic>[
            <String, dynamic>{
              'id': 'srv-s1',
              'data': <String, dynamic>{
                'chestPain': <String, dynamic>{'present': false},
                'shortnessOfBreath': 'MILD',
                'heartRate': 76,
                'bloodPressure': <String, dynamic>{
                  'systolic': 128,
                  'diastolic': 82,
                },
                'swelling': false,
                'energyLevel': 7,
              },
              'measuredAt': '2026-10-01T11:46:00Z',
              'clientRecordId': 's1',
            },
          ]),
        );

        await repo().restoreFromServer();
        await repo().restoreFromServer();

        final SymptomCheckIn checkIn = (await repo().history()).single;
        expect(checkIn.shortnessOfBreath, 'MILD');
        expect(checkIn.overall, Severity.monitor);
        expect(await queue.pending(), isEmpty);
      },
    );
  });

  group('activity', () {
    ActivityRepositoryImpl repo() => ActivityRepositoryImpl(
      local: ActivityLocalDataSource(db),
      syncEnqueuer: queue,
      remote: ActivityRemoteDataSource(http.dio),
      isOnline: () async => online,
    );

    test('activities come back from the server, once', () async {
      http.stub(
        '/api/v1/activities',
        FakeResponse.ok(<dynamic>[
          <String, dynamic>{
            'id': 'srv-a1',
            'data': <String, dynamic>{
              'type': 'FARMING',
              'durationMinutes': 45,
              'intensity': 'MODERATE',
            },
            'measuredAt': '2026-10-01T11:47:00Z',
            'note': 'Field work',
            'clientRecordId': 'a1',
          },
        ]),
      );

      await repo().restoreFromServer();
      await repo().restoreFromServer();

      final ActivityEntry entry = (await repo().history()).single;
      expect(entry.type, ActivityType.farming);
      expect(entry.durationMinutes, 45);
      expect(entry.note, 'Field work');
      expect(await queue.pending(), isEmpty);
    });
  });
}
