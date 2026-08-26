import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({required this.medication, this.onTap, super.key});

  final Medication medication;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String dose = medication.doseMg == medication.doseMg.roundToDouble()
        ? medication.doseMg.toStringAsFixed(0)
        : medication.doseMg.toString();

    return SectionCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Icon(Iconsax.health, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('${medication.name} $dose mg', style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  medication.scheduleTimes.join(' · '),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
