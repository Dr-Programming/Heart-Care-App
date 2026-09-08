import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart';
import '../models/activity_model.dart';

/// Plain Drift over `db.activityLogs` — no `@DriftAccessor`, matching the
/// pattern every feature's local datasource follows (`core/db/tables.dart`),
/// so adding a feature never means regenerating a shared file.
class ActivityLocalDatasource {
  const ActivityLocalDatasource(this._db);

  final AppDatabase _db;

  /// [InsertMode.insertOrIgnore] because a save can legitimately be retried
  /// after a crash before the first attempt's row committed — the primary
  /// key is `clientRecordId`, so a retry is a no-op rather than a duplicate.
  Future<void> insert(ActivityModel model) async {
    await _db
        .into(_db.activityLogs)
        .insert(model.toCompanion(), mode: InsertMode.insertOrIgnore);
  }

  /// Reverse-chronological. [from]/[to] are inclusive bounds on `measuredAt`,
  /// mirroring `GET /api/v1/activities?from=&to=`.
  Stream<List<ActivityModel>> watchHistory({DateTime? from, DateTime? to}) {
    final SimpleSelectStatement<$ActivityLogsTable, ActivityLog> query =
        _db.select(_db.activityLogs)
          ..orderBy(<OrderingTerm Function($ActivityLogsTable)>[
            ($ActivityLogsTable t) => OrderingTerm.desc(t.measuredAt),
          ]);
    if (from != null) {
      query.where(
        ($ActivityLogsTable t) => t.measuredAt.isBiggerOrEqualValue(from),
      );
    }
    if (to != null) {
      query.where(
        ($ActivityLogsTable t) => t.measuredAt.isSmallerOrEqualValue(to),
      );
    }
    return query.watch().map(
      (List<ActivityLog> rows) => rows.map(ActivityModel.fromRow).toList(),
    );
  }
}
