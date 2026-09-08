import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/activity/data/datasources/activity_local_datasource.dart';
import 'package:libu_care/features/activity/data/models/activity_model.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';

import '../../../helpers/test_database.dart';

ActivityModel _model({
  required String clientRecordId,
  required DateTime measuredAt,
  ActivityType type = ActivityType.walking,
  int durationMinutes = 30,
  Intensity intensity = Intensity.moderate,
  int? steps,
  double? distanceMeters,
  String? note,
}) {
  return ActivityModel(
    clientRecordId: clientRecordId,
    type: type.wire,
    durationMinutes: durationMinutes,
    intensity: intensity.wire,
    measuredAt: measuredAt,
    steps: steps,
    distanceMeters: distanceMeters,
    note: note,
  );
}

void main() {
  late AppDatabase db;
  late ActivityLocalDatasource datasource;

  setUp(() {
    db = testDatabase();
    datasource = ActivityLocalDatasource(db);
  });

  tearDown(() => db.close());

  test('a saved session round-trips every field', () async {
    final ActivityModel model = _model(
      clientRecordId: 'a',
      measuredAt: DateTime.utc(2026, 8, 30, 7, 0),
      type: ActivityType.cycling,
      durationMinutes: 45,
      intensity: Intensity.vigorous,
      steps: 4200,
      distanceMeters: 9500,
      note: 'evening ride',
    );

    await datasource.insert(model);
    final List<ActivityModel> history = await datasource.watchHistory().first;

    expect(history, hasLength(1));
    final ActivityModel saved = history.single;
    expect(saved.clientRecordId, 'a');
    expect(saved.type, 'CYCLING');
    expect(saved.durationMinutes, 45);
    expect(saved.intensity, 'VIGOROUS');
    expect(saved.steps, 4200);
    expect(saved.distanceMeters, 9500);
    expect(saved.note, 'evening ride');
    expect(saved.serverId, isNull);
  });

  test(
    're-inserting the same clientRecordId is a no-op, not a duplicate',
    () async {
      final ActivityModel model = _model(
        clientRecordId: 'retry-id',
        measuredAt: DateTime.utc(2026, 8, 30),
      );

      await datasource.insert(model);
      await datasource.insert(model);

      final List<ActivityModel> history = await datasource.watchHistory().first;
      expect(history, hasLength(1));
    },
  );

  test('history is newest-first', () async {
    await datasource.insert(
      _model(clientRecordId: 'oldest', measuredAt: DateTime.utc(2026, 8, 1)),
    );
    await datasource.insert(
      _model(clientRecordId: 'newest', measuredAt: DateTime.utc(2026, 8, 3)),
    );
    await datasource.insert(
      _model(clientRecordId: 'middle', measuredAt: DateTime.utc(2026, 8, 2)),
    );

    final List<ActivityModel> history = await datasource.watchHistory().first;

    expect(
      history.map((ActivityModel m) => m.clientRecordId).toList(),
      <String>['newest', 'middle', 'oldest'],
    );
  });

  test('from/to narrows the window on both ends, inclusive', () async {
    await datasource.insert(
      _model(clientRecordId: 'before', measuredAt: DateTime.utc(2026, 8, 24)),
    );
    await datasource.insert(
      _model(
        clientRecordId: 'window-start',
        measuredAt: DateTime.utc(2026, 8, 26),
      ),
    );
    await datasource.insert(
      _model(
        clientRecordId: 'inside-window',
        measuredAt: DateTime.utc(2026, 8, 28),
      ),
    );
    await datasource.insert(
      _model(
        clientRecordId: 'window-end',
        measuredAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await datasource.insert(
      _model(clientRecordId: 'after', measuredAt: DateTime.utc(2026, 9, 3)),
    );

    final List<ActivityModel> windowed = await datasource
        .watchHistory(
          from: DateTime.utc(2026, 8, 26),
          to: DateTime.utc(2026, 9, 1),
        )
        .first;

    expect(
      windowed.map((ActivityModel m) => m.clientRecordId).toSet(),
      <String>{'window-start', 'inside-window', 'window-end'},
    );
  });

  test(
    'watchHistory with no sessions yet returns an empty list, not an error',
    () async {
      final List<ActivityModel> history = await datasource.watchHistory().first;
      expect(history, isEmpty);
    },
  );
}
