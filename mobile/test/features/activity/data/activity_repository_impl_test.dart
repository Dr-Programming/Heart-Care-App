import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/activity/data/datasources/activity_local_datasource.dart';
import 'package:libu_care/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:libu_care/features/activity/domain/entities/activity_entry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncQueueDao queue;
  late ActivityRepositoryImpl repo;

  setUp(() {
    db = testDatabase();
    queue = SyncQueueDao(db);
    repo = ActivityRepositoryImpl(
      local: ActivityLocalDataSource(db),
      syncEnqueuer: queue,
    );
  });

  tearDown(() => db.close());

  test('logging saves on the phone and queues it for the server', () async {
    final ActivityEntry entry = await repo.log(
      type: ActivityType.walking,
      durationMinutes: 30,
      intensity: Intensity.moderate,
      steps: 4200,
      note: 'Evening walk',
      measuredAt: DateTime.utc(2026, 9, 30, 15),
    );

    expect(await repo.history(), <ActivityEntry>[entry]);
    final SyncQueueEntry queued = (await queue.pending()).single;
    expect(queued.entityType, 'ACTIVITY');
    final Map<String, dynamic> payload =
        jsonDecode(queued.payloadJson) as Map<String, dynamic>;
    expect(payload['data'], <String, dynamic>{
      'type': 'WALKING',
      'durationMinutes': 30,
      'intensity': 'MODERATE',
      'steps': 4200,
    });
    expect(payload['note'], 'Evening walk');
    expect(payload['measuredAt'], isNotNull);
  });

  test('optional fields are left out rather than sent as null', () async {
    await repo.log(
      type: ActivityType.household,
      durationMinutes: 20,
      intensity: Intensity.light,
    );

    final Map<String, dynamic> payload = jsonDecode(
      (await queue.pending()).single.payloadJson,
    ) as Map<String, dynamic>;
    expect((payload['data'] as Map<String, dynamic>).keys, <String>[
      'type',
      'durationMinutes',
      'intensity',
    ]);
    expect(payload.containsKey('note'), isFalse);
  });

  test('history is newest first', () async {
    await repo.log(
      type: ActivityType.walking,
      durationMinutes: 10,
      intensity: Intensity.light,
      measuredAt: DateTime.utc(2026, 9, 28),
    );
    await repo.log(
      type: ActivityType.cycling,
      durationMinutes: 40,
      intensity: Intensity.vigorous,
      measuredAt: DateTime.utc(2026, 9, 30),
    );

    expect(
      (await repo.history()).map((ActivityEntry e) => e.type),
      <ActivityType>[ActivityType.cycling, ActivityType.walking],
    );
  });
}
