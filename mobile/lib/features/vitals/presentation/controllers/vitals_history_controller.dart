import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../vitals_providers.dart';

class VitalsHistoryController extends AsyncNotifier<List<VitalReading>> {
  VitalType? _typeFilter;

  VitalType? get typeFilter => _typeFilter;

  @override
  Future<List<VitalReading>> build() =>
      ref.watch(watchHistoryProvider).call(type: _typeFilter);

  Future<void> setTypeFilter(VitalType? type) async {
    _typeFilter = type;
    state = const AsyncLoading<List<VitalReading>>();
    state = await AsyncValue.guard(
      () => ref.read(watchHistoryProvider).call(type: type),
    );
  }
}

final AsyncNotifierProvider<VitalsHistoryController, List<VitalReading>>
vitalsHistoryControllerProvider = AsyncNotifierProvider.autoDispose<
  VitalsHistoryController,
  List<VitalReading>
>(VitalsHistoryController.new);
