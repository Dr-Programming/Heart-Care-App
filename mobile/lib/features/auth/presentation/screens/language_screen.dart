import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/header_band.dart';
import '../widgets/primary_button.dart';

/// First-run language picker. Persisted; shown once, before Login.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  AppLanguage _selected = AppLanguage.en;

  Future<void> _continue() async {
    await ref.read(languageStoreProvider).write(_selected);
    if (!mounted) return;
    await context.setLocale(_selected.locale);
    ref.invalidate(languageChosenProvider);
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const HeaderBand(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  Text('language.title'.tr(),
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text('language.subtitle'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),
                  for (final AppLanguage language in AppLanguage.values) ...<Widget>[
                    _LanguageRow(
                      language: language,
                      selected: _selected == language,
                      onTap: () => setState(() => _selected = language),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const Spacer(),
                  PrimaryButton(
                      label: 'language.continue'.tr(), onPressed: _continue),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: Container(
        height: AppSpacing.fieldHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          border: Border.all(color: selected ? AppColors.ink : AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        ),
        child: Text(
          language.nativeLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? AppColors.surface : AppColors.ink,
              ),
        ),
      ),
    );
  }
}
