import 'package:flutter/widgets.dart';

import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';

enum AppLanguage {
  en('en', 'English'),
  am('am', 'አማርኛ');

  const AppLanguage(this.code, this.nativeLabel);

  final String code;

  final String nativeLabel;

  Locale get locale => Locale(code);

  static AppLanguage? fromCode(String? code) {
    for (final AppLanguage l in AppLanguage.values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

class LanguageStore {
  const LanguageStore(this._prefs);

  final PreferencesDao _prefs;

  Future<AppLanguage?> read() async =>
      AppLanguage.fromCode(await _prefs.get(PreferenceKeys.language));

  Future<void> write(AppLanguage language) async {
    await _prefs.set(PreferenceKeys.language, language.code);
    await _prefs.set(PreferenceKeys.languageChosen, 'true');
  }

  Future<bool> hasChosen() async =>
      await _prefs.get(PreferenceKeys.languageChosen) == 'true';
}
