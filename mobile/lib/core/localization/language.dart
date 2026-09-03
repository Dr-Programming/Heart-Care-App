import 'package:flutter/widgets.dart';

import '../db/daos/preferences_dao.dart';
import '../db/app_database.dart';

/// The two languages the app ships. The codes match exactly what
/// `POST /auth/register` accepts for `preferredLanguage` — do not add a value
/// here without a matching backend change.
enum AppLanguage {
  en('en', 'English'),
  am('am', 'አማርኛ');

  const AppLanguage(this.code, this.nativeLabel);

  final String code;

  /// Each language named in its own script — the standard for a picker shown
  /// before the user has told us which one they read.
  final String nativeLabel;

  Locale get locale => Locale(code);

  static AppLanguage? fromCode(String? code) {
    for (final AppLanguage l in AppLanguage.values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// Device-local language persistence.
///
/// This slice deliberately does not push the language to the server after
/// registration: `users.preferred_language` has no update endpoint, and there
/// is no post-login settings screen here for it to diverge from. Ownership of
/// that column is settled in the patient-profile slice.
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
