import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shown only while `AuthGate.isResolved` is false — a local JWT check, never
/// a network call, so this must be on screen for a blink, not a wait.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.headerBand,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Iconsax.heart5, size: 56, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text('app.name'.tr(), style: text.displayLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('app.tagline'.tr(), style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
