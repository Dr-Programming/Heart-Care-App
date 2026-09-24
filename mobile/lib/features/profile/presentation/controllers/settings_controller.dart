import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/usecases/set_language.dart';
import '../../profile_providers.dart';

class SettingsController extends Notifier<void> {
  @override
  void build() {}

  Future<void> changeLanguage(AppLanguage language) async {
    final repo = ref.read(profileRepositoryProvider);
    final languageStore = ref.read(languageStoreProvider);

    final cachedUser = await ref
        .read(appDatabaseProvider)
        .cachedUserDao
        .current();
    final userId = cachedUser?.id ?? '';
    final currentProfile = await repo.getProfile(userId);
    await SetLanguage(repo, languageStore)(currentProfile, language);
  }

  Future<void> retrySync(String userId) =>
      ref.read(profileRepositoryProvider).retryPendingSave(userId);

  Future<void> signOut() async {
    final db = ref.read(appDatabaseProvider);
    final cachedUser = await db.cachedUserDao.current();
    final String userId = cachedUser?.id ?? '';

    // Through the repository, so an offline session ends too; the account
    // stays remembered for the next offline sign-in.
    await ref.read(authRepositoryProvider).logout();
    if (userId.isNotEmpty) {
      await ref.read(profileRepositoryProvider).deleteProfile(userId);
    }
    await ref.read(realAuthGateProvider.notifier).refresh();
  }
}

final NotifierProvider<SettingsController, void> settingsControllerProvider =
    NotifierProvider<SettingsController, void>(SettingsController.new);
