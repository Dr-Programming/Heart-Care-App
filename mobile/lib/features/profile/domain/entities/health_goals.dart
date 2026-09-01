class HealthGoals {
  final int? bpSystolic;
  final int? bpDiastolic;
  final double? totalCholesterol;
  final int? stepsPerDay;
  final double? targetWeightKg;
  final String? dietNote;

  const HealthGoals({
    this.bpSystolic,
    this.bpDiastolic,
    this.totalCholesterol,
    this.stepsPerDay,
    this.targetWeightKg,
    this.dietNote,
  });

  HealthGoals copyWith({
    int? bpSystolic,
    int? bpDiastolic,
    double? totalCholesterol,
    int? stepsPerDay,
    double? targetWeightKg,
    String? dietNote,
  }) {
    return HealthGoals(
      bpSystolic: bpSystolic ?? this.bpSystolic,
      bpDiastolic: bpDiastolic ?? this.bpDiastolic,
      totalCholesterol: totalCholesterol ?? this.totalCholesterol,
      stepsPerDay: stepsPerDay ?? this.stepsPerDay,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      dietNote: dietNote ?? this.dietNote,
    );
  }
}