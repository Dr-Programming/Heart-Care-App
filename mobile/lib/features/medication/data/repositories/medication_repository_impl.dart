import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

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

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl({
    required this.local,
    required this.remote,
    required this.syncEnqueuer,
    required this.syncQueueDao,
    required this.preferences,
    required this.isOnline,
  });

  final MedicationLocalDataSource local;
  final MedicationRemoteDataSource remote;
  final SyncEnqueuer syncEnqueuer;

  final SyncQueueDao syncQueueDao;
  final PreferencesDao preferences;
  final Future<bool> Function() isOnline;

  static const String _pendingEditsKey = 'm3_pending_medication_edits';

  Future<void> _pendingEditsLock = Future<void>.value();

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

    await _harvestServerIds(<String>[medicationClientRecordId]);
    final Medication? medication = await local.findMedication(
      medicationClientRecordId,
    );

    final DoseLog? existing = await local.findDoseLogForSlot(
      medicationClientRecordId: medicationClientRecordId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
    );

    final DateTime now = DateTime.now().toUtc();
    final DoseLog entity = DoseLog(
      clientRecordId: existing?.clientRecordId ?? newClientRecordId(),
      serverId: existing?.serverId,
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
    if (ids.isEmpty) return;

    await _harvestServerIds(ids);
    for (final String id in ids) {
      await _tryReplaySingle(id);
    }
  }

  Future<void> _harvestServerIds(Iterable<String> clientRecordIds) async {
    final Map<String, String> resolved = await syncQueueDao.serverIds(
      clientRecordIds,
    );
    for (final MapEntry<String, String> entry in resolved.entries) {
      await local.setServerId(entry.key, entry.value);
    }
  }

  Future<void> _tryReplaySingle(String clientRecordId) async {
    if (!await isOnline()) return;
    Medication? medication = await local.findMedication(clientRecordId);
    if (medication == null) {
      await _clearPendingEdit(clientRecordId);
      return;
    }
    if (medication.serverId == null) {

      await _harvestServerIds(<String>[clientRecordId]);
      medication = await local.findMedication(clientRecordId);
      if (medication == null) {
        await _clearPendingEdit(clientRecordId);
        return;
      }
    }
    final String? serverId = medication.serverId;

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
    } on DioException catch (e) {
      if (_isRetryableFailure(e)) {

        return;
      }

      await _clearPendingEdit(clientRecordId);
    }
  }

  bool _isRetryableFailure(DioException e) {
    final int? status = e.response?.statusCode;

    return status == null || status >= 500;
  }

  Future<Set<String>> _pendingEditIds() async {
    final String? raw = await preferences.get(_pendingEditsKey);
    if (raw == null) return <String>{};
    return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
  }

  Future<void> _markPendingEdit(String clientRecordId) {
    final Future<void> result = _pendingEditsLock.then((_) async {
      final Set<String> ids = await _pendingEditIds()..add(clientRecordId);
      await preferences.set(_pendingEditsKey, jsonEncode(ids.toList()));
    });

    _pendingEditsLock = result.catchError((_) {});
    return result;
  }

  Future<void> _clearPendingEdit(String clientRecordId) {
    final Future<void> result = _pendingEditsLock.then((_) async {
      final Set<String> ids = await _pendingEditIds()..remove(clientRecordId);
      await preferences.set(_pendingEditsKey, jsonEncode(ids.toList()));
    });
    _pendingEditsLock = result.catchError((_) {});
    return result;
  }
}
