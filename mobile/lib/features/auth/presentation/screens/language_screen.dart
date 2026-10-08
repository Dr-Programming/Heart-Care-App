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

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: BandHeader(
        title: 'auth.language.title'.tr(),
        subtitle: 'auth.language.subtitle'.tr(),
        showBack: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final language in AppLanguage.values) ...<Widget>[
              AppButton(
                label: language.nativeLabel,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  await ref.read(languageStoreProvider).write(language);

                  await ref.read(realAuthGateProvider.notifier).refresh();
                  if (!context.mounted) return;
                  await context.setLocale(language.locale);
                  if (context.mounted) context.goNamed(AppRoutes.login);
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
