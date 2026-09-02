import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../language_actions.dart';
import '../providers/profile_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.lg,
              ),
              color: AppColors.headerBand,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.ink,
                  ),
                  Expanded(
                    child: Text(
                      'profile.settings.title'.tr(),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  Text(
                    'profile.settings.preferencesSection'.tr(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  profileAsync.when(
                    loading: () => const _SettingsCard(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (profile) {
                      final language =
                          AppLanguage.fromCode(profile.preferredLanguage) ??
                              AppLanguage.en;
                      return _SettingsCard(
                        children: [
                          _SettingsRow(
                            icon: Icons.language,
                            label: 'profile.settings.language'.tr(),
                            trailing: Text(
                              language.nativeLabel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            onTap: () => _showLanguagePicker(
                              context,
                              ref,
                              language,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'profile.settings.syncSection'.tr(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.sync,
                        label: 'profile.settings.pendingSync'.tr(),
                        trailing: pendingSync.when(
                          loading: () => const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, _) => Text('common.noValue'.tr()),
                          data: (count) => Text(
                            count == 0
                                ? 'profile.settings.upToDate'.tr()
                                : 'sync.pending'.tr(
                                    namedArgs: {'count': count.toString()},
                                  ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _SettingsCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.logout,
                        label: 'home.signOut'.tr(),
                        labelColor: AppColors.critical,
                        onTap: () => _confirmSignOut(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext screenContext,
    WidgetRef ref,
    AppLanguage current,
  ) {
    showModalBottomSheet<void>(
      context: screenContext,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in AppLanguage.values)
              ListTile(
                title: Text(language.nativeLabel),
                trailing:
                    current == language ? const Icon(Icons.check) : null,
                onTap: () async {
                  // Use the screen's own context, not the sheet's — the
                  // sheet's context stops being mounted as soon as it is
                  // popped, and `changeAppLanguage` needs a live context to
                  // call `setLocale` on.
                  Navigator.of(sheetContext).pop();
                  await changeAppLanguage(screenContext, ref, language);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile.settings.signOutTitle'.tr()),
        content: Text('profile.settings.signOutBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('home.signOut'.tr()),
          ),
        ],
      ),
    );

    // TODO(M2/M1): call the real sign-out once M1's AuthGate/session
    // management lands — there is no session to clear yet.
    if (confirmed == true) {
      // ignore: use_build_context_synchronously
      if (context.mounted) context.go('/');
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      // A ListTile paints its ink splashes on the nearest Material ancestor,
      // which — without this — would be the app's opaque scaffold beneath
      // this card's own coloured background, hiding every tap's feedback.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // 44dp minimum tap target (FR-LOC-006): ListTile's default is already
      // close, but pin it so a theme change cannot shrink it below that.
      minVerticalPadding: AppSpacing.sm,
      leading: Icon(icon, color: labelColor ?? AppColors.ink),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: labelColor,
            ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
