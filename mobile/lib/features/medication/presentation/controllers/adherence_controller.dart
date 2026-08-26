import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/adherence.dart';
import '../../domain/entities/medication.dart';
import '../../medication_providers.dart';

class AdherenceState {
  const AdherenceState({
    required this.overall7,
    required this.overall30,
    required this.perMedication7,
    required this.perMedication30,
    this.medications = const <Medication>[],
  });

  final Adherence overall7;
  final Adherence overall30;

  /// Keyed by `Medication.clientRecordId`.
  final Map<String, Adherence> perMedication7;
  final Map<String, Adherence> perMedication30;

  /// The medications the per-window maps are keyed by, in display order.
  ///
  /// The maps alone carry only client record ids, which are UUIDs — the
  /// screen needs the names to render them at all (I4). Defaults to empty so
  /// a test that only exercises the overall figures does not have to supply
  /// it.
  final List<Medication> medications;
}

class AdherenceController extends AsyncNotifier<AdherenceState> {
  @override
  Future<AdherenceState> build() async {
    final repository = ref.watch(medicationRepositoryProvider);
    final List<Medication> medications = await repository.activeMedications();

    final Adherence overall7 = await repository.adherence(windowDays: 7);
    final Adherence overall30 = await repository.adherence(windowDays: 30);

    final Map<String, Adherence> per7 = <String, Adherence>{};
    final Map<String, Adherence> per30 = <String, Adherence>{};
    for (final Medication medication in medications) {
      per7[medication.clientRecordId] = await repository.adherence(
        medicationClientRecordId: medication.clientRecordId,
        windowDays: 7,
      );
      per30[medication.clientRecordId] = await repository.adherence(
        medicationClientRecordId: medication.clientRecordId,
        windowDays: 30,
      );
    }

    return AdherenceState(
      overall7: overall7,
      overall30: overall30,
      perMedication7: per7,
      perMedication30: per30,
      medications: medications,
    );
  }
}

final AsyncNotifierProvider<AdherenceController, AdherenceState>
adherenceControllerProvider =
    AsyncNotifierProvider<AdherenceController, AdherenceState>(
      AdherenceController.new,
    );
