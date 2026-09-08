import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/activity/data/datasources/activity_local_datasource.dart';
import 'package:libu_care/features/activity/data/repositories/activity_repository_impl.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_database.dart';

class _MockSyncEnqueuer extends Mock implements SyncEnqueuer {}

void main() {
  late AppDatabase db;
  late _MockSyncEnqueuer sync;
  late ActivityRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(SyncEntityType.activity);
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    db = testDatabase();
    sync = _MockSyncEnqueuer();
    when(
      () => sync.enqueue(
        clientRecordId: any(named: 'clientRecordId'),
        entityType: any(named: 'entityType'),
        payload: any(named: 'payload'),
        recordedAt: any(named: 'recordedAt'),
      ),
    ).thenAnswer((_) async {});
    repository = ActivityRepositoryImpl(
      local: ActivityLocalDatasource(db),
      sync: sync,
    );
  });

  tearDown(() => db.close());

  test(
    'logging a session writes to Drift and enqueues the exact POST body — '
    'no other interaction happens, so no request is ever made from here',
    () async {
      final ActivitySession session = ActivitySession(
        clientRecordId: 'a',
        type: ActivityType.walking,
        durationMinutes: 30,
        intensity: Intensity.moderate,
        measuredAt: DateTime.utc(2026, 8, 30, 7),
        steps: 3000,
        note: 'evening walk',
      );

      await repository.log(session);

      final List<ActivitySession> stored = await repository
          .watchHistory()
          .first;
      expect(stored, hasLength(1));
      expect(stored.single.clientRecordId, 'a');
      expect(stored.single.type, ActivityType.walking);
      expect(stored.single.steps, 3000);

      final List<dynamic> captured = verify(
        () => sync.enqueue(
          clientRecordId: 'a',
          entityType: SyncEntityType.activity,
          payload: captureAny(named: 'payload'),
          recordedAt: session.measuredAt,
        ),
      ).captured;
      final Map<String, dynamic> payload =
          captured.single as Map<String, dynamic>;
      expect(payload['clientRecordId'], 'a');
      expect((payload['data'] as Map)['type'], 'WALKING');
      expect((payload['data'] as Map)['durationMinutes'], 30);
      expect((payload['data'] as Map)['steps'], 3000);
    },
  );

  test(
    'watchHistory converts stored rows back into entities, including enums',
    () async {
      await repository.log(
        ActivitySession(
          clientRecordId: 'b',
          type: ActivityType.cycling,
          durationMinutes: 45,
          intensity: Intensity.vigorous,
          measuredAt: DateTime.utc(2026, 8, 30),
          distanceMeters: 9500,
        ),
      );

      final ActivitySession result =
          (await repository.watchHistory().first).single;

      expect(result.type, ActivityType.cycling);
      expect(result.intensity, Intensity.vigorous);
      expect(result.distanceMeters, 9500);
      expect(result.steps, isNull);
    },
  );

  test('logging two sessions enqueues one sync record per session', () async {
    await repository.log(
      ActivitySession(
        clientRecordId: 'first',
        type: ActivityType.walking,
        durationMinutes: 20,
        intensity: Intensity.light,
        measuredAt: DateTime.utc(2026, 8, 29),
      ),
    );
    await repository.log(
      ActivitySession(
        clientRecordId: 'second',
        type: ActivityType.farming,
        durationMinutes: 60,
        intensity: Intensity.moderate,
        measuredAt: DateTime.utc(2026, 8, 30),
      ),
    );

    verify(
      () => sync.enqueue(
        clientRecordId: 'first',
        entityType: SyncEntityType.activity,
        payload: any(named: 'payload'),
        recordedAt: DateTime.utc(2026, 8, 29),
      ),
    ).called(1);
    verify(
      () => sync.enqueue(
        clientRecordId: 'second',
        entityType: SyncEntityType.activity,
        payload: any(named: 'payload'),
        recordedAt: DateTime.utc(2026, 8, 30),
      ),
    ).called(1);

    final List<ActivitySession> stored = await repository.watchHistory().first;
    expect(stored, hasLength(2));
  });
}
