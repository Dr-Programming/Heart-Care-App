import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateProvider, StateProviderFamily;
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:libu_care/core/utils/date_formatter.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../../domain/usecases/build_series.dart';
import '../../domain/usecases/watch_history.dart';
import '../../vitals_providers.dart';

/// Either "not enough readings yet" (with what there is, for the list
/// fallback) or a built set of series — never both.
class VitalsTrendData {
  const VitalsTrendData._({
    required this.insufficientData,
    required this.windowDays,
    this.readingsInWindow = const <VitalReading>[],
    this.series = const <VitalSeries>[],
  });

  factory VitalsTrendData.insufficientData(
    List<VitalReading> readings,
    int windowDays,
  ) => VitalsTrendData._(
    insufficientData: true,
    windowDays: windowDays,
    readingsInWindow: readings,
  );

  factory VitalsTrendData.loaded(List<VitalSeries> series, int windowDays) =>
      VitalsTrendData._(
        insufficientData: false,
        windowDays: windowDays,
        series: series,
      );

  final bool insufficientData;
  final int windowDays;
  final List<VitalReading> readingsInWindow;
  final List<VitalSeries> series;
}

/// One 7-or-30 selection per type, so switching tabs never bleeds one type's
/// toggle into another's.
final StateProviderFamily<int, VitalType> windowDaysProvider =
    StateProvider.family<int, VitalType>((Ref ref, VitalType type) => 7);

final StreamProviderFamily<VitalsTrendData, VitalType> trendDataProvider =
    StreamProvider.family<VitalsTrendData, VitalType>((
      Ref ref,
      VitalType type,
    ) async* {
      final int windowDays = ref.watch(windowDaysProvider(type));
      final WatchHistory watchHistory = ref.watch(watchHistoryProvider);
      final BuildSeries buildSeries = ref.watch(buildSeriesProvider);
      final VitalGoals? goals = await ref
          .watch(vitalsRepositoryProvider)
          .patientGoals();
      final Map<String, double> targets = _targetsFor(type, goals);

      await for (final List<VitalReading> all in watchHistory(type: type)) {
        final DateTime windowStart = DateFormatter.daysAgo(windowDays);
        final List<VitalReading> inWindow = all
            .where((VitalReading r) => !r.measuredAt.isBefore(windowStart))
            .toList();

        if (inWindow.length < minReadingsForTrend) {
          yield VitalsTrendData.insufficientData(inWindow, windowDays);
        } else {
          final List<VitalSeries> series = buildSeries(
            type: type,
            readings: all,
            windowDays: windowDays,
            targets: targets,
          );
          yield VitalsTrendData.loaded(series, windowDays);
        }
      }
    });

Map<String, double> _targetsFor(VitalType type, VitalGoals? goals) {
  if (goals == null) return const <String, double>{};
  return switch (type) {
    VitalType.bloodPressure => <String, double>{
      if (goals.bpSystolic != null) 'systolic': goals.bpSystolic!,
      if (goals.bpDiastolic != null) 'diastolic': goals.bpDiastolic!,
    },
    VitalType.weight => <String, double>{
      if (goals.targetWeightKg != null) 'weight': goals.targetWeightKg!,
    },
    VitalType.glucose ||
    VitalType.heartRate ||
    VitalType.cholesterol => const <String, double>{},
  };
}
