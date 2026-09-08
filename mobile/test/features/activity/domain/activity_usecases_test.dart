import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/domain/repositories/activity_repository.dart';
import 'package:libu_care/features/activity/domain/usecases/log_activity.dart';
import 'package:libu_care/features/activity/domain/usecases/watch_activity_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late _MockActivityRepository repository;

  setUp(() {
    repository = _MockActivityRepository();
  });

  group('LogActivity', () {
    test('delegates to the repository with the same session', () async {
      final ActivitySession session = ActivitySession(
        clientRecordId: 'a',
        type: ActivityType.walking,
        durationMinutes: 20,
        intensity: Intensity.light,
        measuredAt: DateTime(2026, 9, 1),
      );
      when(() => repository.log(session)).thenAnswer((_) async {});

      await LogActivity(repository).call(session);

      verify(() => repository.log(session)).called(1);
    });
  });

  group('WatchActivityHistory', () {
    test(
      'delegates to the repository, passing the from/to window through',
      () async {
        final DateTime from = DateTime(2026, 8, 26);
        final DateTime to = DateTime(2026, 9, 1);
        final List<ActivitySession> history = <ActivitySession>[];
        when(() => repository.watchHistory(from: from, to: to))
            .thenAnswer((_) => Stream<List<ActivitySession>>.value(history));

        final Stream<List<ActivitySession>> result = WatchActivityHistory(
          repository,
        ).call(from: from, to: to);

        await expectLater(result, emits(history));
        verify(() => repository.watchHistory(from: from, to: to)).called(1);
      },
    );

    test('defaults from/to to null when not given', () {
      when(() => repository.watchHistory(from: null, to: null))
          .thenAnswer((_) => const Stream<List<ActivitySession>>.empty());

      WatchActivityHistory(repository).call();

      verify(() => repository.watchHistory(from: null, to: null)).called(1);
    });
  });
}
