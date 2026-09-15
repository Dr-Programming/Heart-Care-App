import '../../../../core/utils/date_formatter.dart';
import '../entities/vital_reading.dart';
import '../entities/vital_series.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

class BuildSeries {
  const BuildSeries(this._repository);

  final VitalsRepository _repository;

  static const int minimumPointsForTrend = 3;

  Future<VitalSeriesResult> call({
    required VitalType type,
    required int windowDays,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime from = DateFormatter.daysAgo(
      windowDays - 1,
      from: effectiveNow,
    );

    final List<VitalReading> newestFirst = await _repository.history(
      type: type,
      from: from,
      to: effectiveNow,
    );

    if (newestFirst.length < minimumPointsForTrend) {
      return VitalInsufficientData(newestFirst);
    }

    final List<VitalReading> oldestFirst = newestFirst.reversed.toList();
    final VitalGoals? goals = await _repository.latestGoals();
    return VitalTrendData(_seriesFor(type, oldestFirst, goals), oldestFirst);
  }

  List<ChartSeries> _seriesFor(
    VitalType type,
    List<VitalReading> readings,
    VitalGoals? goals,
  ) {
    switch (type) {
      case VitalType.bloodPressure:
        return <ChartSeries>[
          ChartSeries(
            label: 'vitals.field.systolic',
            points: <MapEntry<DateTime, double>>[
              for (final VitalReading r in readings)
                MapEntry<DateTime, double>(r.measuredAt, r.values['systolic']!),
            ],
            targetValue: goals?.bpSystolic,
          ),
          ChartSeries(
            label: 'vitals.field.diastolic',
            points: <MapEntry<DateTime, double>>[
              for (final VitalReading r in readings)
                MapEntry<DateTime, double>(r.measuredAt, r.values['diastolic']!),
            ],
            targetValue: goals?.bpDiastolic,
          ),
        ];
      case VitalType.weight:
        return <ChartSeries>[
          ChartSeries(
            label: 'vitals.field.weight',
            points: <MapEntry<DateTime, double>>[
              for (final VitalReading r in readings)
                MapEntry<DateTime, double>(r.measuredAt, r.values['weight']!),
            ],
            targetValue: goals?.targetWeightKg,
          ),
        ];
      case VitalType.cholesterol:
        return <ChartSeries>[
          ChartSeries(
            label: 'vitals.field.total',
            points: <MapEntry<DateTime, double>>[
              for (final VitalReading r in readings)
                MapEntry<DateTime, double>(r.measuredAt, r.values['total']!),
            ],
            targetValue: goals?.totalCholesterol,
          ),
        ];
      case VitalType.glucose:
        return <ChartSeries>[
          ChartSeries(
            label: 'vitals.field.glucose',
            points: <MapEntry<DateTime, double>>[
              for (final VitalReading r in readings)
                MapEntry<DateTime, double>(r.measuredAt, r.values['glucose']!),
            ],
          ),
        ];
      case VitalType.heartRate:
        return <ChartSeries>[
          ChartSeries(
            label: 'vitals.field.heartRate',
            points: <MapEntry<DateTime, double>>[
              for (final VitalReading r in readings)
                MapEntry<DateTime, double>(r.measuredAt, r.values['heartRate']!),
            ],
          ),
        ];
    }
  }
}
