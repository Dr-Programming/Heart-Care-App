import '../../../../core/localization/language.dart';
import '../entities/patient_profile.dart';
import '../repositories/profile_repository.dart';

class SetLanguage {
  const SetLanguage(this._repository, this._languageStore);

  final ProfileRepository _repository;
  final LanguageStore _languageStore;

  Future<void> call(PatientProfile currentProfile, AppLanguage language) async {
    await _languageStore.write(language);
    await _repository.saveProfile(
      currentProfile.copyWith(preferredLanguage: language.code),
    );
  }
}
