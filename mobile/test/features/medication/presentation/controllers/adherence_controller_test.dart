import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/presentation/controllers/adherence_controller.dart';

Medication _medication(String id) => Medication(
  clientRecordId: id, serverId: null, name: 'Med $id', doseMg: 10,
  frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
  active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
);

class _FakeRepository implements MedicationRepository {
  @override
  Future<List<Medication>> activeMedications() async => <Medication>[_medication('m1')];
  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async => <Medication>[_medication('m1')];
  @override
  Future<Adherence> adherence({String? medicationClientRecordId, required int windowDays, DateTime? now}) async =>
      Adherence(taken: 1, due: 2, skipped: 0, windowDays: windowDays);
  @override
  Future<Medication> add({required String name, required double doseMg, required MedicationFrequency frequency, required List<String> scheduleTimes}) async => throw UnimplementedError();
  @override
  Future<Medication> edit(Medication updated) async => throw UnimplementedError();
  @override
  Future<Medication> deactivate(String clientRecordId) async => throw UnimplementedError();
  @override
  Future<DoseLog> logDose({required String medicationClientRecordId, required DoseStatus status, required String scheduledDate, String? scheduledTime, String? note}) async => throw UnimplementedError();
  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async => const <ScheduledDose>[];
  @override
  Future<List<DoseLog>> doseHistory({String? medicationClientRecordId, DateTime? from, DateTime? to}) async => const <DoseLog>[];
  @override
  Future<void> replayPendingEdits() async {}
}

void main() {
  test('build populates overall and per-medication figures for both windows', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(_FakeRepository())],
    );
    addTearDown(container.dispose);

    final state = await container.read(adherenceControllerProvider.future);

    expect(state.overall7.windowDays, 7);
    expect(state.overall30.windowDays, 30);
    expect(state.perMedication7['m1']?.taken, 1);
    expect(state.perMedication30.containsKey('m1'), isTrue);
  });
}
