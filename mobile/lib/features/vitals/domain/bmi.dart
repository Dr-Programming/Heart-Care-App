/// FR-VIT-004 / Decision 3. Computes the same formula the server snapshots
/// onto a `WEIGHT` reading (`docs/design/2026-07-10-vitals-design.md` §4):
/// `weightKg / (heightM)^2`, rounded to one decimal.
///
/// A missing or non-positive height yields `null` rather than dividing by
/// zero or throwing — a patient with no height on file simply sees no BMI,
/// never a garbage one. The value returned here is for immediate offline
/// display only; once the reading syncs, the server's snapshot is what
/// persists (Decision 3 — never overwritten locally after the fact).
double? calculateBmi({required double weightKg, double? heightCm}) {
  if (heightCm == null || heightCm <= 0) return null;
  final double heightM = heightCm / 100;
  final double bmi = weightKg / (heightM * heightM);
  return double.parse(bmi.toStringAsFixed(1));
}
