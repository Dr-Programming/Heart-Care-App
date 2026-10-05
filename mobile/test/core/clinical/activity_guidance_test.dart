import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/activity_guidance.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';

void main() {
  test(
    'an all-normal check-in allows moderate activity with nothing to avoid',
    () {
      final ActivityGuidance g = activityGuidanceFor(overall: Severity.none);

      expect(g.level, ActivityLevel.moderate);
      expect(g.good, containsAll(<String>['WALKING', 'CYCLING', 'FARMING']));
      expect(g.avoid, isEmpty);
    },
  );

  test('a watch-level check-in keeps to light activity', () {
    final ActivityGuidance g = activityGuidanceFor(overall: Severity.monitor);

    expect(g.level, ActivityLevel.light);
    expect(g.good, <String>['WALKING', 'STRETCHING', 'HOUSEHOLD']);
    expect(g.avoid, containsAll(<String>['JOGGING', 'CYCLING', 'FARMING']));
  });

  test('an urgent check-in allows only gentle stretching', () {
    final ActivityGuidance g = activityGuidanceFor(overall: Severity.urgent);

    expect(g.level, ActivityLevel.gentle);
    expect(g.good, <String>['STRETCHING']);
    expect(g.avoid, contains('WALKING'));
  });

  test('an emergency check-in means no exercise', () {
    final ActivityGuidance g = activityGuidanceFor(overall: Severity.emergency);

    expect(g.level, ActivityLevel.rest);
    expect(g.good, isEmpty);
  });

  test(
    'any chest pain means no exercise, even when the overall level is lower',
    () {
      final ActivityGuidance g = activityGuidanceFor(
        overall: Severity.monitor,
        perSymptom: <String, Severity>{'chestPain': Severity.monitor},
      );

      expect(g.level, ActivityLevel.rest);
    },
  );

  test('severe breathlessness means no exercise', () {
    final ActivityGuidance g = activityGuidanceFor(
      overall: Severity.urgent,
      perSymptom: <String, Severity>{'shortnessOfBreath': Severity.urgent},
    );

    expect(g.level, ActivityLevel.rest);
  });

  test('every level has its own message', () {
    for (final ActivityLevel level in ActivityLevel.values) {
      expect(
        ActivityGuidance(
          level: level,
          good: const <String>[],
          avoid: const <String>[],
        ).messageKey,
        'activityGuidance.message.${level.name}',
      );
    }
  });
}
