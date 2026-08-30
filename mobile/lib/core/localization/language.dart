import 'package:flutter/widgets.dart';

import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';

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

/// Device-local language persistence — and the authoritative one.
///
/// Ownership of the language setting is settled: **the device owns it.**
/// `users.preferred_language` is a registration-time hint with no update
/// endpoint, and `patient_profiles.preferred_language` is profile data written
/// through `PUT /patients/me`. Neither is read to decide what the UI renders
/// in; this store is.
///
/// The reasoning: the setting is inherently per-device (the same account on a
/// borrowed phone should not change that phone's language), the released
/// backend has no endpoint to update the `users` copy, and the in-app toggle
/// (FR-LOC-003) has to work offline like everything else. Adding a
/// `PATCH /users/me/language` would reopen a shipped API for a setting the
/// server never reads.
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
