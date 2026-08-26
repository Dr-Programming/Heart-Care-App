import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/presentation/controllers/dose_history_controller.dart';

class _FakeRepository implements MedicationRepository {
  final List<String?> historyCalls = <String?>[];

  @override
  Future<List<DoseLog>> doseHistory({String? medicationClientRecordId, DateTime? from, DateTime? to}) async {
    historyCalls.add(medicationClientRecordId);
    return const <DoseLog>[];
  }
  @override
  Future<List<Medication>> activeMedications() async => const <Medication>[];
  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async => const <Medication>[];
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
  Future<Adherence> adherence({String? medicationClientRecordId, required int windowDays, DateTime? now}) async =>
      Adherence(taken: 0, due: 0, skipped: 0, windowDays: windowDays);
  @override
  Future<void> replayPendingEdits() async {}
}

void main() {
  test('build fetches with no filter', () async {
    final _FakeRepository repo = _FakeRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(doseHistoryControllerProvider.future);

    expect(repo.historyCalls, <String?>[null]);
  });

  test('setFilter refetches scoped to the chosen medication', () async {
    final _FakeRepository repo = _FakeRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(doseHistoryControllerProvider.future);

    await container
        .read(doseHistoryControllerProvider.notifier)
        .setFilter(const DoseHistoryFilter(medicationClientRecordId: 'm1'));
    await container.read(doseHistoryControllerProvider.future);

    expect(repo.historyCalls.last, 'm1');
  });
}
