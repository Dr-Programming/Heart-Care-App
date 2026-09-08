import '../../../../core/clinical/alert_evaluator.dart';
import 'symptom_check_in.dart';

/// A check-in as stored — the read shape for history and the check-in hub,
/// pairing the captured answers with their severity assessment.
///
/// Named distinctly from Drift's generated `SymptomLog` row class
/// (`core/db/app_database.g.dart`, from the `SymptomLogs` table) to avoid a
/// same-name collision between the domain entity and the storage row.
///
/// [assessment] is the locally computed value (`assessSymptoms`) until the
/// server confirms it via `SymptomRepository.reconcileServerAssessments`,
/// then the server's own. Design decision 2 is that the two always agree by
/// construction, so nothing user-visible depends on which one is showing —
/// reconciliation exists for defensive consistency, not to change what the
/// patient sees.
class SymptomHistoryEntry {
  const SymptomHistoryEntry({
    required this.checkIn,
    required this.assessment,
    this.serverId,
  });

  final SymptomCheckIn checkIn;
  final SymptomAssessment assessment;

  /// Null until `reconcileServerAssessments` has confirmed this row.
  final String? serverId;

  String get clientRecordId => checkIn.clientRecordId;
  Severity get overallSeverity => assessment.overall;
}
