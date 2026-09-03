import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/usecases/watch_history.dart';
import '../../vitals_providers.dart';

/// The tab root's view of "the latest of each type," derived from one live
/// history stream rather than five separate lookups.
class VitalsListState {
  const VitalsListState({
    required this.latestByType,
    required this.sparklineByType,
  });

  final Map<VitalType, VitalReading?> latestByType;

  /// Up to the 7 most recent readings per type, oldest-to-newest, reduced to
  /// one representative number each — enough for a glance, not a chart.
  final Map<VitalType, List<VitalPoint>> sparklineByType;
}

final StreamProvider<VitalsListState> vitalsListProvider =
    StreamProvider<VitalsListState>((Ref ref) {
      final WatchHistory watchHistory = ref.watch(watchHistoryProvider);
      return watchHistory().map(_toListState);
    });

VitalsListState _toListState(List<VitalReading> allNewestFirst) {
  final Map<VitalType, VitalReading?> latest = <VitalType, VitalReading?>{};
  final Map<VitalType, List<VitalPoint>> sparkline =
      <VitalType, List<VitalPoint>>{};

  for (final VitalType type in VitalType.values) {
    final List<VitalReading> forType = allNewestFirst
        .where((VitalReading r) => r.type == type)
        .toList();
    latest[type] = forType.isEmpty ? null : forType.first;
    sparkline[type] = forType
        .take(7)
        .toList()
        .reversed
        .map(
          (VitalReading r) => VitalPoint(r.measuredAt, _primaryValue(type, r)),
        )
        .toList();
  }
  return VitalsListState(latestByType: latest, sparklineByType: sparkline);
}

double _primaryValue(VitalType type, VitalReading r) => switch (type) {
  VitalType.bloodPressure => r.values['systolic']!,
  VitalType.glucose => r.values['glucose']!,
  VitalType.heartRate => r.values['heartRate']!,
  VitalType.weight => r.values['weight']!,
  VitalType.cholesterol => r.values['total']!,
};
