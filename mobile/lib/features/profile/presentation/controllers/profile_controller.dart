import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/patient_profile.dart';
import '../../profile_providers.dart';

class ProfileController extends AsyncNotifier<PatientProfile> {
  @override
  Future<PatientProfile> build() async {
    final cachedUser = await ref.watch(cachedUserProvider.future);
    final userId = cachedUser?.id ?? '';
    return ref.watch(profileRepositoryProvider).getProfile(userId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final AsyncNotifierProvider<ProfileController, PatientProfile>
profileControllerProvider =
    AsyncNotifierProvider<ProfileController, PatientProfile>(
      ProfileController.new,
    );
