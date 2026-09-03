import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:libu_care/core/db/app_database.dart';

import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../models/vital_model.dart';

/// Drift only — no Dio, no domain usecases. See the file-level note in
/// `vitals_repository_impl.dart` (Task 9) for how this and the sync queue
/// compose into the offline-first write path.
class VitalsLocalDataSource {
  const VitalsLocalDataSource(this._db);

  final AppDatabase _db;

  /// `insertOrIgnore` so a retried write (app killed before the local
  /// transaction confirms, then retried) is a no-op rather than a primary-key
  /// crash — `clientRecordId` is `VitalsLogs`' primary key.
  Future<void> insert(VitalModel model) async {
    await _db
        .into(_db.vitalsLogs)
        .insert(model.toCompanion(), mode: InsertMode.insertOrIgnore);
  }

  /// Newest-first (FR-VIT-006), optionally filtered by [type] and/or windowed
  /// to `[from, to]` inclusive on both ends.
  Stream<List<VitalModel>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    final Selectable<VitalsLog> query = _db.select(_db.vitalsLogs)
      ..where(($VitalsLogsTable t) {
        Expression<bool> predicate = const Constant<bool>(true);
        if (type != null) predicate = predicate & t.type.equals(type.wire);
        if (from != null) {
          predicate = predicate & t.measuredAt.isBiggerOrEqualValue(from);
        }
        if (to != null) {
          predicate = predicate & t.measuredAt.isSmallerOrEqualValue(to);
        }
        return predicate;
      });

    return query.watch().map(
      (List<VitalsLog> rows) => (rows.map(_fromRow).toList())
        ..sort(
          (VitalModel a, VitalModel b) => b.measuredAt.compareTo(a.measuredAt),
        ),
    );
  }

  /// The most recent reading of [type], or null if none exists yet.
  Future<VitalModel?> latestByType(VitalType type) async {
    final List<VitalsLog> rows = await (_db.select(
      _db.vitalsLogs,
    )..where(($VitalsLogsTable t) => t.type.equals(type.wire))).get();
    if (rows.isEmpty) return null;
    rows.sort(
      (VitalsLog a, VitalsLog b) => b.measuredAt.compareTo(a.measuredAt),
    );
    return _fromRow(rows.first);
  }

  /// `PatientProfiles.heightCm` for the device's one patient row, or null if
  /// no row exists yet (M2 may not have landed) or no height is set.
  Future<double?> readHeightCm() async {
    final PatientProfile? profile = await (_db.select(
      _db.patientProfiles,
    )..limit(1)).getSingleOrNull();
    return profile?.heightCm;
  }

  /// `PatientProfiles.goalsJson`, parsed to the three keys this feature
  /// reads. Null under the same conditions as [readHeightCm], or if
  /// `goalsJson` itself is null.
  Future<VitalGoals?> readGoals() async {
    final PatientProfile? profile = await (_db.select(
      _db.patientProfiles,
    )..limit(1)).getSingleOrNull();
    final String? goalsJson = profile?.goalsJson;
    if (goalsJson == null) return null;

    final Map<String, dynamic> goals =
        jsonDecode(goalsJson) as Map<String, dynamic>;
    return VitalGoals(
      bpSystolic: (goals['bpSystolic'] as num?)?.toDouble(),
      bpDiastolic: (goals['bpDiastolic'] as num?)?.toDouble(),
      targetWeightKg: (goals['targetWeightKg'] as num?)?.toDouble(),
    );
  }

  VitalModel _fromRow(VitalsLog row) => VitalModel(
    clientRecordId: row.clientRecordId,
    serverId: row.serverId,
    type: row.type,
    values: (jsonDecode(row.valuesJson) as Map<String, dynamic>).map(
      (String k, dynamic v) =>
          MapEntry<String, double>(k, (v as num).toDouble()),
    ),
    flagged: row.flagged ?? false,
    bmi: row.bmi,
    measuredAt: row.measuredAt,
    note: row.note,
  );
}
