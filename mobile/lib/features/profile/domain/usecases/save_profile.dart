// Author: Thi Thuy Trang Nguyen
// Contributors: Thi Thuy Trang Nguyen, Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import '../entities/patient_profile.dart';
import '../repositories/profile_repository.dart';

class SaveProfile {
  const SaveProfile(this._repository);
  final ProfileRepository _repository;

  Future<void> call(PatientProfile profile) => _repository.saveProfile(profile);
}
