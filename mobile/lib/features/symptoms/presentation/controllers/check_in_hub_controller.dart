import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/symptom_check_in.dart';
import '../../symptom_providers.dart';

class CheckInHubController extends AsyncNotifier<SymptomCheckIn?> {
  @override
  Future<SymptomCheckIn?> build() =>
      ref.watch(symptomRepositoryProvider).latestToday();

  Future<void> refresh() async {
    state = const AsyncLoading<SymptomCheckIn?>();
    state = await AsyncValue.guard(
      () => ref.read(symptomRepositoryProvider).latestToday(),
    );
  }
}

final AsyncNotifierProvider<CheckInHubController, SymptomCheckIn?>
checkInHubControllerProvider =
    AsyncNotifierProvider.autoDispose<CheckInHubController, SymptomCheckIn?>(
      CheckInHubController.new,
    );
