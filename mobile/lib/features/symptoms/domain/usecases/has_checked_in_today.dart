import '../../../../core/utils/date_formatter.dart';
import '../entities/symptom_history_entry.dart';
import '../repositories/symptom_repository.dart';

/// The check-in hub's "done today" state (screen table, M5 spec §3):
/// whether the patient has already completed today's check-in, and if so,
/// what it was.
class HasCheckedInToday {
  const HasCheckedInToday(this._repository);

  final SymptomRepository _repository;

  /// Emits the most recent check-in made today, or null if none yet.
  ///
  /// History is newest-first, so the first item of a same-day window is
  /// today's latest — there is no server-enforced limit of one check-in per
  /// day, so "latest" rather than "the" is deliberate.
  Stream<SymptomHistoryEntry?> call({DateTime? now}) {
    final DateTime today = DateFormatter.startOfDay(now ?? DateTime.now());
    return _repository
        .watchHistory(from: today)
        .map(
          (List<SymptomHistoryEntry> logs) => logs.isEmpty ? null : logs.first,
        );
  }
}
