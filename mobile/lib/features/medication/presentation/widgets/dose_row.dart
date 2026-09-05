import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/scheduled_dose.dart';
import 'dose_note_sheet.dart';
import 'status_selector.dart';

typedef DoseLogCallback = void Function(DoseStatus status, {String? note});

class DoseRow extends StatelessWidget {
  const DoseRow({required this.dose, required this.onLog, super.key});

  final ScheduledDose dose;
  final DoseLogCallback onLog;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String doseLabel = dose.doseMg == dose.doseMg.roundToDouble()
        ? dose.doseMg.toStringAsFixed(0)
        : dose.doseMg.toString();

    return Row(
      children: <Widget>[

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

        Flexible(
          child: dose.status == ScheduledDoseStatus.logged
              ? _LoggedDose(dose: dose, onLog: onLog)
              : StatusSelector(onSelected: (DoseStatus status) => onLog(status)),
        ),
      ],
    );
  }
}

class _LoggedDose extends StatelessWidget {
  const _LoggedDose({required this.dose, required this.onLog});

  final ScheduledDose dose;
  final DoseLogCallback onLog;

  @override
  Widget build(BuildContext context) {
    final DoseLog log = dose.doseLog!;
    final String? note = (log.note ?? '').trim().isEmpty ? null : log.note!.trim();

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        StatusChip(
          severity: log.status == DoseStatus.taken ? Severity.none : Severity.monitor,
          label: 'meds.status.${log.status.name}'.tr(),
        ),
        if (note != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(note, style: Theme.of(context).textTheme.bodySmall),
          ),
        AppButton(
          label: note == null ? 'meds.note.add'.tr() : 'meds.note.edit'.tr(),
          variant: AppButtonVariant.text,
          expand: false,
          onPressed: () => _editNote(context, log),
        ),
      ],
    );
  }

  Future<void> _editNote(BuildContext context, DoseLog log) async {
    final String? entered = await DoseNoteSheet.show(context, initialNote: log.note);
    if (entered == null) return;
    onLog(log.status, note: entered.isEmpty ? null : entered);
  }
}
