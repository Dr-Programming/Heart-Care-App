import 'alert_evaluator.dart';

/// How active the patient can be today, from their daily check-in.
enum ActivityLevel { rest, gentle, light, moderate }

/// What to do and what to avoid today. Activities are the server's
/// ActivityType wire values; their labels are `activity.type.<wire>`.
class ActivityGuidance {
  const ActivityGuidance({
    required this.level,
    required this.good,
    required this.avoid,
  });

  final ActivityLevel level;
  final List<String> good;
  final List<String> avoid;

  String get messageKey => 'activityGuidance.message.${level.name}';
}

const List<String> _all = <String>[
  'WALKING',
  'JOGGING',
  'CYCLING',
  'HOUSEHOLD',
  'FARMING',
  'STRETCHING',
];

/// General guidance until the care team's own rules are added; keep any
/// change here in step with the wording under `activityGuidance` in the
/// translations.
///
/// * Chest pain or severe breathlessness today, or an emergency-level
///   check-in: no exercise.
/// * Urgent: only gentle stretching.
/// * Watch: light activity only (walking, stretching, housework).
/// * All normal: moderate activity is fine.
ActivityGuidance activityGuidanceFor({
  required Severity overall,
  Map<String, Severity> perSymptom = const <String, Severity>{},
}) {
  final bool chestPain =
      (perSymptom['chestPain'] ?? Severity.none) != Severity.none;
  final bool severeBreathlessness =
      (perSymptom['shortnessOfBreath'] ?? Severity.none).index >=
      Severity.urgent.index;

  if (overall == Severity.emergency || chestPain || severeBreathlessness) {
    return const ActivityGuidance(
      level: ActivityLevel.rest,
      good: <String>[],
      avoid: _all,
    );
  }
  return switch (overall) {
    Severity.urgent => const ActivityGuidance(
      level: ActivityLevel.gentle,
      good: <String>['STRETCHING'],
      avoid: <String>['WALKING', 'JOGGING', 'CYCLING', 'HOUSEHOLD', 'FARMING'],
    ),
    Severity.monitor => const ActivityGuidance(
      level: ActivityLevel.light,
      good: <String>['WALKING', 'STRETCHING', 'HOUSEHOLD'],
      avoid: <String>['JOGGING', 'CYCLING', 'FARMING'],
    ),
    _ => const ActivityGuidance(
      level: ActivityLevel.moderate,
      good: _all,
      avoid: <String>[],
    ),
  };
}
