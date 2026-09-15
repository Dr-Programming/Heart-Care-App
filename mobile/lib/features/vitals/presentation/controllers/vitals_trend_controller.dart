import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;

import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../vitals_providers.dart';

class VitalsTrendController extends AsyncNotifier<VitalSeriesResult> {
  VitalsTrendController(this.type);

  final VitalType type;

  int _windowDays = 7;

  int get windowDays => _windowDays;

  @override
  Future<VitalSeriesResult> build() =>
      ref.watch(buildSeriesProvider).call(type: type, windowDays: _windowDays);

  Future<void> setWindowDays(int days) async {
    _windowDays = days;
    state = const AsyncLoading<VitalSeriesResult>();
    state = await AsyncValue.guard(
      () => ref.read(buildSeriesProvider).call(type: type, windowDays: days),
    );
  }
}

final AsyncNotifierProviderFamily<VitalsTrendController, VitalSeriesResult, VitalType>
vitalsTrendControllerProvider = AsyncNotifierProvider.autoDispose.family<
  VitalsTrendController,
  VitalSeriesResult,
  VitalType
>(VitalsTrendController.new);
