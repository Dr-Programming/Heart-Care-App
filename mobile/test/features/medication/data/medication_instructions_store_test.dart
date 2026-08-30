import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/medication/data/medication_instructions_store.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MedicationInstructionsStore store;

  setUp(() {
    db = testDatabase();
    store = MedicationInstructionsStore(db.preferencesDao);
  });

  tearDown(() => db.close());

  test('a medication with nothing saved yet returns none', () async {
    final MedicationInstructions value = await store.get('m1');
    expect(value, MedicationInstructions.none);
  });

  test('round-trips each instruction value for one medication', () async {
    for (final MedicationInstructions value in MedicationInstructions.values) {
      await store.set('m1', value);
      expect(await store.get('m1'), value);
    }
  });

  test('instructions for different medications do not collide', () async {
    await store.set('m1', MedicationInstructions.afterMeal);
    await store.set('m2', MedicationInstructions.beforeMeal);

    expect(await store.get('m1'), MedicationInstructions.afterMeal);
    expect(await store.get('m2'), MedicationInstructions.beforeMeal);
  });
}
