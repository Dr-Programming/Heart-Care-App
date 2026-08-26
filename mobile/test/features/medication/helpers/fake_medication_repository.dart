import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/notifications/notification_scheduler.dart';

/// A `MedicationRepository` that answers from in-memory lists.
///
/// The individual task tests each grew their own one-off `implements
/// MedicationRepository` fake; this is the shared version for the tests added
/// by the final-review fix wave, so that a new test does not have to restate
/// all eleven members to stub one of them.
class FakeMedicationRepository implements MedicationRepository {
  FakeMedicationRepository({
    List<Medication> medications = const <Medication>[],
    List<DoseLog> history = const <DoseLog>[],
    List<ScheduledDose> todays = const <ScheduledDose>[],
    this.writeError,
  }) : medications = <Medication>[...medications],
       history = <DoseLog>[...history],
       todays = <ScheduledDose>[...todays];

  /// When set, `add` and `edit` throw it instead of writing — for asserting
  /// that a caller surfaces a failed save rather than swallowing it (I7).
  final Object? writeError;

  final List<Medication> medications;
  final List<DoseLog> history;

  /// What `todaysDoses` answers with — supply it to drive a screen that
  /// renders today's rows.
  final List<ScheduledDose> todays;

  /// Every `doseHistory` call's filter, in order — lets a test assert that a
  /// filter control actually reached the repository.
  final List<String?> historyFilters = <String?>[];

  Medication? deactivated;

  @override
  Future<List<Medication>> activeMedications() async =>
      medications.where((Medication m) => m.active).toList();

  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async =>
      includeInactive
      ? <Medication>[...medications]
      : medications.where((Medication m) => m.active).toList();

  @override
  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  }) async {
    if (writeError != null) throw writeError!;
    final Medication created = Medication(
      clientRecordId: 'new-${medications.length}',
      serverId: null,
      name: name,
      doseMg: doseMg,
      frequency: frequency,
      scheduleTimes: scheduleTimes,
      active: true,
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
    );
    medications.add(created);
    return created;
  }

  @override
  Future<Medication> edit(Medication updated) async {
    if (writeError != null) throw writeError!;
    medications.removeWhere(
      (Medication m) => m.clientRecordId == updated.clientRecordId,
    );
    medications.add(updated);
    return updated;
  }

  @override
  Future<Medication> deactivate(String clientRecordId) async {
    final Medication current = medications.firstWhere(
      (Medication m) => m.clientRecordId == clientRecordId,
    );
    final Medication updated = current.copyWith(active: false);
    deactivated = updated;
    return edit(updated);
  }

  @override
  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) async {
    final DoseLog log = DoseLog(
      clientRecordId: 'log-${history.length}',
      serverId: null,
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: null,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      loggedAt: DateTime(2026, 8, 25),
      note: note,
    );
    history.add(log);
    return log;
  }

  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async =>
      <ScheduledDose>[...todays];

  @override
  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  }) async {
    historyFilters.add(medicationClientRecordId);
    if (medicationClientRecordId == null) return <DoseLog>[...history];
    return history
        .where(
          (DoseLog l) =>
              l.medicationClientRecordId == medicationClientRecordId,
        )
        .toList();
  }

  @override
  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  }) async => Adherence(taken: 0, due: 0, skipped: 0, windowDays: windowDays);

  @override
  Future<void> replayPendingEdits() async {}
}

/// A [NotificationScheduler] that keeps a real pending list, so
/// `MedicationNotifications`'s cancel-by-payload-prefix path is exercised
/// rather than stubbed out.
class RecordingScheduler implements NotificationScheduler {
  int initCalls = 0;

  /// Every payload ever scheduled, including ones later cancelled — the
  /// scheduling history, not the current state.
  final List<String> scheduledPayloads = <String>[];

  final Map<int, String> _pending = <int, String>{};

  List<String> get pendingPayloads => _pending.values.toList();

  @override
  Future<void> init() async => initCalls++;

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduledPayloads.add(payload);
    _pending[id] = payload;
  }

  @override
  Future<List<PendingScheduledNotification>> pending() async => _pending.entries
      .map(
        (MapEntry<int, String> e) =>
            PendingScheduledNotification(id: e.key, payload: e.value),
      )
      .toList();

  @override
  Future<void> cancel(int id) async {
    _pending.remove(id);
  }
}

/// A medication with sensible defaults, for tests that only care about one or
/// two of its fields.
Medication fakeMedication({
  String clientRecordId = 'm1',
  String name = 'Aspirin',
  double doseMg = 75,
  MedicationFrequency frequency = MedicationFrequency.onceDaily,
  List<String> scheduleTimes = const <String>['08:00'],
  bool active = true,
}) {
  return Medication(
    clientRecordId: clientRecordId,
    serverId: null,
    name: name,
    doseMg: doseMg,
    frequency: frequency,
    scheduleTimes: scheduleTimes,
    active: active,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}
