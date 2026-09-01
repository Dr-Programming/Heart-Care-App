import '../repositories/profile_repository.dart';

class SetLanguage {
  final ProfileRepository repository;

  const SetLanguage(this.repository);

  Future<void> call(String languageCode) {
    return repository.setLanguage(languageCode);
  }
}