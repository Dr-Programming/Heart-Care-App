import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('auth.language.title'.tr(), style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text('auth.language.subtitle'.tr(), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
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
