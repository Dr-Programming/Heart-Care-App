import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/adherence.dart';
import '../../domain/entities/medication.dart';
import '../controllers/adherence_controller.dart';

/// "12 of 14 doses (86%)", or the honest no-data line.
///
/// Decision 5: the denominator is always shown, never a bare percentage — a
/// figure computed from two due doses must not read like one computed from
/// sixty. The percentage rides alongside it because it is the number a
/// patient (and their health worker) actually compares week to week, and
/// `Adherence.percentage` existed with no reader at all until finding I4.
String adherenceLabel(Adherence? adherence) {
  if (adherence == null || !adherence.hasData) {
    return 'meds.adherence.noData'.tr();
  }
  return 'meds.adherence.countWithPercent'.tr(
    namedArgs: <String, String>{
      'taken': '${adherence.taken}',
      'due': '${adherence.due}',
      'percent': '${(adherence.percentage! * 100).round()}',
    },
  );
}

class AdherenceScreen extends ConsumerWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdherenceState> state = ref.watch(adherenceControllerProvider);

    return AppScaffold(
      title: 'meds.adherence.title'.tr(),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => ErrorView(
          failure: e is Failure ? e : UnknownFailure(e.toString()),
          onRetry: () => ref.invalidate(adherenceControllerProvider),
        ),
        data: (AdherenceState data) => ListView(
          children: <Widget>[
            _AdherenceCard(title: 'meds.adherence.overall7'.tr(), adherence: data.overall7),
            const SizedBox(height: AppSpacing.md),
            _AdherenceCard(title: 'meds.adherence.overall30'.tr(), adherence: data.overall30),
            if (data.medications.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _PerMedicationCard(state: data),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.title, required this.adherence});

  final String title;
  final Adherence adherence;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Text(
        adherenceLabel(adherence),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

/// The per-medication breakdown (I4).
///
/// `AdherenceController` computed `perMedication7`/`perMedication30` from the
/// start; nothing rendered them, so a patient on three medications could only
/// see one pooled figure and had no way to tell which one they were actually
/// missing.
class _PerMedicationCard extends StatelessWidget {
  const _PerMedicationCard({required this.state});

  final AdherenceState state;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SectionCard(
      title: 'meds.adherence.perMedication'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final Medication medication in state.medications)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(medication.name, style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${'meds.adherence.overall7'.tr()} · '
                    '${adherenceLabel(state.perMedication7[medication.clientRecordId])}',
                    style: text.bodySmall,
                  ),
                  Text(
                    '${'meds.adherence.overall30'.tr()} · '
                    '${adherenceLabel(state.perMedication30[medication.clientRecordId])}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
