import '../../../core/db/daos/preferences_dao.dart';
import '../../../core/db/tables.dart';

/// Device-local reminder preferences — owned by M2 (settings + onboarding
/// step 3), read by M3 to actually schedule notifications. See the
/// `PreferenceKeys` doc comment in `core/db/tables.dart`.
///
/// Mirrors `core/localization/language.dart`'s `LanguageStore`: plain
/// key/value persistence, no server involvement. `notificationsEnabled` and
/// `symptomPromptTime` are not part of `PatientProfile` — the backend has no
/// notification fields — so there is nothing here to sync; M3 reads these
/// two Preferences rows directly.
class ReminderPrefs {
  const ReminderPrefs(this._prefs);

  final PreferencesDao _prefs;

  /// Defaults to enabled when unset, matching the wizard's opt-out framing
  /// (step 3 ships with the toggle already on).
  Future<bool> readNotificationsEnabled() async =>
      (await _prefs.get(PreferenceKeys.notificationsEnabled)) != 'false';

  Future<String?> readSymptomPromptTime() =>
      _prefs.get(PreferenceKeys.symptomPromptTime);

  Future<void> write({
    required bool notificationsEnabled,
    required String symptomPromptTime,
  }) async {
    await _prefs.set(
      PreferenceKeys.notificationsEnabled,
      notificationsEnabled.toString(),
    );
    await _prefs.set(PreferenceKeys.symptomPromptTime, symptomPromptTime);
  }
}