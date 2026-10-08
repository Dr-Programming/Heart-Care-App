import '../../../core/utils/date_formatter.dart';
import 'entities/vital_reading.dart';

enum BpTrendStatus { noData, onTarget, aboveTarget, critical }

/// One day's average reading, for the chart.
class BpDay {
  const BpDay(this.day, this.systolic, this.diastolic);

  final DateTime day;
  final double systolic;
  final double diastolic;
}

/// Blood pressure over a window, against the patient's target.
///
/// The target is the goal set in the profile, or 120/80 when there is none —
/// the clinician's wording is "Your target is below 120/80". A day counts as
/// above target when its average is above either number. 180/120 is the
/// critical line, as everywhere else in the app.
class BpTrend {
  const BpTrend._({
    required this.days,
    required this.averageSystolic,
    required this.averageDiastolic,
    required this.systolicChange,
    required this.targetSystolic,
    required this.targetDiastolic,
    required this.daysAboveTarget,
    required this.status,
  });

  static const double defaultTargetSystolic = 120;
  static const double defaultTargetDiastolic = 80;
  static const double criticalSystolic = 180;
  static const double criticalDiastolic = 120;

  factory BpTrend.of({
    required List<VitalReading> readings,
    required List<VitalReading> previous,
    required int windowDays,
    VitalGoals? goals,
    DateTime? now,
  }) {
    final double targetSys = goals?.bpSystolic ?? defaultTargetSystolic;
    final double targetDia = goals?.bpDiastolic ?? defaultTargetDiastolic;

    final List<BpDay> days = _byDay(readings);
    final double? avgSys = _mean(readings, 'systolic');
    final double? avgDia = _mean(readings, 'diastolic');
    final double? previousSys = _mean(previous, 'systolic');

    final int above = days
        .where((BpDay d) => d.systolic > targetSys || d.diastolic > targetDia)
        .length;
    final bool critical = days.any(
      (BpDay d) =>
          d.systolic >= criticalSystolic || d.diastolic >= criticalDiastolic,
    );

    final BpTrendStatus status;
    if (days.isEmpty) {
      status = BpTrendStatus.noData;
    } else if (critical) {
      status = BpTrendStatus.critical;
    } else if (avgSys! > targetSys || avgDia! > targetDia) {
      status = BpTrendStatus.aboveTarget;
    } else {
      status = BpTrendStatus.onTarget;
    }

    return BpTrend._(
      days: days,
      averageSystolic: avgSys?.roundToDouble(),
      averageDiastolic: avgDia?.roundToDouble(),
      systolicChange: (avgSys == null || previousSys == null)
          ? null
          : (avgSys.round() - previousSys.round()).toDouble(),
      targetSystolic: targetSys,
      targetDiastolic: targetDia,
      daysAboveTarget: above,
      status: status,
    );
  }

  final List<BpDay> days;
  final double? averageSystolic;
  final double? averageDiastolic;

  /// Against the window before this one; null when either has no readings.
  final double? systolicChange;
  final double targetSystolic;
  final double targetDiastolic;
  final int daysAboveTarget;
  final BpTrendStatus status;

  bool get hasData => days.isNotEmpty;
  int get daysWithReadings => days.length;

  static double? _mean(List<VitalReading> readings, String key) {
    final List<double> values = <double>[
      for (final VitalReading r in readings)
        if (r.values[key] != null) r.values[key]!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  static List<BpDay> _byDay(List<VitalReading> readings) {
    final Map<DateTime, List<VitalReading>> grouped =
        <DateTime, List<VitalReading>>{};
    for (final VitalReading r in readings) {
      grouped
          .putIfAbsent(
            DateFormatter.startOfDay(r.measuredAt.toLocal()),
            () => <VitalReading>[],
          )
          .add(r);
    }
    final List<DateTime> keys = grouped.keys.toList()..sort();
    return <BpDay>[
      for (final DateTime day in keys)
        BpDay(
          day,
          _mean(grouped[day]!, 'systolic')!,
          _mean(grouped[day]!, 'diastolic')!,
        ),
    ];
  }
}
