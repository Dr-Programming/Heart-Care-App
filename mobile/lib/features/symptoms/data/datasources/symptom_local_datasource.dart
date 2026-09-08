import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart';
import '../models/symptom_model.dart';

/// Plain Drift over `db.symptomLogs` — no `@DriftAccessor`, matching the
/// pattern every feature's local datasource follows (`core/db/tables.dart`),
/// so adding a feature never means regenerating a shared file.
class SymptomLocalDatasource {
  const SymptomLocalDatasource(this._db);

  final AppDatabase _db;

  /// [InsertMode.insertOrIgnore] because a save can legitimately be retried
  /// after a crash before the first attempt's row committed — the primary
  /// key is `clientRecordId`, so a retry is a no-op rather than a duplicate.
  Future<void> insert(SymptomModel model) async {
    await _db
        .into(_db.symptomLogs)
        .insert(model.toCompanion(), mode: InsertMode.insertOrIgnore);
  }

  /// Reverse-chronological. [from]/[to] are inclusive bounds on `measuredAt`,
  /// mirroring `GET /api/v1/symptoms?from=&to=`.
  Stream<List<SymptomModel>> watchHistory({DateTime? from, DateTime? to}) {
    final SimpleSelectStatement<$SymptomLogsTable, SymptomLog> query =
        _db.select(_db.symptomLogs)
          ..orderBy(<OrderingTerm Function($SymptomLogsTable)>[
            ($SymptomLogsTable t) => OrderingTerm.desc(t.measuredAt),
          ]);
    if (from != null) {
      query.where(
        ($SymptomLogsTable t) => t.measuredAt.isBiggerOrEqualValue(from),
      );
    }
    if (to != null) {
      query.where(
        ($SymptomLogsTable t) => t.measuredAt.isSmallerOrEqualValue(to),
      );
    }
    return query.watch().map(
      (List<SymptomLog> rows) => rows.map(SymptomModel.fromRow).toList(),
    );
  }

  /// Rows not yet confirmed by `reconcileServerAssessments` — the only
  /// marker needed is `serverId IS NULL`, since nothing else in this
  /// architecture ever writes it (the generic sync queue tracks its own
  /// copy of the server id, not the feature table's).
  Future<List<SymptomModel>> unconfirmed() async {
    final List<SymptomLog> rows = await (_db.select(
      _db.symptomLogs,
    )..where(($SymptomLogsTable t) => t.serverId.isNull())).get();
    return rows.map(SymptomModel.fromRow).toList();
  }

  /// Backfills the server's authoritative assessment onto an already-stored
  /// row. Scoped to exactly these three derived columns — `dataJson`,
  /// `measuredAt` and `note` (what the patient actually entered) are never
  /// touched, which is what keeps this from being the kind of log mutation
  /// `core/db/tables.dart` forbids.
  Future<void> applyServerAssessment({
    required String clientRecordId,
    required String serverId,
    required Map<String, dynamic> assessment,
    required String overallSeverity,
  }) async {
    await (_db.update(_db.symptomLogs)..where(
          ($SymptomLogsTable t) => t.clientRecordId.equals(clientRecordId),
        ))
        .write(
          SymptomLogsCompanion(
            serverId: Value<String?>(serverId),
            assessmentJson: Value<String?>(jsonEncode(assessment)),
            overallSeverity: Value<String?>(overallSeverity),
          ),
        );
  }
}
