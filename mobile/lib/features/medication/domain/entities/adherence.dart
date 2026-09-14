
class Adherence {
  const Adherence({
    required this.taken,
    required this.due,
    required this.skipped,
    required this.windowDays,
  });

  final int taken;
  final int due;
  final int skipped;
  final int windowDays;

  bool get hasData => due > 0;

  double? get percentage => hasData ? taken / due : null;
}
