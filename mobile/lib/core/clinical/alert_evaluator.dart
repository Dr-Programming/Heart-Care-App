

library;

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

String actionKeyFor(Severity severity) => switch (severity) {
  Severity.none => 'clinical.action.none',
  Severity.monitor => 'clinical.action.monitor',
  Severity.urgent => 'clinical.action.urgent',
  Severity.emergency => 'clinical.action.emergency',
};

class FlagRange {
  const FlagRange(this.low, this.high);

  final num? low;
  final num? high;

  bool breached(num value) =>
      (low != null && value <= low!) || (high != null && value >= high!);
}

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

bool isVitalFlagged(Map<String, num?> values) {
  return values.entries.any((MapEntry<String, num?> e) {
    final FlagRange? range = vitalFlagRanges[e.key];
    final num? value = e.value;
    return range != null && value != null && range.breached(value);
  });
}

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

Severity heartRateSeverity(num heartRate) =>
    (heartRate < 40 || heartRate > 120) ? Severity.urgent : Severity.none;

Severity glucoseSeverity(num glucose) {
  if (glucose < 3.9 || glucose > 15.0) return Severity.urgent;
  if (vitalFlagRanges['glucose']!.breached(glucose)) return Severity.monitor;
  return Severity.none;
}

class SymptomAssessment {
  const SymptomAssessment({required this.overall, required this.symptoms});

  final Severity overall;
  final Map<String, Severity> symptoms;
}

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

Severity adherenceCrossSignal({
  required bool missedDoseToday,
  required bool chestPainToday,
  required bool severeBreathlessnessToday,
}) {
  if (!missedDoseToday) return Severity.none;
  if (chestPainToday || severeBreathlessnessToday) return Severity.urgent;
  return Severity.monitor;
}
