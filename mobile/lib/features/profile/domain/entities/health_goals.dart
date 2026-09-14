class HealthGoals {
  const HealthGoals({
    this.bpSystolic,
    this.bpDiastolic,
    this.totalCholesterol,
    this.stepsPerDay,
    this.targetWeightKg,
    this.dietNote,
  });

  final int? bpSystolic;
  final int? bpDiastolic;
  final double? totalCholesterol;
  final int? stepsPerDay;
  final double? targetWeightKg;
  final String? dietNote;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthGoals &&
          runtimeType == other.runtimeType &&
          bpSystolic == other.bpSystolic &&
          bpDiastolic == other.bpDiastolic &&
          totalCholesterol == other.totalCholesterol &&
          stepsPerDay == other.stepsPerDay &&
          targetWeightKg == other.targetWeightKg &&
          dietNote == other.dietNote;

  @override
  int get hashCode => Object.hash(
    bpSystolic,
    bpDiastolic,
    totalCholesterol,
    stepsPerDay,
    targetWeightKg,
    dietNote,
  );
}
