import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CaregiverNotifyStore store;

  setUp(() {
    db = testDatabase();
    store = CaregiverNotifyStore(db.preferencesDao);
  });

  tearDown(() => db.close());

  test('a medication with nothing saved yet returns empty settings', () async {
    final settings = await store.get('m1');
    expect(settings.enabled, isFalse);
    expect(settings.phone, isEmpty);
  });

  test('round-trips enabled + phone for one medication', () async {
    await store.set('m1', const CaregiverNotifySettings(enabled: true, phone: '+251911234567'));

    final settings = await store.get('m1');
    expect(settings.enabled, isTrue);
    expect(settings.phone, '+251911234567');
  });

  test('settings for different medications do not collide', () async {
    await store.set('m1', const CaregiverNotifySettings(enabled: true, phone: '+251911111111'));
    await store.set('m2', const CaregiverNotifySettings(enabled: false, phone: ''));

    expect((await store.get('m1')).phone, '+251911111111');
    expect((await store.get('m2')).enabled, isFalse);
  });
}
