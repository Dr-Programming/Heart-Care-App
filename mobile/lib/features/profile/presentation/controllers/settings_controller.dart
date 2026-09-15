import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/usecases/set_language.dart';
import '../../profile_providers.dart';

class SettingsController extends Notifier<void> {
  static const String _needsOnboardingKey = 'auth_needs_onboarding';

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
    final tokenStore = ref.read(tokenStoreProvider);
    final db = ref.read(appDatabaseProvider);
    final cachedUser = await db.cachedUserDao.current();
    final String userId = cachedUser?.id ?? '';

    await tokenStore.clear();
    await db.cachedUserDao.clear();
    await db.preferencesDao.remove(_needsOnboardingKey);
    if (userId.isNotEmpty) {
      await ref.read(profileRepositoryProvider).deleteProfile(userId);
    }
    await ref.read(realAuthGateProvider.notifier).refresh();
  }
}

final NotifierProvider<SettingsController, void> settingsControllerProvider =
    NotifierProvider<SettingsController, void>(SettingsController.new);
