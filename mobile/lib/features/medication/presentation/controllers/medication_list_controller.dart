import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../../medication_providers.dart';

class MedicationListState {
  const MedicationListState({required this.todaysDoses, required this.medications});
  final List<ScheduledDose> todaysDoses;
  final List<Medication> medications;
}

/// Backs the Medications tab root and the Home card (Task 18). State is a
/// plain re-fetch after every mutation (`ref.invalidateSelf()`) rather than a
/// live stream — see the plan header's reactivity note.
class MedicationListController extends AsyncNotifier<MedicationListState> {
  @override
  Future<MedicationListState> build() async {
    final repository = ref.watch(medicationRepositoryProvider);
    unawaited(repository.replayPendingEdits());
    final doses = await repository.todaysDoses();
    final medications = await repository.activeMedications();
    return MedicationListState(todaysDoses: doses, medications: medications);
  }

  Future<void> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
  }) async {
    await ref.read(medicationRepositoryProvider).logDose(
      medicationClientRecordId: medicationClientRecordId,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
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
