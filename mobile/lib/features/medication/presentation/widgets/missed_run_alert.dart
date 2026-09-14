import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';

class MissedRunAlert extends StatelessWidget {
  const MissedRunAlert({required this.medications, super.key});

  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SectionCard(
      title: 'meds.alert.missedRunTitle'.tr(),
      action: StatusChip(
        severity: Severity.monitor,
        label: 'meds.alert.missedRunChip'.tr(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final Medication medication in medications)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                'meds.alert.missedRunBody'.tr(
                  namedArgs: <String, String>{'name': medication.name},
                ),
                style: text.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
