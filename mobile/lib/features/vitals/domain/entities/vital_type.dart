/// The five metric types `VitalsLogs.type` can hold. Wire-identical to the
/// backend's `VitalType` enum (`docs/design/2026-07-10-vitals-design.md` §4).
enum VitalType {
  bloodPressure('BLOOD_PRESSURE'),
  glucose('GLUCOSE'),
  heartRate('HEART_RATE'),
  weight('WEIGHT'),
  cholesterol('CHOLESTEROL');

  const VitalType(this.wire);

  final String wire;

  static VitalType fromWire(String value) =>
      values.firstWhere((VitalType t) => t.wire == value);
}
