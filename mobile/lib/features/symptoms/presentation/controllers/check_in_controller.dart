import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/ids.dart';
import '../../domain/entities/symptom_answer.dart';
import '../../domain/entities/symptom_check_in.dart';
import '../../domain/usecases/submit_check_in.dart';
import '../../domain/validators/symptom_validators.dart';
import '../providers/symptom_providers.dart';

part 'check_in_controller.g.dart';

/// Thrown into the controller's [AsyncValue] when [validateSymptomCheckIn]
/// finds a problem, so the screen can render field errors through
/// `state.error` — the same channel a `Failure` would use.
class SymptomValidationFailed implements Exception {
  const SymptomValidationFailed(this.errors);

  final Set<SymptomValidationError> errors;
}

/// Drives the daily symptom check-in form (FR-SYM-001…011).
///
/// `idle` is the initial `AsyncData(null)`; `saving` is `AsyncLoading`; a
/// validation problem or a local storage error both land in `AsyncError`,
/// the former as [SymptomValidationFailed]. There is nothing to await from
/// the network here — see `SymptomRepositoryImpl` for how the server's
/// assessment is reconciled in the background instead.
///
/// The screen reads the actual severity/action result from
/// `todayCheckInProvider` once this completes, rather than this controller
/// synthesizing one — that keeps the result on the same Drift-backed stream
/// every other screen already uses, with no duplicated assessment logic.
@riverpod
class CheckInController extends _$CheckInController {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required ChestPain chestPain,
    required ShortnessOfBreath shortnessOfBreath,
    required int heartRate,
    required BloodPressureReading bloodPressure,
    required bool swelling,
    required int energyLevel,
    Map<SymptomKey, bool> worseThanYesterday = const <SymptomKey, bool>{},
    String? note,
    DateTime? measuredAt,
  }) async {
    final SymptomCheckIn checkIn = SymptomCheckIn(
      clientRecordId: newClientRecordId(),
      chestPain: chestPain,
      shortnessOfBreath: shortnessOfBreath,
      heartRate: heartRate,
      bloodPressure: bloodPressure,
      swelling: swelling,
      energyLevel: energyLevel,
      worseThanYesterday: worseThanYesterday,
      measuredAt: measuredAt ?? DateTime.now(),
      note: note,
    );

    final Set<SymptomValidationError> errors = validateSymptomCheckIn(checkIn);
    if (errors.isNotEmpty) {
      state = AsyncError<void>(
        SymptomValidationFailed(errors),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() {
      final SubmitCheckIn submit = SubmitCheckIn(
        ref.read(symptomRepositoryProvider),
      );
      return submit(checkIn);
    });
  }
}
