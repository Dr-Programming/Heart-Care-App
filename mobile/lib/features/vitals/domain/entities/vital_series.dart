import 'vital_reading.dart';

class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.points,
    this.targetValue,
  });

  final String label;
  final List<MapEntry<DateTime, double>> points;
  final double? targetValue;
}

sealed class VitalSeriesResult {}

class VitalTrendData extends VitalSeriesResult {
  VitalTrendData(this.series, this.readings);

  final List<ChartSeries> series;
  final List<VitalReading> readings;
}

class VitalInsufficientData extends VitalSeriesResult {
  VitalInsufficientData(this.readings);

  final List<VitalReading> readings;
}
