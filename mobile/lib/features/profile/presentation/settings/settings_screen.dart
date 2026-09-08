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
import '../sign_out_actions.dart';

/// Hardcoded to match `pubspec.yaml`'s `version:` line. There is no
/// `package_info_plus` dependency yet to read this live, and `pubspec.yaml`
/// is outside M2's editable region (see the M2 design spec §7) — so this
/// constant has to be kept in sync by hand until someone adds that package
/// to the shared pubspec. Flagged rather than silently guessed.
const String _appVersion = 'v1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(patientProfileProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);
    final notificationsEnabledAsync = ref.watch(notificationsEnabledProvider);
    final symptomPromptTimeAsync = ref.watch(symptomPromptTimeProvider);

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
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsCard(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: Text('profile.fields.notificationsEnabled'.tr()),
                        value: notificationsEnabledAsync.value ?? true,
                        onChanged: notificationsEnabledAsync.isLoading
                            ? null
                            : (value) => _setNotificationsEnabled(
                                  ref,
                                  value,
                                  symptomPromptTimeAsync.value,
                                ),
                      ),
                      if ((notificationsEnabledAsync.value ?? true))
                        _SettingsRow(
                          icon: Icons.access_time,
                          label: 'profile.fields.symptomPromptTime'.tr(),
                          trailing: Text(
                            _formatTimeLabel(
                              context,
                              symptomPromptTimeAsync.value,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () => _pickSymptomPromptTime(
                            context,
                            ref,
                            symptomPromptTimeAsync.value,
                          ),
                        ),
                    ],
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
                      _SettingsRow(
                        icon: Icons.cloud_upload_outlined,
                        label: 'sync.syncNow'.tr(),
                        onTap: () => _syncNow(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'profile.settings.aboutSection'.tr(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.info_outline,
                        label: 'profile.settings.appVersion'.tr(),
                        trailing: Text(
                          _appVersion,
                          style: Theme.of(context).textTheme.bodyMedium,
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
                        onTap: () => confirmSignOut(context, ref),
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

  /// Formats the stored `HH:mm` string for display, falling back to the
  /// wizard's default the first time this screen is opened with nothing
  /// saved yet.
  String _formatTimeLabel(BuildContext context, String? stored) {
    final time = _parseTime(stored) ?? const TimeOfDay(hour: 19, minute: 30);
    return time.format(context);
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeValue(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _setNotificationsEnabled(
    WidgetRef ref,
    bool value,
    String? currentSymptomPromptTime,
  ) async {
    await ref.read(reminderPrefsProvider).write(
          notificationsEnabled: value,
          symptomPromptTime: currentSymptomPromptTime ?? '19:30',
        );
    ref.invalidate(notificationsEnabledProvider);
  }

  Future<void> _pickSymptomPromptTime(
    BuildContext context,
    WidgetRef ref,
    String? currentValue,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _parseTime(currentValue) ?? const TimeOfDay(hour: 19, minute: 30),
    );
    if (picked == null) return;

    await ref.read(reminderPrefsProvider).write(
          notificationsEnabled: true,
          symptomPromptTime: _formatTimeValue(picked),
        );
    ref.invalidate(symptomPromptTimeProvider);
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final report = await ref.read(syncServiceProvider).syncNow();

    if (!context.mounted) return;

    final String message;
    if (report.skippedOffline) {
      message = 'sync.offlineTitle'.tr();
    } else if (report.failure != null) {
      message = 'sync.failed'.tr();
    } else if (report.rejected > 0) {
      message = 'sync.rejected'.tr(
        namedArgs: {'count': report.rejected.toString()},
      );
    } else if (!report.didWork) {
      message = 'profile.settings.upToDate'.tr();
    } else {
      message = 'sync.syncNow'.tr();
    }

    messenger.showSnackBar(SnackBar(content: Text(message)));
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