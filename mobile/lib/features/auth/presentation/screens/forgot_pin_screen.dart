import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Guidance only — there is no self-service PIN reset in this slice
/// (M1 spec Decision 4). Must not imply otherwise.
class ForgotPinScreen extends StatelessWidget {
  const ForgotPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'auth.forgotPin.title'.tr(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text('auth.forgotPin.body'.tr(), style: text.bodyLarge),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'auth.forgotPin.back'.tr(),
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
