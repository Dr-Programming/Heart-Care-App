import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/scheduled_dose.dart';
import 'status_selector.dart';

class DoseRow extends StatelessWidget {
  const DoseRow({required this.dose, required this.onLog, super.key});

  final ScheduledDose dose;
  final ValueChanged<DoseStatus> onLog;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String doseLabel = dose.doseMg == dose.doseMg.roundToDouble()
        ? dose.doseMg.toStringAsFixed(0)
        : dose.doseMg.toString();

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(dose.medicationName, style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('${dose.scheduledTime} · $doseLabel mg', style: text.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (dose.status == ScheduledDoseStatus.logged)
          StatusChip(
            severity: dose.doseLog!.status == DoseStatus.taken ? Severity.none : Severity.monitor,
            label: 'meds.status.${dose.doseLog!.status.name}'.tr(),
          )
        else
          StatusSelector(onSelected: onLog),
      ],
    );
  }
}
