import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

// `app_database.dart` re-exports `tables.dart`, whose Drift-generated row
// classes for the `Medications`/`DoseLogs` tables default to the names
// `Medication` and `DoseLog` — identical to this feature's domain entities,
// imported below. Hiding them avoids an ambiguous-import error; this file
// only needs `SyncEnqueuer`/`SyncEntityType` and `PreferencesDao`'s type from
// this import (the `AppDatabase` type itself is not referenced here).
import '../../../../core/db/app_database.dart' hide Medication, DoseLog;
import '../../../../core/db/daos/preferences_dao.dart';
import '../../../../core/sync/sync_queue_dao.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/adherence.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/schedule.dart';
import '../datasources/medication_local_datasource.dart';
import '../datasources/medication_remote_datasource.dart';
import '../models/dose_log_model.dart';
import '../models/medication_model.dart';

/// Offline-first: every write lands in Drift first, then is either enqueued
/// through [SyncEnqueuer] (creates/dose-logs — the only record kinds
/// `/api/v1/sync` accepts) or tracked as a pending edit (edits/deactivations,
/// which are not syncable) and replayed as a direct `PUT` once the
/// medication has a `serverId` and the device is online.
class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl({
    required this.local,
    required this.remote,
    required this.syncEnqueuer,
    required this.preferences,
    required this.isOnline,
  });

  final MedicationLocalDataSource local;
  final MedicationRemoteDataSource remote;
  final SyncEnqueuer syncEnqueuer;
  final PreferencesDao preferences;
  final Future<bool> Function() isOnline;

  static const String _pendingEditsKey = 'm3_pending_medication_edits';

  @override
  Future<List<Medication>> activeMedications() => local.activeMedications();

  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) =>
      local.allMedications(includeInactive: includeInactive);

  @override
  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final Medication entity = Medication(
      clientRecordId: newClientRecordId(),
      serverId: null,
      name: name,
      doseMg: doseMg,
      frequency: frequency,
      scheduleTimes: scheduleTimes,
      active: true,
      createdAt: now,
      updatedAt: now,
    );

    await local.upsertMedication(MedicationModel.fromEntity(entity));
    await syncEnqueuer.enqueue(
      clientRecordId: entity.clientRecordId,
      entityType: SyncEntityType.medication,
      payload: <String, dynamic>{
        'name': name,
        'doseMg': doseMg,
        'frequency': frequency.wire,
        'scheduleTimes': scheduleTimes,
        'active': true,
      },
      recordedAt: now,
    );
    return entity;
  }

  @override
  Future<Medication> edit(Medication updated) async {
    final Medication withTimestamp = updated.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );
    await local.upsertMedication(MedicationModel.fromEntity(withTimestamp));
    await _markPendingEdit(withTimestamp.clientRecordId);
    unawaited(_tryReplaySingle(withTimestamp.clientRecordId));
    return withTimestamp;
  }

  @override
  Future<Medication> deactivate(String clientRecordId) async {
    final Medication? current = await local.findMedication(clientRecordId);
    if (current == null) {
      throw StateError('Unknown medication: $clientRecordId');
    }
    return edit(current.copyWith(active: false));
  }

  @override
  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) async {
    final Medication? medication = await local.findMedication(
      medicationClientRecordId,
    );
    final DateTime now = DateTime.now().toUtc();
    final DoseLog entity = DoseLog(
      clientRecordId: newClientRecordId(),
      serverId: null,
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: medication?.serverId,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      loggedAt: now,
      note: note,
    );

    await local.upsertDoseLog(
      DoseLogModel.fromEntity(entity),
      medicationClientRecordId: medicationClientRecordId,
    );

    final String? medicationServerId = medication?.serverId;
    final Map<String, dynamic> payload = <String, dynamic>{
      'status': status.wire,
      'scheduledDate': scheduledDate,
      'scheduledTime': ?scheduledTime,
      'loggedAt': now.toIso8601String(),
      'note': ?note,
    };
    if (medicationServerId != null) {
      payload['medicationId'] = medicationServerId;
    } else {
      payload['medicationClientRecordId'] = medicationClientRecordId;
    }

    await syncEnqueuer.enqueue(
      clientRecordId: entity.clientRecordId,
      entityType: SyncEntityType.doseLog,
      payload: payload,
      recordedAt: now,
    );
    return entity;
  }

  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime today = DateFormatter.startOfDay(effectiveNow);
    final List<Medication> medications = await local.activeMedications();
    final List<DoseLog> logs = await local.doseLogsForDate(
      DateFormatter.toApiDate(today),
    );
    return scheduledDosesFor(
      medications: medications,
      logsForDate: logs,
      date: today,
      now: effectiveNow,
    );
  }

  @override
  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  }) => local.doseLogsInRange(
    medicationClientRecordId: medicationClientRecordId,
    from: from == null ? null : DateFormatter.toApiDate(from),
    to: to == null ? null : DateFormatter.toApiDate(to),
  );

  @override
  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime windowStart = DateFormatter.daysAgo(
      windowDays - 1,
      from: effectiveNow,
    );

    final List<Medication> medications;
    if (medicationClientRecordId == null) {
      medications = await local.allMedications(includeInactive: true);
    } else {
      final Medication? one = await local.findMedication(
        medicationClientRecordId,
      );
      medications = one == null ? <Medication>[] : <Medication>[one];
    }

    final List<DoseLog> logs = await local.doseLogsInRange(
      medicationClientRecordId: medicationClientRecordId,
      from: DateFormatter.toApiDate(windowStart),
      to: DateFormatter.toApiDate(effectiveNow),
    );

    return computeAdherence(
      medications: medications,
      allLogs: logs,
      windowStart: windowStart,
      now: effectiveNow,
      windowDays: windowDays,
    );
  }

  @override
  Future<void> replayPendingEdits() async {
    if (!await isOnline()) return;
    final Set<String> ids = await _pendingEditIds();
    for (final String id in ids) {
      await _tryReplaySingle(id);
    }
  }

  Future<void> _tryReplaySingle(String clientRecordId) async {
    if (!await isOnline()) return;
    final Medication? medication = await local.findMedication(clientRecordId);
    if (medication == null) {
      await _clearPendingEdit(clientRecordId);
      return;
    }
    final String? serverId = medication.serverId;
    // Still waiting on the original create to sync — nothing to PUT yet.
    // The record stays in the pending set and is retried on the next call.
    if (serverId == null) return;

    try {
      await remote.update(
        serverId,
        name: medication.name,
        doseMg: medication.doseMg,
        frequency: medication.frequency.wire,
        scheduleTimes: medication.scheduleTimes,
        active: medication.active,
      );
      await _clearPendingEdit(clientRecordId);
    } on DioException {
      // Leave it pending; the next reconnect or screen visit retries it.
    }
  }

  Future<Set<String>> _pendingEditIds() async {
    final String? raw = await preferences.get(_pendingEditsKey);
    if (raw == null) return <String>{};
    return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
  }

  Future<void> _markPendingEdit(String clientRecordId) async {
    final Set<String> ids = await _pendingEditIds()..add(clientRecordId);
    await preferences.set(_pendingEditsKey, jsonEncode(ids.toList()));
  }

  Future<void> _clearPendingEdit(String clientRecordId) async {
    final Set<String> ids = await _pendingEditIds()..remove(clientRecordId);
    await preferences.set(_pendingEditsKey, jsonEncode(ids.toList()));
  }
}
