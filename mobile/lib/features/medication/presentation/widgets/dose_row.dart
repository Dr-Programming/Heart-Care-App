import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/scheduled_dose.dart';
import 'dose_note_sheet.dart';
import 'status_selector.dart';

/// What a dose row hands back when the patient records (or re-records) a dose.
///
/// [note] is the free-text note from [DoseNoteSheet] (FR-MED-008). It is
/// optional and named so the one-tap logging path — Decision 6 — can keep
/// calling `onLog(status)` with nothing extra.
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
              ? _LoggedDose(dose: dose, onLog: onLog)
              : StatusSelector(onSelected: (DoseStatus status) => onLog(status)),
        ),
      ],
    );
  }
}

/// The trailing half of an already-logged row: the status chip, plus the note
/// affordance that gives FR-MED-008 a UI (the `note` column was otherwise
/// plumbed all the way through the domain, data and sync layers with nothing
/// able to fill it).
///
/// Re-logging with a note is safe rather than duplicative: `logDose` is
/// idempotent per dose slot (medication + date + time — see I8 in
/// `MedicationRepositoryImpl.logDose`), so saving a note updates the row that
/// already exists instead of appending a second one.
class _LoggedDose extends StatelessWidget {
  const _LoggedDose({required this.dose, required this.onLog});

  final ScheduledDose dose;
  final DoseLogCallback onLog;

  @override
  Widget build(BuildContext context) {
    final DoseLog log = dose.doseLog!;
    final String? note = (log.note ?? '').trim().isEmpty ? null : log.note!.trim();

    // A `Wrap` for the same reason `StatusSelector` uses one: the chip and the
    // note button must be free to fall onto a second line rather than overflow
    // when the labels run long (Amharic, or a large text-scale factor).
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
    if (entered == null) return; // dismissed without saving
    onLog(log.status, note: entered.isEmpty ? null : entered);
  }
}
