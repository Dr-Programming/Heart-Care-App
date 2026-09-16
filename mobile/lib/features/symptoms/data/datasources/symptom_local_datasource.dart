import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/symptom_check_in.dart';

class SymptomLocalDataSource {
  const SymptomLocalDataSource(this._db);

  final drift_db.AppDatabase _db;

  Future<void> insert(SymptomCheckIn entity) => _db
      .into(_db.symptomLogs)
      .insert(
        drift_db.SymptomLogsCompanion.insert(
          clientRecordId: entity.clientRecordId,
          dataJson: jsonEncode(entity.data),
          assessmentJson: Value<String?>(
            jsonEncode(<String, dynamic>{
              'overall': entity.overall.wire,
              'symptoms': entity.perSymptom.map(
                (String k, Severity v) => MapEntry<String, String>(k, v.wire),
              ),
            }),
          ),
          overallSeverity: Value<String?>(entity.overall.wire),
          measuredAt: entity.measuredAt,
          note: Value<String?>(entity.note),
        ),
      );

  Future<SymptomCheckIn?> latestToday() async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final drift_db.SymptomLog? row =
        await (_db.select(_db.symptomLogs)
              ..where(
                (drift_db.$SymptomLogsTable t) =>
                    t.measuredAt.isBiggerOrEqualValue(startOfDay),
              )
              ..orderBy(<OrderingTerm Function(drift_db.$SymptomLogsTable)>[
                (drift_db.$SymptomLogsTable t) =>
                    OrderingTerm.desc(t.measuredAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  Future<List<SymptomCheckIn>> history() async {
    final List<drift_db.SymptomLog> rows =
        await (_db.select(_db.symptomLogs)
              ..orderBy(<OrderingTerm Function(drift_db.$SymptomLogsTable)>[
                (drift_db.$SymptomLogsTable t) =>
                    OrderingTerm.desc(t.measuredAt),
              ]))
            .get();
    return rows.map(_toEntity).toList();
  }

  SymptomCheckIn _toEntity(drift_db.SymptomLog row) {
    final Map<String, dynamic> data =
        jsonDecode(row.dataJson) as Map<String, dynamic>;
    final Map<String, Severity> perSymptom = <String, Severity>{};
    if (row.assessmentJson != null) {
      final Map<String, dynamic> assessment =
          jsonDecode(row.assessmentJson!) as Map<String, dynamic>;
      final Map<String, dynamic> symptoms =
          (assessment['symptoms'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      symptoms.forEach((String k, dynamic v) {
        perSymptom[k] = Severity.fromWire(v as String);
      });
    }
    return SymptomCheckIn(
      clientRecordId: row.clientRecordId,
      data: data,
      overall: row.overallSeverity == null
          ? Severity.none
          : Severity.fromWire(row.overallSeverity!),
      perSymptom: perSymptom,
      measuredAt: row.measuredAt,
      note: row.note,
    );
  }
}
