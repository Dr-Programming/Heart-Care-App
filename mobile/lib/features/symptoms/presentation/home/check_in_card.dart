import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_history_entry.dart';
import '../providers/symptom_providers.dart';

/// Home card, order 110 (FR-DASH-001…009) — today's check-in prompt, or its
/// result once done. Must never throw: a card that crashes takes the whole
/// dashboard down with it, so a stream error degrades to "—" the same way
/// an empty result does.
class CheckInHomeCard extends ConsumerWidget {
  const CheckInHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SymptomHistoryEntry?> today = ref.watch(
      todayCheckInProvider,
    );

    return SectionCard(
      title: 'symptoms.home.title'.tr(),
      child: today.when(
        data: (SymptomHistoryEntry? entry) => entry == null
            ? MetricTile(
                label: 'symptoms.home.status'.tr(),
                value: 'common.noValue'.tr(),
                caption: 'symptoms.home.notDoneYet'.tr(),
              )
            : _DoneMetric(entry: entry),
        loading: () => MetricTile(
          label: 'symptoms.home.status'.tr(),
          value: 'common.loading'.tr(),
        ),
        error: (Object _, StackTrace _) => MetricTile(
          label: 'symptoms.home.status'.tr(),
          value: 'common.noValue'.tr(),
        ),
      ),
    );
  }
}

/// Combines today's check-in with the missed-dose cross-signal
/// (FR-DEC-003), same as the check-in hub — whichever is more severe wins,
/// since there is no standalone Alerts screen to show them separately
/// (design decision 4).
class _DoneMetric extends ConsumerWidget {
  const _DoneMetric({required this.entry});

  final SymptomHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Severity> cross = ref.watch(crossSignalProvider);
    final Severity effective = cross.maybeWhen(
      data: (Severity s) => entry.overallSeverity.coalesce(s),
      orElse: () => entry.overallSeverity,
    );

    return MetricTile(
      label: 'symptoms.home.status'.tr(),
      value: 'symptoms.home.done'.tr(),
      trailing: StatusChip(severity: effective),
    );
  }
}
