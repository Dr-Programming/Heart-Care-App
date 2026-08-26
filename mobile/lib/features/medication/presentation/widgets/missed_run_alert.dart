import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';

/// The adherence alert for FR-DEC-002 / FR-NOT-003: two doses of the same
/// medication missed in a row.
///
/// Whether the run exists is decided by `core/clinical`'s
/// `hasConsecutiveMissedDoses` (see `MedicationListController`); this widget
/// only renders the verdict. `Severity.monitor` rather than `urgent` — a
/// missed run is worth noticing and asking about, not an emergency, and the
/// escalation to urgent is FR-DEC-003's cross-signal with symptoms, which is
/// M5's to compose.
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
