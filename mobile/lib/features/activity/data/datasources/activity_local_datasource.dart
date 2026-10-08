import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/activity_entry.dart';

class ActivityLocalDataSource {
  const ActivityLocalDataSource(this._db);

  final drift_db.AppDatabase _db;

  Future<bool> exists(String clientRecordId) async =>
      await (_db.select(_db.activityLogs)..where(
            (drift_db.$ActivityLogsTable t) =>
                t.clientRecordId.equals(clientRecordId),
          ))
          .getSingleOrNull() !=
      null;

  Future<void> insert(ActivityEntry entry) => _db
      .into(_db.activityLogs)
      .insert(
        drift_db.ActivityLogsCompanion.insert(
          clientRecordId: entry.clientRecordId,
          type: entry.type.wire,
          durationMinutes: entry.durationMinutes,
          intensity: entry.intensity.wire,
          steps: Value<int?>(entry.steps),
          distanceMeters: Value<double?>(entry.distanceMeters),
          measuredAt: entry.measuredAt,
          note: Value<String?>(entry.note),
        ),
      );

  Future<List<ActivityEntry>> history() async {
    final List<drift_db.ActivityLog> rows =
        await (_db.select(_db.activityLogs)
              ..orderBy(<OrderingTerm Function(drift_db.$ActivityLogsTable)>[
                (drift_db.$ActivityLogsTable t) =>
                    OrderingTerm.desc(t.measuredAt),
              ]))
            .get();
    return rows.map(_toEntity).toList();
  }

  ActivityEntry _toEntity(drift_db.ActivityLog row) => ActivityEntry(
    clientRecordId: row.clientRecordId,
    type: ActivityType.fromWire(row.type),
    durationMinutes: row.durationMinutes,
    intensity: Intensity.fromWire(row.intensity),
    measuredAt: row.measuredAt,
    steps: row.steps,
    distanceMeters: row.distanceMeters,
    note: row.note,
  );
}
