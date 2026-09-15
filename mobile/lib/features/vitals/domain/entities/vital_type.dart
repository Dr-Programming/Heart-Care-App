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
