import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// The cream band with the Libu Care mark that tops every screen in the design
/// (Figma frames `368:680` / `368:632`).
class HeaderBand extends StatelessWidget {
  const HeaderBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.headerBandHeight,
      width: double.infinity,
      color: AppColors.headerBand,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.logoTopInset),
        child: Image.asset(
          'assets/images/libu_care_logo.png',
          height: AppSpacing.logoHeight,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
