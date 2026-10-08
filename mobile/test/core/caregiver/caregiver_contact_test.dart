import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/caregiver/caregiver_contact.dart';
import 'package:libu_care/core/db/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CaregiverContactStore store;

  setUp(() {
    db = testDatabase();
    store = CaregiverContactStore(db.preferencesDao);
  });

  tearDown(() => db.close());

  test('nothing is saved at first', () async {
    expect(await store.read(), isNull);
  });

  test('a saved caregiver is read back', () async {
    await store.save(
      const CaregiverContact(name: 'Almaz', phone: '+251911555666'),
    );

    expect(
      await store.read(),
      const CaregiverContact(name: 'Almaz', phone: '+251911555666'),
    );
  });

  test('clearing removes it', () async {
    await store.save(
      const CaregiverContact(name: 'Almaz', phone: '+251911555666'),
    );
    await store.clear();

    expect(await store.read(), isNull);
  });

  test(
    'belongs to the patient: cleared when another patient signs in',
    () async {
      await store.save(
        const CaregiverContact(name: 'Almaz', phone: '+251911555666'),
      );

      await db.clearPatientData();

      expect(await store.read(), isNull);
    },
  );

  test('phone numbers are checked', () {
    expect(validateCaregiverPhone('+251911555666'), isNull);
    expect(validateCaregiverPhone('0911555666'), isNull);
    expect(validateCaregiverPhone('12'), 'profile.caregiver.phoneInvalid');
    expect(validateCaregiverPhone(''), 'profile.caregiver.phoneRequired');
  });
}
