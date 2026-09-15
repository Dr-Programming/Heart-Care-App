import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';
import 'package:libu_care/features/profile/domain/repositories/profile_repository.dart';
import 'package:libu_care/features/profile/domain/usecases/get_profile.dart';
import 'package:libu_care/features/profile/domain/usecases/save_profile.dart';

final _profile = PatientProfile.empty('u1').copyWith(birthYear: 1968);

class _FakeProfileRepository implements ProfileRepository {
  PatientProfile? saved;
  bool dirty = false;

  @override
  Future<PatientProfile> getProfile(String userId) async => _profile;

  @override
  Future<void> saveProfile(PatientProfile profile) async => saved = profile;

  @override
  Future<bool> isDirty(String userId) async => dirty;

  @override
  Future<void> retryPendingSave(String userId) async => dirty = false;

  @override
  Future<void> deleteProfile(String userId) async {}
}

void main() {
  test('GetProfile forwards the user id and returns the repository result', () async {
    final repo = _FakeProfileRepository();
    final result = await GetProfile(repo)('u1');
    expect(result, _profile);
  });

  test('SaveProfile forwards the profile to the repository', () async {
    final repo = _FakeProfileRepository();
    await SaveProfile(repo)(_profile);
    expect(repo.saved, _profile);
  });
}
