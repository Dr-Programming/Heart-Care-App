import 'vital_type.dart';

/// One vitals reading, exactly as the app stores and displays it. No JSON,
/// no Drift, no Flutter import — see `CONTRIBUTING.md` §8.
///
/// [flagged] is computed locally at capture time via
/// `core/clinical/alert_evaluator.dart` and is never recomputed later: it
/// agrees with the server's answer by construction (Decision 2), so there is
/// nothing to reconcile once the reading syncs.
class VitalReading {
  const VitalReading({
    required this.clientRecordId,
    required this.type,
    required this.values,
    required this.flagged,
    required this.measuredAt,
    this.serverId,
    this.bmi,
    this.note,
  });

  final String clientRecordId;
  final String? serverId;
  final VitalType type;

  /// Exactly the keys `vitalDescriptors[type]!.requiredKeys` declares.
  final Map<String, double> values;
  final bool flagged;

  /// Only ever set for a [VitalType.weight] reading with a known profile
  /// height (Decision 3). Null otherwise — never zero, never guessed.
  final double? bmi;
  final DateTime measuredAt;
  final String? note;
}
