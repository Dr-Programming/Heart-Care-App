import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../controllers/auth_controller.dart';
import '../widgets/header_band.dart';
import '../widgets/primary_button.dart';

/// Placeholder shell. The real dashboard is a later slice — this exists to
/// prove the session survives a cold start with no network.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState? state = ref.watch(authControllerProvider).valueOrNull;
    final String name = state is AuthAuthenticated ? state.user.name : '';

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
                  Text(
                    'home.greeting'.tr(namedArgs: <String, String>{'name': name}),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'home.signOut'.tr(),
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
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
