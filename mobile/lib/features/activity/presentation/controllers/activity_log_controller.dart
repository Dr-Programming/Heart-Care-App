import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/ids.dart';
import '../../domain/entities/activity_session.dart';
import '../../domain/usecases/log_activity.dart';
import '../../domain/validators/activity_validators.dart';
import '../providers/activity_providers.dart';

part 'activity_log_controller.g.dart';

/// Thrown into the controller's [AsyncValue] when [validateActivitySession]
/// finds a problem, so the screen can render field errors the same way it
/// renders a `Failure` — through `state.error`, no separate error channel.
class ActivityValidationFailed implements Exception {
  const ActivityValidationFailed(this.errors);

  final Set<ActivityValidationError> errors;
}

/// Drives the "log activity" form (FR-ACT-003).
///
/// `idle` is the initial `AsyncData(null)`; `saving` is `AsyncLoading`; a
/// validation problem or a local storage error both land in `AsyncError`, the
/// former as [ActivityValidationFailed]. There is nothing to await from the
/// network here — see `ActivityRepositoryImpl` for why.
@riverpod
class ActivityLogController extends _$ActivityLogController {
  @override
  FutureOr<void> build() {}

  Future<void> save({
    required ActivityType type,
    required int durationMinutes,
    required Intensity intensity,
    int? steps,
    double? distanceMeters,
    String? note,
    DateTime? measuredAt,
  }) async {
    final Set<ActivityValidationError> errors = validateActivitySession(
      durationMinutes: durationMinutes,
    );
    if (errors.isNotEmpty) {
      state = AsyncError<void>(
        ActivityValidationFailed(errors),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() {
      final LogActivity logActivity = LogActivity(
        ref.read(activityRepositoryProvider),
      );
      return logActivity(
        ActivitySession(
          clientRecordId: newClientRecordId(),
          type: type,
          durationMinutes: durationMinutes,
          intensity: intensity,
          measuredAt: measuredAt ?? DateTime.now(),
          steps: steps,
          distanceMeters: distanceMeters,
          note: note,
        ),
      );
    });
  }
}
