import '../entities/patient_profile.dart';
import '../repositories/profile_repository.dart';

class SaveProfile {
  final ProfileRepository repository;

  const SaveProfile(this.repository);

  Future<PatientProfile> call(PatientProfile profile) {
    return repository.saveProfile(profile);
  }
}