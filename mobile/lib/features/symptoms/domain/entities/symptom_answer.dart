/// The six symptoms a daily check-in reports on (`backend/docs/API.md` §5).
///
/// Wire-identical to each key's spelling in the JSON payload — camelCase,
/// not SCREAMING_SNAKE, because these are object *keys*, not enum values.
/// This is also the key space `worseThanYesterday` is restricted to; typing
/// it as `Map<SymptomKey, bool>` makes an invalid key a compile error
/// instead of a server-side 400.
enum SymptomKey {
  chestPain('chestPain'),
  shortnessOfBreath('shortnessOfBreath'),
  heartRate('heartRate'),
  bloodPressure('bloodPressure'),
  swelling('swelling'),
  energyLevel('energyLevel');

  const SymptomKey(this.wire);

  final String wire;

  static SymptomKey fromWire(String value) =>
      values.firstWhere((SymptomKey k) => k.wire == value);
}

/// FR-SYM-001 — whether chest pain was present, and how severe.
///
/// [severity] is 0-10 and required exactly when [present] is true; a
/// [present]=false reading carries no severity, matching how the check-in
/// form only reveals the severity control once the symptom is reported
/// (design decision 1).
class ChestPain {
  const ChestPain({required this.present, this.severity});

  static const ChestPain none = ChestPain(present: false);

  final bool present;
  final int? severity;
}

/// FR-SYM-002.
enum ShortnessOfBreath {
  none('NONE'),
  mild('MILD'),
  severe('SEVERE');

  const ShortnessOfBreath(this.wire);

  final String wire;

  static ShortnessOfBreath fromWire(String value) =>
      values.firstWhere((ShortnessOfBreath s) => s.wire == value);
}

/// FR-SYM-004. Both bounds 40-300; the server also requires
/// `systolic > diastolic` (`backend/docs/API.md` §5).
class BloodPressureReading {
  const BloodPressureReading({required this.systolic, required this.diastolic});

  final int systolic;
  final int diastolic;
}
