/// Offline clinical evaluation (FR-DEC-011).
///
/// Everything in this file is a pure function over plain maps and numbers, so
/// it runs with no network, no database and no Flutter binding — which is the
/// whole point: FR-DEC-011 requires decision support to work entirely from
/// locally stored data.
///
/// **These rules mirror the shipped backend, deliberately and exactly.**
/// `SymptomAssessment.java` and `VitalThresholds.java` are the authority. If
/// the client used its own numbers, a reading logged offline would show one
/// severity, then silently change to a different one after sync — the worst
/// possible behaviour for clinical information. When the backend rules change,
/// change these to match in the same pull request.
///
/// The bounds themselves are documented defaults and are **still pending
/// clinical sign-off** — the same caveat the backend carries. They are not
/// approved clinical guidance.
library;

/// Clinical urgency, ordered from least to most severe.
///
/// Wire-identical to the backend's `Severity` enum, including the ordering the
/// server relies on when it takes the maximum across symptoms.
enum Severity {
  none('NONE'),
  monitor('MONITOR'),
  urgent('URGENT'),
  emergency('EMERGENCY');

  const Severity(this.wire);

  final String wire;

  static Severity fromWire(String? value) => values.firstWhere(
    (Severity s) => s.wire == value,
    orElse: () => Severity.none,
  );

  bool operator >(Severity other) => index > other.index;

  Severity coalesce(Severity other) => index >= other.index ? this : other;
}

/// The recommended action to show alongside a severity (FR-DEC-009).
///
/// Returns a translation key, never a sentence — the action has to render in
/// both English and Amharic (FR-NOT-007), so the string itself lives in
/// `assets/translations/`.
String actionKeyFor(Severity severity) => switch (severity) {
  Severity.none => 'clinical.action.none',
  Severity.monitor => 'clinical.action.monitor',
  Severity.urgent => 'clinical.action.urgent',
  Severity.emergency => 'clinical.action.emergency',
};

// ---------------------------------------------------------------------------
// Vitals
// ---------------------------------------------------------------------------

/// A value is out of range when it is at or below [low], or at or above
/// [high]. A null bound means that side is unbounded.
class FlagRange {
  const FlagRange(this.low, this.high);

  final num? low;
  final num? high;

  bool breached(num value) =>
      (low != null && value <= low!) || (high != null && value >= high!);
}

/// Mirrors `VitalThresholds.RANGES` in the backend, key for key.
///
/// The server owns `flagged` on a synced reading; this table exists so a
/// reading captured offline shows the same status immediately, and shows the
/// *same* status again once it syncs.
const Map<String, FlagRange> vitalFlagRanges = <String, FlagRange>{
  'systolic': FlagRange(90, 180),
  'diastolic': FlagRange(60, 120),
  'glucose': FlagRange(4.0, 11.1),
  'heartRate': FlagRange(40, 120),
  'bmi': FlagRange(18.5, 30),
  'ldl': FlagRange(null, 4.9),
  'total': FlagRange(null, 7.5),
  'hdl': FlagRange(1.0, null),
};

/// Local stand-in for the server's `flagged`, computed the same way: any known
/// key out of range flags the whole reading. Unknown keys are ignored rather
/// than treated as a breach, exactly as the backend does.
bool isVitalFlagged(Map<String, num?> values) {
  return values.entries.any((MapEntry<String, num?> e) {
    final FlagRange? range = vitalFlagRanges[e.key];
    final num? value = e.value;
    return range != null && value != null && range.breached(value);
  });
}

/// How urgently the patient should act on a reading.
///
/// [type] is the wire `VitalType`; [values] is the reading's `values` object.
/// For a `WEIGHT` reading pass [bmi] as well — BMI, not the raw weight, is
/// what carries a threshold.
Severity severityForVital({
  required String type,
  required Map<String, num?> values,
  double? bmi,
}) {
  switch (type) {
    case 'BLOOD_PRESSURE':
      final num? systolic = values['systolic'];
      final num? diastolic = values['diastolic'];
      if (systolic == null || diastolic == null) return Severity.none;
      return bloodPressureSeverity(systolic, diastolic);

    case 'HEART_RATE':
      final num? heartRate = values['heartRate'];
      return heartRate == null ? Severity.none : heartRateSeverity(heartRate);

    case 'GLUCOSE':
      final num? glucose = values['glucose'];
      return glucose == null ? Severity.none : glucoseSeverity(glucose);

    case 'WEIGHT':
      if (bmi == null) return Severity.none;
      return vitalFlagRanges['bmi']!.breached(bmi)
          ? Severity.monitor
          : Severity.none;

    case 'CHOLESTEROL':
      return isVitalFlagged(values) ? Severity.monitor : Severity.none;

    default:
      return Severity.none;
  }
}

/// Mirrors `SymptomAssessment.bloodPressure`.
///
/// Note these bounds are *not* the ones written in FR-DEC-004/005 (>180/>110
/// and >140/>90). The shipped backend is the authority, and matching it is
/// what keeps a reading's severity stable across the offline/online boundary.
Severity bloodPressureSeverity(num systolic, num diastolic) {
  if (systolic >= 180) return Severity.emergency;
  if (systolic >= 160 ||
      systolic <= 90 ||
      diastolic >= 100 ||
      diastolic <= 60) {
    return Severity.urgent;
  }
  return Severity.none;
}

/// Mirrors `SymptomAssessment.heartRate` (FR-DEC-006).
Severity heartRateSeverity(num heartRate) =>
    (heartRate < 40 || heartRate > 120) ? Severity.urgent : Severity.none;

/// FR-DEC-007 for the urgent band; the backend's flag range for the watch
/// band. The backend has no glucose severity of its own — symptom check-ins
/// do not capture glucose — so this is the one classifier without a Java
/// counterpart to mirror.
Severity glucoseSeverity(num glucose) {
  if (glucose < 3.9 || glucose > 15.0) return Severity.urgent;
  if (vitalFlagRanges['glucose']!.breached(glucose)) return Severity.monitor;
  return Severity.none;
}

// ---------------------------------------------------------------------------
// Symptoms
// ---------------------------------------------------------------------------

/// The same shape the server returns in `assessment`: an overall level plus a
/// per-symptom breakdown. One widget can render either source.
class SymptomAssessment {
  const SymptomAssessment({required this.overall, required this.symptoms});

  final Severity overall;
  final Map<String, Severity> symptoms;
}

/// Mirrors `SymptomAssessment.assess` (FR-SYM-010).
///
/// [data] is the check-in payload: `chestPain{present, severity}`,
/// `shortnessOfBreath`, `bloodPressure{systolic, diastolic}`, `heartRate`,
/// `swelling`, `energyLevel`. Missing or malformed entries score `none` rather
/// than throwing — a partially filled draft still has to render.
SymptomAssessment assessSymptoms(Map<String, dynamic> data) {
  final Map<String, Severity> symptoms = <String, Severity>{
    'chestPain': _chestPain(data['chestPain']),
    'shortnessOfBreath': _shortnessOfBreath(data['shortnessOfBreath']),
    'bloodPressure': _bloodPressure(data['bloodPressure']),
    'heartRate': _heartRate(data['heartRate']),
    'swelling': data['swelling'] == true ? Severity.monitor : Severity.none,
    'energyLevel': _energyLevel(data['energyLevel']),
  };

  final Severity overall = symptoms.values.fold(
    Severity.none,
    (Severity a, Severity b) => a.coalesce(b),
  );

  return SymptomAssessment(overall: overall, symptoms: symptoms);
}

Severity _chestPain(dynamic raw) {
  if (raw is! Map) return Severity.none;
  if (raw['present'] != true) return Severity.none;
  final num? severity = _num(raw['severity']);
  if (severity == null) return Severity.none;
  if (severity >= 7) return Severity.emergency;
  if (severity >= 4) return Severity.urgent;
  if (severity >= 1) return Severity.monitor;
  return Severity.none;
}

Severity _shortnessOfBreath(dynamic level) => switch (level) {
  'SEVERE' => Severity.urgent,
  'MILD' => Severity.monitor,
  _ => Severity.none,
};

Severity _bloodPressure(dynamic raw) {
  if (raw is! Map) return Severity.none;
  final num? systolic = _num(raw['systolic']);
  final num? diastolic = _num(raw['diastolic']);
  if (systolic == null || diastolic == null) return Severity.none;
  return bloodPressureSeverity(systolic, diastolic);
}

Severity _heartRate(dynamic raw) {
  final num? heartRate = _num(raw);
  return heartRate == null ? Severity.none : heartRateSeverity(heartRate);
}

Severity _energyLevel(dynamic raw) {
  final num? level = _num(raw);
  return (level != null && level <= 2) ? Severity.monitor : Severity.none;
}

num? _num(dynamic value) => value is num ? value : null;

// ---------------------------------------------------------------------------
// Adherence
// ---------------------------------------------------------------------------

/// FR-DEC-002 — an adherence alert once [threshold] consecutive doses of the
/// same medication are missed.
///
/// [statusesNewestFirst] is that medication's dose history in reverse
/// chronological order. `SKIPPED` is deliberately not a miss: the patient made
/// a decision and recorded it, which is the behaviour the app is trying to
/// encourage.
bool hasConsecutiveMissedDoses(
  List<String> statusesNewestFirst, {
  int threshold = 2,
}) {
  int run = 0;
  for (final String status in statusesNewestFirst) {
    if (status != 'MISSED') break;
    run++;
    if (run >= threshold) return true;
  }
  return false;
}

/// FR-DEC-003 — the cross-signal that matters most: doses missed *and*
/// cardiac symptoms reported on the same day.
///
/// Kept as a pure function over three booleans so the caller assembles it from
/// whatever it already has. Nothing here imports a feature, which is what lets
/// the medication slice and the symptom slice both contribute to it without
/// importing each other.
Severity adherenceCrossSignal({
  required bool missedDoseToday,
  required bool chestPainToday,
  required bool severeBreathlessnessToday,
}) {
  if (!missedDoseToday) return Severity.none;
  if (chestPainToday || severeBreathlessnessToday) return Severity.urgent;
  return Severity.monitor;
}
