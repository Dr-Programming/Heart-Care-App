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

  /// Active medications whose most recent dose logs are two or more
  /// consecutive `MISSED` (FR-DEC-002 / FR-NOT-003, Done Criterion §9).
  ///
  /// Defaults to empty so a test or a caller that only cares about the list
  /// itself does not have to supply it.
  final List<Medication> missedRunAlerts;

  bool get hasMissedRunAlert => missedRunAlerts.isNotEmpty;
}

/// How far back the consecutive-miss check reads.
///
/// `hasConsecutiveMissedDoses` only ever inspects the head of the list, so
/// this is just a bound on how much history is loaded — 30 days matches the
/// longer adherence window and comfortably covers a run of two.
const int _missedRunWindowDays = 30;

/// Backs the Medications tab root and the Home card. State is a
/// plain re-fetch after every mutation (`ref.invalidateSelf()`) rather than a
/// live stream.
class MedicationListController extends AsyncNotifier<MedicationListState> {
  @override
  Future<MedicationListState> build() async {
    final repository = ref.watch(medicationRepositoryProvider);
    unawaited(repository.replayPendingEdits());
    final doses = await repository.todaysDoses();
    final medications = await repository.activeMedications();

    final DateTime now = DateTime.now();
    // One query for every medication's recent history, then partitioned in
    // memory — the alternative is one round-trip per medication.
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

  /// FR-DEC-002: two consecutive misses of the same medication raise an
  /// adherence alert.
  ///
  /// The decision itself is `core/clinical`'s `hasConsecutiveMissedDoses`,
  /// used verbatim (working notes: "Do not reimplement — `SKIPPED`
  /// deliberately breaks the run rather than continuing it"). All this does is
  /// hand it the right list: that medication's logs, newest first, as wire
  /// status strings. `doseHistory` already returns newest-first, ordered by
  /// scheduled date then scheduled time.
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

  /// [note] is the optional free-text note (FR-MED-008). Because `logDose` is
  /// idempotent per dose slot (I8), calling this again for the same slot with
  /// a note attaches it to the log already there rather than adding a second.
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
