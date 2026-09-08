import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/domain/repositories/activity_repository.dart';
import 'package:libu_care/features/activity/domain/validators/activity_validators.dart';
import 'package:libu_care/features/activity/presentation/controllers/activity_log_controller.dart';
import 'package:libu_care/features/activity/presentation/providers/activity_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late _MockActivityRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      ActivitySession(
        clientRecordId: 'fallback',
        type: ActivityType.walking,
        durationMinutes: 1,
        intensity: Intensity.light,
        measuredAt: DateTime(2000),
      ),
    );
  });

  setUp(() {
    repository = _MockActivityRepository();
    when(() => repository.log(any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: <Override>[
        activityRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a valid save logs the session through the repository', () async {
    final ActivityLogController notifier = container.read(
      activityLogControllerProvider.notifier,
    );

    await notifier.save(
      type: ActivityType.walking,
      durationMinutes: 30,
      intensity: Intensity.moderate,
      steps: 3000,
    );

    final List<dynamic> captured = verify(() => repository.log(captureAny()))
        .captured;
    final ActivitySession logged = captured.single as ActivitySession;
    expect(logged.type, ActivityType.walking);
    expect(logged.durationMinutes, 30);
    expect(logged.intensity, Intensity.moderate);
    expect(logged.steps, 3000);
    expect(logged.clientRecordId, isNotEmpty);

    final AsyncValue<void> state = container.read(
      activityLogControllerProvider,
    );
    expect(state.hasValue, isTrue);
    expect(state.hasError, isFalse);
  });

  test('an invalid duration never reaches the repository', () async {
    final ActivityLogController notifier = container.read(
      activityLogControllerProvider.notifier,
    );

    await notifier.save(
      type: ActivityType.walking,
      durationMinutes: 0,
      intensity: Intensity.moderate,
    );

    verifyNever(() => repository.log(any()));

    final AsyncValue<void> state = container.read(
      activityLogControllerProvider,
    );
    expect(state.hasError, isTrue);
    final Object? error = state.error;
    expect(error, isA<ActivityValidationFailed>());
    expect(
      (error as ActivityValidationFailed).errors,
      contains(ActivityValidationError.durationOutOfRange),
    );
  });

  test(
    'a repository failure surfaces through the async state, not a throw',
    () async {
      when(() => repository.log(any())).thenThrow(StateError('disk full'));
      final ActivityLogController notifier = container.read(
        activityLogControllerProvider.notifier,
      );

      await notifier.save(
        type: ActivityType.cycling,
        durationMinutes: 45,
        intensity: Intensity.vigorous,
      );

      final AsyncValue<void> state = container.read(
        activityLogControllerProvider,
      );
      expect(state.hasError, isTrue);
      expect(state.error, isA<StateError>());
    },
  );
}
