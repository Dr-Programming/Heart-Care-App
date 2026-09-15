double? calculateBmi({required double weightKg, double? heightCm}) {
  if (heightCm == null || heightCm <= 0) return null;
  final double heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}
