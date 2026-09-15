import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../profile_providers.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _appVersion = '1.0.0';

  String _userId = '';
  AppLanguage? _language;
  bool _notificationsEnabled = true;
  bool _isDirty = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final cachedUser = await db.cachedUserDao.current();
    final String userId = cachedUser?.id ?? '';
    final AppLanguage? language = await ref.read(languageStoreProvider).read();
    final String? notificationsRaw = await db.preferencesDao.get(
      PreferenceKeys.notificationsEnabled,
    );
    final bool isDirty = userId.isEmpty
        ? false
        : await ref.read(profileRepositoryProvider).isDirty(userId);

    if (!mounted) return;
    setState(() {
      _userId = userId;
      _language = language;

      _notificationsEnabled = notificationsRaw != 'false';
      _isDirty = isDirty;
      _loading = false;
    });
  }

  Future<void> _onLanguageTap() async {
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final AppLanguage? chosen = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xl),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'profile.settings.language.pickerTitle'.tr(),
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final AppLanguage option in AppLanguage.values)
                ListTile(
                  key: Key('settings_language_option_${option.code}'),
                  title: Text(option.nativeLabel),
                  trailing: option == _language
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        );
      },
    );

    if (chosen == null || chosen == _language) return;
    await controller.changeLanguage(chosen);
    if (!mounted) return;

    await context.setLocale(chosen.locale);
    if (!mounted) return;
    setState(() => _language = chosen);
  }

  Future<void> _onNotificationsChanged(bool value) async {
    final db = ref.read(appDatabaseProvider);
    await db.preferencesDao.set(
      PreferenceKeys.notificationsEnabled,
      value ? 'true' : 'false',
    );
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _onSendNow() async {
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    await controller.retrySync(_userId);
    final bool stillDirty = await ref
        .read(profileRepositoryProvider)
        .isDirty(_userId);
    if (!mounted) return;
    setState(() => _isDirty = stillDirty);
  }

  Future<void> _onSignOut() async {
    final bool confirmed = await ConfirmSheet.show(
      context,
      title: 'profile.settings.signOut.confirmTitle'.tr(),
      message: 'profile.settings.signOut.confirmMessage'.tr(),
      confirmLabel: 'profile.settings.signOut.confirmLabel'.tr(),
      isDestructive: true,
    );
    if (!confirmed) return;

    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    await controller.signOut();
    if (!mounted) return;
    context.goNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'profile.settings.title'.tr(),
      scrollable: true,
      padded: false,
      body: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ListTile(
                  key: const Key('settings_language_row'),
                  leading: const Icon(Icons.language_outlined),
                  title: Text('profile.settings.language.title'.tr()),
                  subtitle: Text(_language?.nativeLabel ?? '—'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _onLanguageTap,
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  key: const Key('settings_notifications_row'),
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text('profile.settings.notifications.title'.tr()),
                  subtitle: Text(
                    'profile.settings.notifications.subtitle'.tr(),
                  ),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _onNotificationsChanged,
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  key: const Key('settings_sync_row'),
                  leading: Icon(
                    _isDirty
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                  ),
                  title: Text('profile.settings.sync.title'.tr()),
                  subtitle: Text(
                    _isDirty
                        ? 'profile.settings.sync.pending'.tr()
                        : 'profile.settings.sync.synced'.tr(),
                  ),
                  trailing: _isDirty
                      ? AppButton(
                          label: 'profile.settings.sync.sendNow'.tr(),
                          variant: AppButtonVariant.text,
                          expand: false,
                          onPressed: _onSendNow,
                        )
                      : null,
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  key: const Key('settings_app_version_row'),
                  leading: const Icon(Icons.info_outline),
                  title: Text('profile.settings.appVersion.title'.tr()),
                  trailing: const Text(_appVersion),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  key: const Key('settings_sign_out_row'),
                  leading: const Icon(Icons.logout, color: AppColors.critical),
                  title: Text(
                    'profile.settings.signOut.title'.tr(),
                    style: const TextStyle(color: AppColors.critical),
                  ),
                  onTap: _onSignOut,
                ),
              ],
            ),
    );
  }
}
