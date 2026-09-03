import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../widgets/header_band.dart';
import '../widgets/primary_button.dart';

/// Information only. There is no self-service PIN reset on the server, so this
/// screen must not imply one exists — it explains the lockout and points at
/// the clinic instead.
class ForgotPinScreen extends StatelessWidget {
  const ForgotPinScreen({super.key});

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
                  Text('forgotPin.title'.tr(),
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.lg),
                  Text('forgotPin.body'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  PrimaryButton(
                    label: 'forgotPin.back'.tr(),
                    onPressed: () => context.pop(),
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
