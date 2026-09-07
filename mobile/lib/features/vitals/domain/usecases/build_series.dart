import 'package:libu_care/core/utils/date_formatter.dart';

import '../entities/vital_reading.dart';
import '../entities/vital_series.dart';
import '../entities/vital_type.dart';
import '../vital_descriptors.dart';

/// Turns a type's reading history into one [VitalSeries] per value key,
/// windowed to the last [windowDays] (FR-GRAPH-001..004).
///
/// [readings] need not be pre-filtered or pre-sorted — this windows them
/// itself, inclusive of the whole day [windowDays] ago (so a 7-day window
/// includes a reading from exactly 7 days back and excludes one from 8), and
/// always emits points oldest-to-newest for plotting, regardless of the
/// newest-first order a history stream provides (FR-VIT-006).
class BuildSeries {
  const BuildSeries();

  List<VitalSeries> call({
    required VitalType type,
    required List<VitalReading> readings,
    required int windowDays,
    Map<String, double> targets = const <String, double>{},
    DateTime? now,
  }) {
    final DateTime windowStart = DateFormatter.daysAgo(windowDays, from: now);
    final List<VitalReading> windowed =
        readings
            .where((VitalReading r) => !r.measuredAt.isBefore(windowStart))
            .toList()
          ..sort(
            (VitalReading a, VitalReading b) =>
                a.measuredAt.compareTo(b.measuredAt),
          );

    if (windowed.isEmpty) return const <VitalSeries>[];

    final List<String> keys = vitalDescriptors[type]!.requiredKeys;

    return <VitalSeries>[
      for (final String key in keys)
        if (windowed.any((VitalReading r) => r.values[key] != null))
          VitalSeries(
            key: key,
            points: <VitalPoint>[
              for (final VitalReading r in windowed)
                if (r.values[key] != null)
                  VitalPoint(r.measuredAt, r.values[key]!),
            ],
            targetValue: targets[key],
          ),
    ];
  }
}
