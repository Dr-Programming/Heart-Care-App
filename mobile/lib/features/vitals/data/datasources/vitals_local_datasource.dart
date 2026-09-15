import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../models/vital_model.dart';

class VitalsLocalDataSource {
  const VitalsLocalDataSource(this._db);

  final drift_db.AppDatabase _db;

  Future<void> insert(VitalModel model) =>
      _db.into(_db.vitalsLogs).insert(model.toCompanion());

  Future<List<VitalReading>> history({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) async {
    final SimpleSelectStatement<drift_db.$VitalsLogsTable, drift_db.VitalsLog>
    query = _db.select(_db.vitalsLogs);

    query.where((drift_db.$VitalsLogsTable t) {
      Expression<bool> predicate = const Constant<bool>(true);
      if (type != null) {
        predicate = predicate & t.type.equals(type.wire);
      }
      if (from != null) {
        predicate = predicate & t.measuredAt.isBiggerOrEqualValue(from);
      }
      if (to != null) {
        predicate = predicate & t.measuredAt.isSmallerOrEqualValue(to);
      }
      return predicate;
    });

    query.orderBy(<OrderingTerm Function(drift_db.$VitalsLogsTable)>[
      (drift_db.$VitalsLogsTable t) => OrderingTerm.desc(t.measuredAt),
    ]);

    final List<drift_db.VitalsLog> rows = await query.get();
    return rows
        .map((drift_db.VitalsLog r) => VitalModel.fromRow(r).toEntity())
        .toList();
  }

  Future<Map<VitalType, VitalReading?>> latestByType() async {
    final Map<VitalType, VitalReading?> result = <VitalType, VitalReading?>{};
    for (final VitalType type in VitalType.values) {
      final drift_db.VitalsLog? row =
          await (_db.select(_db.vitalsLogs)
                ..where(
                  (drift_db.$VitalsLogsTable t) => t.type.equals(type.wire),
                )
                ..orderBy(<OrderingTerm Function(drift_db.$VitalsLogsTable)>[
                  (drift_db.$VitalsLogsTable t) =>
                      OrderingTerm.desc(t.measuredAt),
                ])
                ..limit(1))
              .getSingleOrNull();
      result[type] = row == null ? null : VitalModel.fromRow(row).toEntity();
    }
    return result;
  }

  Future<double?> latestHeightCm() async {
    final drift_db.PatientProfile? profile = await (_db.select(
      _db.patientProfiles,
    )..limit(1)).getSingleOrNull();
    return profile?.heightCm;
  }

  Future<VitalGoals?> latestGoals() async {
    final drift_db.PatientProfile? profile = await (_db.select(
      _db.patientProfiles,
    )..limit(1)).getSingleOrNull();
    final String? goalsJson = profile?.goalsJson;
    if (goalsJson == null) return null;
    try {
      return VitalGoals.fromJson(jsonDecode(goalsJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
