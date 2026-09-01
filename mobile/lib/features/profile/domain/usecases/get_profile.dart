import '../entities/patient_profile.dart';
import '../repositories/profile_repository.dart';

class GetProfile {
  final ProfileRepository repository;

  const GetProfile(this.repository);

  Future<PatientProfile> call() {
    return repository.getProfile();
  }
}
