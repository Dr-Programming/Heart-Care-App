import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/activity/activity_providers.dart';
import 'package:libu_care/features/activity/domain/entities/activity_entry.dart';
import 'package:libu_care/features/activity/presentation/controllers/activity_form_controller.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    // The form provider is auto-disposed; keep it alive for the test.
    container.listen(activityFormControllerProvider, (Object? a, Object? b) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ActivityFormController controller() =>
      container.read(activityFormControllerProvider.notifier);

  test('an out-of-range duration is shown and nothing is saved', () async {
    controller().setDuration('2000');

    expect(await controller().save(), isFalse);
    expect(
      container.read(activityFormControllerProvider).durationError,
      'activity.errors.durationRange',
    );
    expect(await container.read(activityRepositoryProvider).history(), isEmpty);
  });

  test('a valid entry is saved with the chosen type and intensity', () async {
    controller()
      ..setType(ActivityType.cycling)
      ..setIntensity(Intensity.vigorous)
      ..setDuration('45')
      ..setSteps('');

    expect(await controller().save(), isTrue);

    final ActivityEntry saved =
        (await container.read(activityRepositoryProvider).history()).single;
    expect(saved.type, ActivityType.cycling);
    expect(saved.intensity, Intensity.vigorous);
    expect(saved.durationMinutes, 45);
    expect(saved.steps, isNull);
  });
}
