import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/presentation/controllers/vital_form_controller.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    )..listen(vitalFormControllerProvider, (Object? a, Object? b) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  VitalFormController form() =>
      container.read(vitalFormControllerProvider.notifier);

  test(
    'a critical blood pressure is reported so the screen can warn',
    () async {
      form()
        ..updateValue(VitalType.bloodPressure, 'systolic', 182)
        ..updateValue(VitalType.bloodPressure, 'diastolic', 100);

      expect(await form().save(), isTrue);

      expect(
        container.read(vitalFormControllerProvider).worstSeverity,
        Severity.emergency,
      );
    },
  );

  test('a normal reading reports no severity', () async {
    form()
      ..updateValue(VitalType.bloodPressure, 'systolic', 118)
      ..updateValue(VitalType.bloodPressure, 'diastolic', 76);

    expect(await form().save(), isTrue);

    expect(
      container.read(vitalFormControllerProvider).worstSeverity,
      Severity.none,
    );
  });
}
