import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';

void main() {
  late AppDatabase db;
  late LanguageStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LanguageStore(db.preferencesDao);
  });
  tearDown(() => db.close());

  group('AppLanguage', () {
    test('maps to the two-letter codes the API accepts', () {
      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.am.code, 'am');
    });

    test('parses a stored code, null when unrecognised', () {
      expect(AppLanguage.fromCode('am'), AppLanguage.am);
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('fr'), isNull);
      expect(AppLanguage.fromCode(null), isNull);
    });

    test('labels each language in its own script', () {
      expect(AppLanguage.en.nativeLabel, 'English');
      expect(AppLanguage.am.nativeLabel, 'አማርኛ');
    });
  });

  group('LanguageStore', () {
    test('reports no choice before first run completes', () async {
      expect(await store.hasChosen(), isFalse);
      expect(await store.read(), isNull);
    });

    test('persists the chosen language across reads', () async {
      await store.write(AppLanguage.am);
      expect(await store.read(), AppLanguage.am);
      expect(await store.hasChosen(), isTrue);
    });

    test('a later choice overwrites the earlier one', () async {
      await store.write(AppLanguage.am);
      await store.write(AppLanguage.en);
      expect(await store.read(), AppLanguage.en);
    });
  });
}
