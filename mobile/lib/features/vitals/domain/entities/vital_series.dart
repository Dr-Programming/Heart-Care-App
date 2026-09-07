/// One point on a trend chart: when, and what the value was.
class VitalPoint {
  const VitalPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

/// One line's worth of windowed history — `systolic`, `diastolic`,
/// `weight`, or `glucose` — ready to plot. [points] is oldest-to-newest.
///
/// Presentation maps this to a `ChartSeries` (Task 11) by adding a [Color];
/// this class stays Flutter-free.
class VitalSeries {
  VitalSeries({required this.key, required this.points, this.targetValue})
    : assert(points.isNotEmpty, 'VitalSeries must have at least one point');

  final String key;
  final List<VitalPoint> points;

  /// From the patient's goals (Decision 5). Null means no goal is set on
  /// this key — never a default, invented target.
  final double? targetValue;

  double get min =>
      points.map((VitalPoint p) => p.value).reduce((a, b) => a < b ? a : b);

  double get max =>
      points.map((VitalPoint p) => p.value).reduce((a, b) => a > b ? a : b);

  double get avg =>
      points.map((VitalPoint p) => p.value).reduce((a, b) => a + b) /
      points.length;
}

/// Resolved Decision 6: below this many readings in the selected window,
/// the trend screen shows a list instead of a line — two points is not a
/// trend.
const int minReadingsForTrend = 3;
