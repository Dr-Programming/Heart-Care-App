import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../vitals_providers.dart';

class VitalsListController extends AsyncNotifier<Map<VitalType, VitalReading?>> {
  @override
  Future<Map<VitalType, VitalReading?>> build() =>
      ref.watch(latestByTypeProvider).call();

  Future<void> refresh() async {
    state = const AsyncLoading<Map<VitalType, VitalReading?>>();
    state = await AsyncValue.guard(
      () => ref.read(latestByTypeProvider).call(),
    );
  }
}

final AsyncNotifierProvider<VitalsListController, Map<VitalType, VitalReading?>>
vitalsListControllerProvider = AsyncNotifierProvider.autoDispose<
  VitalsListController,
  Map<VitalType, VitalReading?>
>(VitalsListController.new);
