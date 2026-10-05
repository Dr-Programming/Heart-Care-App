import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clinical/alert_evaluator.dart';
import '../../core/error/failure.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/widgets.dart';
import '../../features/vitals/presentation/widgets/range_toggle.dart';
import 'visit_summary.dart';
import 'visit_summary_controller.dart';
import 'visit_summary_pdf.dart';

/// A one-page summary for the patient's next clinic visit, with a PDF
/// export to show or send to the clinician.
class VisitSummaryScreen extends ConsumerStatefulWidget {
  const VisitSummaryScreen({super.key});

  @override
  ConsumerState<VisitSummaryScreen> createState() => _VisitSummaryScreenState();
}

class _VisitSummaryScreenState extends ConsumerState<VisitSummaryScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _exporting = false;

  Future<void> _savePdf() async {
    final RenderObject? render = _captureKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) return;
    setState(() => _exporting = true);
    try {
      await VisitSummaryPdf.share(
        render,
        filename:
            'visit-summary-${DateFormatter.toApiDate(DateTime.now())}.pdf',
      );
    } on Object {
      if (mounted) {
        showAppToast(context, 'visitSummary.pdfFailed'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VisitSummary> state = ref.watch(
      visitSummaryControllerProvider,
    );
    final VisitSummaryController controller = ref.read(
      visitSummaryControllerProvider.notifier,
    );
    final String? name = ref.watch(cachedUserProvider).value?.name;
    final String today = DateFormatter.displayDate(
      DateTime.now(),
      context.locale.languageCode,
    );

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: BandHeader(
        title: 'visitSummary.title'.tr(),
        subtitle: 'visitSummary.subtitle'.tr(
          namedArgs: <String, String>{'date': today},
        ),
      ),
      bottomBar: state.hasValue
          ? AppButton(
              label: 'visitSummary.savePdf'.tr(),
              icon: Icons.picture_as_pdf_outlined,
              variant: AppButtonVariant.secondary,
              isLoading: _exporting,
              onPressed: _savePdf,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: RangeToggle(
              selectedDays: controller.windowDays,
              onChanged: controller.setWindowDays,
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace _) => ErrorView(
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () => controller.setWindowDays(controller.windowDays),
              ),
              data: (VisitSummary summary) => SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: RepaintBoundary(
                  key: _captureKey,
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: _SummaryBody(
                      summary: summary,
                      patientName: name,
                      date: today,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.summary,
    required this.patientName,
    required this.date,
  });

  final VisitSummary summary;
  final String? patientName;
  final String date;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String window = 'visitSummary.window'.tr(
      namedArgs: <String, String>{'days': '${summary.windowDays}'},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (patientName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'visitSummary.patient'.tr(
                namedArgs: <String, String>{'name': patientName!, 'date': date},
              ),
              style: text.bodySmall,
            ),
          ),
        _OverallCard(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        _SectionLabel(
          'visitSummary.vitalsTitle'.tr(
            namedArgs: <String, String>{'window': window},
          ),
        ),
        SectionCard(
          child: Column(
            children: <Widget>[
              _VitalRow(
                label: 'visitSummary.bp'.tr(),
                value: summary.bpSystolic == null
                    ? null
                    : '${summary.bpSystolic!.toStringAsFixed(0)} / ${summary.bpDiastolic!.toStringAsFixed(0)}',
                unit: 'mmHg',
                chip: summary.bpSystolic == null
                    ? null
                    : summary.attention.contains(AttentionReason.bpCritical)
                    ? (Severity.urgent, 'visitSummary.chip.critical'.tr())
                    : summary.bpAboveTarget
                    ? (Severity.monitor, 'visitSummary.chip.aboveTarget'.tr())
                    : (Severity.none, 'visitSummary.chip.onTarget'.tr()),
              ),
              _VitalRow(
                label: 'visitSummary.heartRate'.tr(),
                value: summary.heartRate?.toStringAsFixed(0),
                unit: 'bpm',
                chip: summary.heartRate == null
                    ? null
                    : summary.attention.contains(
                        AttentionReason.heartRateOutOfRange,
                      )
                    ? (Severity.monitor, 'visitSummary.chip.outOfRange'.tr())
                    : (Severity.none, 'visitSummary.chip.normal'.tr()),
              ),
              _VitalRow(
                label: 'visitSummary.glucose'.tr(),
                value: summary.glucose?.toStringAsFixed(1),
                unit: 'mmol/L',
                chip: summary.glucose == null
                    ? null
                    : summary.attention.contains(
                        AttentionReason.glucoseOutOfRange,
                      )
                    ? (Severity.monitor, 'visitSummary.chip.outOfRange'.tr())
                    : (Severity.none, 'visitSummary.chip.inRange'.tr()),
              ),
              _VitalRow(
                label: 'visitSummary.weight'.tr(),
                value: summary.weight?.toStringAsFixed(1),
                unit: 'kg',
                chip: summary.weightChange == null
                    ? null
                    : (
                        Severity.none,
                        '${summary.weightChange! > 0 ? '+' : ''}${summary.weightChange!.toStringAsFixed(1)} kg',
                      ),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionLabel('visitSummary.medsTitle'.tr()),
        _AdherenceCard(summary: summary, window: window),
        const SizedBox(height: AppSpacing.lg),
        _SectionLabel(
          'visitSummary.symptomsTitle'.tr(
            namedArgs: <String, String>{'window': window},
          ),
        ),
        _SymptomsCard(summary: summary),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.summary});

  final VisitSummary summary;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final (Severity severity, String label) = switch (summary.status) {
      VisitStatus.needsAttention => (
        Severity.monitor,
        'visitSummary.status.needsAttention'.tr(),
      ),
      VisitStatus.stable => (Severity.none, 'visitSummary.status.stable'.tr()),
      VisitStatus.noData => (Severity.none, 'visitSummary.status.noData'.tr()),
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('visitSummary.overall'.tr(), style: text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          StatusChip(severity: severity, label: label),
          const SizedBox(height: AppSpacing.sm),
          if (summary.status == VisitStatus.noData)
            Text('visitSummary.noDataBody'.tr(), style: text.bodyMedium)
          else if (summary.attention.isEmpty)
            Text('visitSummary.stableBody'.tr(), style: text.bodyMedium)
          else
            for (final AttentionReason reason in summary.attention)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('•  '),
                    Expanded(
                      child: Text(
                        'visitSummary.reason.${reason.name}'.tr(
                          namedArgs: <String, String>{
                            'sys': summary.targetSystolic.toStringAsFixed(0),
                            'dia': summary.targetDiastolic.toStringAsFixed(0),
                          },
                        ),
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  const _VitalRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.chip,
    this.last = false,
  });

  final String label;
  final String? value;
  final String unit;
  final (Severity, String)? chip;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(flex: 4, child: Text(label, style: text.bodySmall)),
          Expanded(
            flex: 5,
            child: value == null
                ? Text('common.noValue'.tr(), style: text.bodyMedium)
                : Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: value, style: text.titleMedium),
                        TextSpan(text: '  $unit', style: text.labelSmall),
                      ],
                    ),
                  ),
          ),
          if (chip != null) StatusChip(severity: chip!.$1, label: chip!.$2),
        ],
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.summary, required this.window});

  final VisitSummary summary;
  final String window;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int? percent = summary.adherencePercent;
    final int? change = summary.adherenceChange;
    final bool good =
        percent != null && percent >= VisitSummary.adherenceGoal * 100;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'visitSummary.adherence'.tr(
              namedArgs: <String, String>{'window': window},
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (percent == null)
            Text('visitSummary.noDoses'.tr(), style: text.bodyMedium)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  '$percent%',
                  style: text.headlineLarge?.copyWith(
                    color: good ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'visitSummary.doses'.tr(
                      namedArgs: <String, String>{
                        'taken': '${summary.adherence.taken}',
                        'due': '${summary.adherence.due}',
                      },
                    ),
                    style: text.bodySmall,
                  ),
                ),
                if (change != null)
                  Text(
                    change >= 0 ? '↑ +$change%' : '↓ $change%',
                    style: text.bodySmall?.copyWith(
                      color: change >= 0
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
              ],
            ),
          if (summary.dailyAdherence.any((bool? d) => d != null)) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                for (
                  int i = 0;
                  i < summary.dailyAdherence.length;
                  i++
                ) ...<Widget>[
                  if (i > 0)
                    SizedBox(
                      width: summary.dailyAdherence.length > 7
                          ? 2
                          : AppSpacing.xs,
                    ),
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: switch (summary.dailyAdherence[i]) {
                          true => AppColors.success,
                          false => AppColors.critical,
                          null => AppColors.surfaceAlt,
                        },
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SymptomsCard extends StatelessWidget {
  const _SymptomsCard({required this.summary});

  final VisitSummary summary;

  @override
  Widget build(BuildContext context) {
    String days(int n) => 'visitSummary.days'.plural(n);
    final List<(String, String)> cells = <(String, String)>[
      (
        'visitSummary.chestPain'.tr(),
        'visitSummary.episodes'.plural(summary.chestPainDays),
      ),
      ('visitSummary.swelling'.tr(), days(summary.swellingDays)),
      (
        'visitSummary.breath'.tr(),
        summary.breathlessSevereDays > 0
            ? 'visitSummary.breathSevere'.tr(
                namedArgs: <String, String>{
                  'mild': '${summary.breathlessMildDays}',
                  'severe': '${summary.breathlessSevereDays}',
                },
              )
            : 'visitSummary.breathMild'.plural(summary.breathlessMildDays),
      ),
      (
        'visitSummary.energy'.tr(),
        summary.averageEnergy == null
            ? 'common.noValue'.tr()
            : '${summary.averageEnergy} / 10',
      ),
    ];
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int row = 0; row < 2; row++) ...<Widget>[
            if (row > 0) const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int col = 0; col < 2; col++)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(cells[row * 2 + col].$1, style: text.bodySmall),
                        const SizedBox(height: 2),
                        Text(cells[row * 2 + col].$2, style: text.titleSmall),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'visitSummary.checkIns'.plural(summary.checkInCount),
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }
}
