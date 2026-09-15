import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/domain/usecases/add_medication.dart';
import 'package:libu_care/features/medication/domain/usecases/deactivate_medication.dart';
import 'package:libu_care/features/medication/domain/usecases/edit_medication.dart';
import 'package:libu_care/features/medication/domain/usecases/get_adherence.dart';
import 'package:libu_care/features/medication/domain/usecases/log_dose.dart';
import 'package:libu_care/features/medication/domain/usecases/todays_doses.dart';

Medication _medication(String id) => Medication(
  clientRecordId: id,
  serverId: null,
  name: 'Aspirin',
  doseMg: 75,
  frequency: MedicationFrequency.onceDaily,
  scheduleTimes: const <String>['08:00'],
  active: true,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

class _FakeMedicationRepository implements MedicationRepository {
  final List<String> calls = <String>[];

  @override
  Future<List<Medication>> activeMedications() async {
    calls.add('activeMedications');
    return <Medication>[_medication('m1')];
  }

  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async {
    calls.add('allMedications:$includeInactive');
    return <Medication>[_medication('m1')];
  }

  @override
  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  }) async {
    calls.add('add:$name');
    return _medication('new');
  }

  @override
  Future<Medication> edit(Medication updated) async {
    calls.add('edit:${updated.clientRecordId}');
    return updated;
  }

  @override
  Future<Medication> deactivate(String clientRecordId) async {
    calls.add('deactivate:$clientRecordId');
    return _medication(clientRecordId);
  }

  @override
  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) async {
    calls.add('logDose:$medicationClientRecordId:${status.wire}');
    return DoseLog(
      clientRecordId: 'd1',
      serverId: null,
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: null,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      loggedAt: DateTime.utc(2026, 8, 25),
      note: note,
    );
  }

  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async {
    calls.add('todaysDoses');
    return const <ScheduledDose>[];
  }

  @override
  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  }) async {
    calls.add('doseHistory');
    return const <DoseLog>[];
  }

  @override
  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  }) async {
    calls.add('adherence:$windowDays');
    return Adherence(taken: 1, due: 1, skipped: 0, windowDays: windowDays);
  }

  @override
  Future<void> replayPendingEdits() async {
    calls.add('replayPendingEdits');
  }
}

void main() {
  late _FakeMedicationRepository repo;

  setUp(() => repo = _FakeMedicationRepository());

  test('AddMedication delegates to the repository', () async {
    await AddMedication(repo).call(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );
    expect(repo.calls.single, 'add:Aspirin');
  });

  test('EditMedication delegates to the repository', () async {
    await EditMedication(repo).call(_medication('m1'));
    expect(repo.calls.single, 'edit:m1');
  });

  test('DeactivateMedication delegates to the repository', () async {
    await DeactivateMedication(repo).call('m1');
    expect(repo.calls.single, 'deactivate:m1');
  });

  test('LogDose delegates to the repository', () async {
    await LogDose(repo).call(
      medicationClientRecordId: 'm1',
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
    );
    expect(repo.calls.single, 'logDose:m1:TAKEN');
  });

  test('TodaysDoses delegates to the repository', () async {
    await TodaysDoses(repo).call();
    expect(repo.calls.single, 'todaysDoses');
  });

  test('GetAdherence delegates to the repository', () async {
    final Adherence a = await GetAdherence(repo).call(windowDays: 7);
    expect(repo.calls.single, 'adherence:7');
    expect(a.windowDays, 7);
  });
}
