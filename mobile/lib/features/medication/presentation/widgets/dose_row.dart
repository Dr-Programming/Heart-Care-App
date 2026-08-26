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
        // Capped with a maximum width instead of `Expanded`/proportional
        // `Flexible` on purpose: an even flex split reserves the same share
        // for the leading column regardless of how little its actual content
        // needs, starving the trailing status widget even when the
        // medication name is short (the common case). A `ConstrainedBox`
        // still protects this column from its own overflow on a long name
        // (it wraps within the cap instead of demanding unbounded width, the
        // same failure mode `Flexible` on the trailing side exists to avoid
        // below) while giving back whatever it doesn't use to the trailing
        // `Flexible`, which is the tighter, higher-priority constraint —
        // three tap targets versus one line of descriptive text.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
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
        // Wrapped in `Flexible` (rather than left as a bare trailing child)
        // so the trailing status widget can shrink or wrap instead of
        // forcing a hard `RenderFlex` overflow: it is the sole flex child in
        // this row, so it is offered the entire remainder left over after
        // the capped leading column — not a fixed 50/50 share — and can
        // still render smaller than that ceiling (a `StatusChip` pill keeps
        // hugging its own text rather than stretching to fill it).
        Flexible(
          child: dose.status == ScheduledDoseStatus.logged
              ? StatusChip(
                  severity: dose.doseLog!.status == DoseStatus.taken ? Severity.none : Severity.monitor,
                  label: 'meds.status.${dose.doseLog!.status.name}'.tr(),
                )
              : StatusSelector(onSelected: onLog),
        ),
      ],
    );
  }
}
