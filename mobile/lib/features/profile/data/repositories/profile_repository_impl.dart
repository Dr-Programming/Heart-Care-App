import 'package:dio/dio.dart';

import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_datasource.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/patient_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({
    required this.remote,
    required this.local,
    required this.isOnline,
  });

  final ProfileRemoteDataSource remote;
  final ProfileLocalDataSource local;
  final Future<bool> Function() isOnline;

  @override
  Future<PatientProfile> getProfile(String userId) => local.getProfile(userId);

  @override
  Future<void> saveProfile(PatientProfile profile) async {
    await local.saveProfile(profile);

    if (!await isOnline()) {
      await local.setDirty(profile.userId, true);
      return;
    }

    try {
      await remote.saveProfile(PatientProfileModel.fromDomain(profile));
      await local.setDirty(profile.userId, false);
    } on DioException {
      await local.setDirty(profile.userId, true);
    } catch (_) {
      await local.setDirty(profile.userId, true);
    }
  }

  @override
  Future<bool> isDirty(String userId) => local.isDirty(userId);

  @override
  Future<void> deleteProfile(String userId) => local.deleteProfile(userId);

  @override
  Future<void> retryPendingSave(String userId) async {
    if (!await local.isDirty(userId)) return;
    if (!await isOnline()) return;

    final PatientProfile profile = await local.getProfile(userId);
    try {
      await remote.saveProfile(PatientProfileModel.fromDomain(profile));
      await local.setDirty(userId, false);
    } on DioException {
    } catch (_) {}
  }
}
