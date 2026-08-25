/// `taken / due` over a window (Decision 5). `SKIPPED` doses are excluded
/// from both [taken] and [due] — recorded separately in [skipped] for
/// display, never as a penalty.
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

  /// False when there were zero due doses in the window — the UI must show
  /// "not enough data" rather than 0% or dividing by zero.
  bool get hasData => due > 0;

  double? get percentage => hasData ? taken / due : null;
}
