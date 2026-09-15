import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../../medication_providers.dart';

class MedicationListState {
  const MedicationListState({
    required this.todaysDoses,
    required this.medications,
    this.missedRunAlerts = const <Medication>[],
  });

  final List<ScheduledDose> todaysDoses;
  final List<Medication> medications;

  final List<Medication> missedRunAlerts;

  bool get hasMissedRunAlert => missedRunAlerts.isNotEmpty;
}

const int _missedRunWindowDays = 30;

class MedicationListController extends AsyncNotifier<MedicationListState> {
  @override
  Future<MedicationListState> build() async {
    final repository = ref.watch(medicationRepositoryProvider);
    unawaited(repository.replayPendingEdits());
    final doses = await repository.todaysDoses();
    final medications = await repository.activeMedications();

    final DateTime now = DateTime.now();

    final List<DoseLog> recent = await repository.doseHistory(
      from: now.subtract(const Duration(days: _missedRunWindowDays)),
      to: now,
    );

    return MedicationListState(
      todaysDoses: doses,
      medications: medications,
      missedRunAlerts: _missedRunAlerts(medications, recent),
    );
  }

  List<Medication> _missedRunAlerts(
    List<Medication> medications,
    List<DoseLog> recentNewestFirst,
  ) {
    final Map<String, List<String>> statusesByMedication = <String, List<String>>{};
    for (final DoseLog log in recentNewestFirst) {
      statusesByMedication
          .putIfAbsent(log.medicationClientRecordId, () => <String>[])
          .add(log.status.wire);
    }

    return medications
        .where(
          (Medication m) => hasConsecutiveMissedDoses(
            statusesByMedication[m.clientRecordId] ?? const <String>[],
          ),
        )
        .toList();
  }

  Future<void> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) async {
    await ref.read(medicationRepositoryProvider).logDose(
      medicationClientRecordId: medicationClientRecordId,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      note: note,
    );
    ref.invalidateSelf();
  }

  Future<void> deactivate(String clientRecordId) async {
    final updated = await ref.read(medicationRepositoryProvider).deactivate(clientRecordId);
    await ref.read(medicationNotificationsProvider).cancelFor(updated.clientRecordId);
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<MedicationListController, MedicationListState>
medicationListControllerProvider =
    AsyncNotifierProvider<MedicationListController, MedicationListState>(
      MedicationListController.new,
    );
