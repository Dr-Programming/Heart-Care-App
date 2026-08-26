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
    required this.syncQueueDao,
    required this.preferences,
    required this.isOnline,
  });

  final MedicationLocalDataSource local;
  final MedicationRemoteDataSource remote;
  final SyncEnqueuer syncEnqueuer;

  /// Read-only use of a `core/` dao: the sync engine parks the server id it
  /// got back for a record on `sync_queue_entries.serverId` rather than
  /// writing into feature tables, so a feature that needs its own rows'
  /// server ids has to harvest them from there. See [_harvestServerIds].
  final SyncQueueDao syncQueueDao;
  final PreferencesDao preferences;
  final Future<bool> Function() isOnline;

  static const String _pendingEditsKey = 'm3_pending_medication_edits';

  /// Serializes every read-modify-write against the pending-edits blob.
  ///
  /// `edit()` fires `_tryReplaySingle` unawaited, so a second `edit()` call
  /// (for a different medication) can otherwise land its own
  /// `_markPendingEdit` read-modify-write while the first edit's replay is
  /// still awaiting the network and its own eventual `_clearPendingEdit`.
  /// Without this, the later write's read would miss the earlier write and
  /// silently drop it on save. Chaining every mutation through this future
  /// forces them to run strictly one after another, regardless of which
  /// caller (a direct edit or a fire-and-forget replay) triggered them.
  ///
  /// Always kept in a completed-successfully state, even when the operation
  /// that produced it failed: `_markPendingEdit`/`_clearPendingEdit` chain
  /// onto this field but reassign it to an error-swallowed copy of the
  /// result they hand back to their own caller. `Future.then` skips its
  /// callback entirely once its source future has errored, so without that,
  /// a single transient `preferences` failure would permanently wedge this
  /// field in an errored state and silently disable every later mark/clear
  /// for the lifetime of this repository instance.
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
    // The medication's create may have synced since it was written locally;
    // if it has, `medicationId` (not `medicationClientRecordId`) is what the
    // dose-log payload should carry (Decision 3).
    await _harvestServerIds(<String>[medicationClientRecordId]);
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
    if (ids.isEmpty) return;
    // One batch query for the whole pending set, so `_tryReplaySingle` below
    // never has to harvest per-record.
    await _harvestServerIds(ids);
    for (final String id in ids) {
      await _tryReplaySingle(id);
    }
  }

  /// Copies server ids the sync engine resolved onto this feature's own rows.
  ///
  /// `SyncService` records the id the server assigned on the *queue* row
  /// (`sync_queue_entries.serverId`), deliberately not reaching into feature
  /// tables. Without this harvest a medication's `serverId` stays null
  /// forever, which silently disables both the pending-edit replay (there is
  /// no id to `PUT` to) and the `medicationId` branch of a dose-log payload.
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
      // `edit()` fires this directly, without going through
      // `replayPendingEdits`'s batch harvest — so try once here before
      // giving up on this pass.
      await _harvestServerIds(<String>[clientRecordId]);
      medication = await local.findMedication(clientRecordId);
      if (medication == null) {
        await _clearPendingEdit(clientRecordId);
        return;
      }
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
    } on DioException catch (e) {
      if (_isRetryableFailure(e)) {
        // Transport failure or a 5xx — leave it pending; the next reconnect
        // or screen visit retries it.
        return;
      }
      // A permanent rejection (working notes: "Retry only 500. 400/404/405/
      // 409/413 are permanent" — e.g. 409 because the record changed
      // server-side, or 404 because the medication was deleted there).
      // Retrying this forever would just re-fail forever. The local edit
      // already succeeded and is visible to the user; only the sync of it is
      // abandoned. There is no UI in this plan for surfacing a failed-sync
      // state — dropping the pending marker is the whole fix.
      await _clearPendingEdit(clientRecordId);
    }
  }

  /// Mirrors the split `core/network/dio_client.dart`'s
  /// `failureFromDioException` draws between transient and permanent
  /// failures (working notes: "Retry only 500. 400/404/405/409/413 are
  /// permanent."), without depending on that file's `Failure` hierarchy —
  /// it's shaped for user-facing error messages, not this internal
  /// retry-or-drop decision.
  bool _isRetryableFailure(DioException e) {
    final int? status = e.response?.statusCode;
    // No response at all (timeout, connection error) is a transport
    // failure — always retryable. A 5xx status is a transient server
    // condition — also retryable. Every other status (400/404/405/409/413
    // and any other 4xx) is a permanent rejection.
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
    // The chain itself must never see this operation's error — `catchError`
    // here swallows it only for `_pendingEditsLock`'s own purposes, so the
    // next queued mark/clear still runs. `result`, what THIS call returns to
    // its own caller, is untouched and still carries the real error.
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
