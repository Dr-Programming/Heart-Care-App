import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../models/dose_log_model.dart';
import '../models/medication_model.dart';

class MedicationLocalDataSource {
  const MedicationLocalDataSource(this._db);

  final drift_db.AppDatabase _db;

  Future<void> upsertMedication(MedicationModel model) =>
      _db.into(_db.medications).insertOnConflictUpdate(model.toCompanion());

  Future<List<Medication>> activeMedications() async {
    final List<drift_db.Medication> rows =
        await (_db.select(_db.medications)
              ..where((drift_db.$MedicationsTable t) => t.active.equals(true)))
            .get();
    return rows.map(_medicationFromRow).toList();
  }

  Future<List<Medication>> allMedications({bool includeInactive = false}) async {
    final SimpleSelectStatement<drift_db.$MedicationsTable, drift_db.Medication>
    query = _db.select(_db.medications);
    if (!includeInactive) {
      query.where((drift_db.$MedicationsTable t) => t.active.equals(true));
    }
    final List<drift_db.Medication> rows = await query.get();
    return rows.map(_medicationFromRow).toList();
  }

  Future<Medication?> findMedication(String clientRecordId) async {
    final drift_db.Medication? row =
        await (_db.select(_db.medications)..where(
              (drift_db.$MedicationsTable t) =>
                  t.clientRecordId.equals(clientRecordId),
            ))
            .getSingleOrNull();
    return row == null ? null : _medicationFromRow(row);
  }

  Future<void> setServerId(String clientRecordId, String serverId) =>
      (_db.update(_db.medications)..where(
            (drift_db.$MedicationsTable t) =>
                t.clientRecordId.equals(clientRecordId),
          ))
          .write(
            drift_db.MedicationsCompanion(serverId: Value<String?>(serverId)),
          );

  Future<void> upsertDoseLog(
    DoseLogModel model, {
    required String medicationClientRecordId,
  }) => _db
      .into(_db.doseLogs)
      .insertOnConflictUpdate(
        model.toCompanion(medicationClientRecordId: medicationClientRecordId),
      );

  Future<List<DoseLog>> doseLogsForDate(String date) async {
    final List<drift_db.DoseLog> rows =
        await (_db.select(_db.doseLogs)..where(
              (drift_db.$DoseLogsTable t) => t.scheduledDate.equals(date),
            ))
            .get();
    return rows.map(_doseLogFromRow).toList();
  }

  Future<List<DoseLog>> doseLogsInRange({
    String? medicationClientRecordId,
    String? from,
    String? to,
  }) async {
    final SimpleSelectStatement<drift_db.$DoseLogsTable, drift_db.DoseLog>
    query = _db.select(_db.doseLogs);
    query.where((drift_db.$DoseLogsTable t) {
      Expression<bool> predicate = const Constant<bool>(true);
      if (medicationClientRecordId != null) {
        predicate =
            predicate & t.medicationClientRecordId.equals(medicationClientRecordId);
      }
      if (from != null) {
        predicate = predicate & t.scheduledDate.isBiggerOrEqualValue(from);
      }
      if (to != null) {
        predicate = predicate & t.scheduledDate.isSmallerOrEqualValue(to);
      }
      return predicate;
    });
    query.orderBy(<OrderingTerm Function(drift_db.$DoseLogsTable)>[
      (drift_db.$DoseLogsTable t) => OrderingTerm.desc(t.scheduledDate),
    ]);
    final List<drift_db.DoseLog> rows = await query.get();
    return rows.map(_doseLogFromRow).toList();
  }

  Medication _medicationFromRow(drift_db.Medication row) {
    return Medication(
      clientRecordId: row.clientRecordId,
      serverId: row.serverId,
      name: row.name,
      doseMg: row.doseMg,
      frequency: MedicationFrequency.fromWire(row.frequency),
      scheduleTimes: (jsonDecode(row.scheduleTimesJson) as List<dynamic>)
          .cast<String>(),
      active: row.active,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DoseLog _doseLogFromRow(drift_db.DoseLog row) {
    return DoseLog(
      clientRecordId: row.clientRecordId,
      serverId: row.serverId,
      medicationClientRecordId: row.medicationClientRecordId,
      medicationServerId: row.medicationServerId,
      status: DoseStatus.fromWire(row.status),
      scheduledDate: row.scheduledDate,
      scheduledTime: row.scheduledTime,
      loggedAt: row.loggedAt,
      note: row.note,
    );
  }
}
