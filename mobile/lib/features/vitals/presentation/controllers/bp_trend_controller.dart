import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../domain/bp_trend.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../../vitals_providers.dart';

/// Blood pressure over the last 7 or 30 days, compared with the period
/// before it and with the patient's target.
class BpTrendController extends AsyncNotifier<BpTrend> {
  int _windowDays = 7;

  int get windowDays => _windowDays;

  @override
  Future<BpTrend> build() => _load(_windowDays);

  Future<void> setWindowDays(int days) async {
    _windowDays = days;
    state = const AsyncLoading<BpTrend>();
    state = await AsyncValue.guard(() => _load(days));
  }

  Future<BpTrend> _load(int windowDays) async {
    final VitalsRepository repository = ref.read(vitalsRepositoryProvider);
    final DateTime now = DateTime.now();
    final DateTime windowStart = DateFormatter.daysAgo(
      windowDays - 1,
      from: now,
    );
    final DateTime previousStart = DateFormatter.daysAgo(
      2 * windowDays - 1,
      from: now,
    );

    final List<VitalReading> readings = await repository.history(
      type: VitalType.bloodPressure,
      from: windowStart,
      to: now,
    );
    final List<VitalReading> previous = await repository.history(
      type: VitalType.bloodPressure,
      from: previousStart,
      to: windowStart.subtract(const Duration(microseconds: 1)),
    );
    return BpTrend.of(
      readings: readings,
      previous: previous,
      windowDays: windowDays,
      goals: await repository.latestGoals(),
      now: now,
    );
  }
}

final AsyncNotifierProvider<BpTrendController, BpTrend>
bpTrendControllerProvider =
    AsyncNotifierProvider.autoDispose<BpTrendController, BpTrend>(
      BpTrendController.new,
    );
