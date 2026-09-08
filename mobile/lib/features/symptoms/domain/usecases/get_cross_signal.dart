import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/utils/date_formatter.dart';
import '../entities/symptom_answer.dart';
import '../entities/symptom_history_entry.dart';
import '../repositories/symptom_repository.dart';

/// FR-DEC-003 — doses missed and cardiac symptoms on the same day escalate
/// above either alone.
///
/// Composed here from two signals that belong to different slices:
/// [missedDoseToday] is a direct `DoseLogs` read (`DoseLogReader`, in this
/// feature's own `data/` folder — never an import from
/// `features/medication/`); today's symptoms come from this repository.
/// `adherenceCrossSignal` itself is pure and already mirrors the backend
/// (`core/clinical/alert_evaluator.dart`) — nothing here invents a rule.
class GetCrossSignal {
  const GetCrossSignal(this._repository);

  final SymptomRepository _repository;

  /// Chest pain counts if *any* check-in today reported it present, and
  /// likewise for severe breathlessness — not just the latest check-in of
  /// the day, since nothing stops a patient from checking in more than
  /// once.
  Stream<Severity> call({required bool missedDoseToday, DateTime? now}) {
    final DateTime today = DateFormatter.startOfDay(now ?? DateTime.now());
    return _repository.watchHistory(from: today).map((
      List<SymptomHistoryEntry> entries,
    ) {
      final bool chestPainToday = entries.any(
        (SymptomHistoryEntry e) => e.checkIn.chestPain.present,
      );
      final bool severeBreathlessnessToday = entries.any(
        (SymptomHistoryEntry e) =>
            e.checkIn.shortnessOfBreath == ShortnessOfBreath.severe,
      );
      return adherenceCrossSignal(
        missedDoseToday: missedDoseToday,
        chestPainToday: chestPainToday,
        severeBreathlessnessToday: severeBreathlessnessToday,
      );
    });
  }
}
