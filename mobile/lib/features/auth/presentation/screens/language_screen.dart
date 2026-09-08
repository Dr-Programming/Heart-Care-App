import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';
import '../widgets/language_choice.dart';

/// First-run only (FR-LOC-003): picks and persists the device's language,
/// then navigates to Login itself.
///
/// The redirect will not do this step for us: `AppRoutes.languagePath` is
/// itself one of `AppRoutes.publicPaths`, so once `hasChosenLanguage` flips
/// true the signed-out branch of `_redirect` sees we're already sitting on a
/// public path and returns null — "stay here." It only forces navigation
/// *onto* Login from a private route, never *between* public screens. Moving
/// on to Login is this screen's job, the same way Login and Register
/// navigate to each other explicitly.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  AppLanguage _selected = AppLanguage.en;
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      await ref.read(languageStoreProvider).write(_selected);
      // The gate reads this provider, not the store directly, so it has to
      // be told to re-read before `hasChosenLanguage` reflects the write.
      ref.invalidate(languageChosenProvider);
      await ref.read(languageChosenProvider.future);
      if (!mounted) return;
      context.goNamed(AppRoutes.login);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'auth.language.title'.tr(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'auth.language.subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          LanguageChoice(
            selected: _selected,
            onChanged: _saving
                ? (AppLanguage _) {}
                : (AppLanguage language) =>
                      setState(() => _selected = language),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: const Key('language_continue'),
            label: 'auth.language.continue'.tr(),
            isLoading: _saving,
            onPressed: _saving ? null : _continue,
          ),
        ],
      ),
    );
  }
}
