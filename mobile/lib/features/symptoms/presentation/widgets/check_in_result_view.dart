import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/activity_guidance.dart';
import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/symptom_check_in.dart';
import 'activity_guidance_card.dart';

/// The full result of one check-in: overall rating, what the patient
/// answered for each question with its rating, and, for today's check-in,
/// the activity advice. Shown right after a check-in and from the history.
class CheckInResultView extends StatelessWidget {
  const CheckInResultView({
    required this.result,
    this.fromHistory = false,
    this.onDone,
    super.key,
  });

  final SymptomCheckIn result;

  /// Opened from the history: titled with the date instead of "today".
  final bool fromHistory;

  /// Shows a Done button when set.
  final VoidCallback? onDone;

  /// Order the answers are listed in, matching the check-in form.
  static const List<String> fields = <String>[
    'chestPain',
    'shortnessOfBreath',
    'swelling',
    'heartRate',
    'bloodPressure',
    'energyLevel',
  ];

  bool get _isToday {
    final DateTime now = DateTime.now();
    final DateTime at = result.measuredAt.toLocal();
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = context.locale.languageCode;
    final bool worse = result.data['worseThanYesterday'] is Map;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: <Widget>[
        Text('symptoms.summary.title'.tr(), style: text.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          fromHistory
              ? DateFormatter.displayDateTime(result.measuredAt, locale)
              : 'symptoms.summary.subtitle'.tr(),
          key: const Key('checkInResultSubtitle'),
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'symptoms.summary.overall'.tr(),
                    style: text.titleMedium,
                  ),
                  StatusChip(severity: result.overall),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(actionKeyFor(result.overall).tr(), style: text.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // The advice is about today, so an older check-in leaves it out.
        if (_isToday) ...<Widget>[
          ActivityGuidanceCard(
            guidance: activityGuidanceFor(
              overall: result.overall,
              perSymptom: result.perSymptom,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('symptoms.summary.yourAnswers'.tr(), style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final String field in fields)
          _AnswerRow(
            key: Key('checkInAnswer_$field'),
            label: 'symptoms.summary.field.$field'.tr(),
            answer: _answerFor(field),
            severity: result.perSymptom[field],
          ),
        if (worse)
          _AnswerRow(
            key: const Key('checkInAnswer_worse'),
            label: 'symptoms.checkIn.worseThanYesterday'.tr(),
            answer: 'symptoms.checkIn.yes'.tr(),
          ),
        if (result.note != null && result.note!.trim().isNotEmpty)
          _AnswerRow(
            key: const Key('checkInAnswer_note'),
            label: 'symptoms.checkIn.note'.tr(),
            answer: result.note!.trim(),
          ),
        if (onDone != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'symptoms.summary.done'.tr(), onPressed: onDone),
        ],
      ],
    );
  }

  /// What the patient entered for [field], in words or numbers.
  String _answerFor(String field) {
    final Map<String, dynamic> data = result.data;
    switch (field) {
      case 'chestPain':
        if (!result.chestPainPresent) return 'symptoms.checkIn.none'.tr();
        final Object? raw = (data['chestPain'] as Map)['severity'];
        final num level = raw is num ? raw : 0;
        if (level >= 7) return 'symptoms.checkIn.severe'.tr();
        if (level >= 4) return 'symptoms.checkIn.moderate'.tr();
        return 'symptoms.checkIn.mild'.tr();
      case 'shortnessOfBreath':
        return switch (result.shortnessOfBreath) {
          'SEVERE' => 'symptoms.checkIn.severe'.tr(),
          'MILD' => 'symptoms.checkIn.mild'.tr(),
          _ => 'symptoms.checkIn.none'.tr(),
        };
      case 'swelling':
        return result.swelling
            ? 'symptoms.checkIn.yes'.tr()
            : 'symptoms.checkIn.no'.tr();
      case 'heartRate':
        final Object? hr = data['heartRate'];
        return hr is num ? '${hr.round()} bpm' : '-';
      case 'bloodPressure':
        final Object? bp = data['bloodPressure'];
        if (bp is! Map || bp['systolic'] is! num || bp['diastolic'] is! num) {
          return '-';
        }
        return '${(bp['systolic'] as num).round()}/'
            '${(bp['diastolic'] as num).round()} mmHg';
      case 'energyLevel':
        return '${result.energyLevel} / 10';
    }
    return '-';
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.label,
    required this.answer,
    this.severity,
    super.key,
  });

  final String label;
  final String answer;
  final Severity? severity;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SectionCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: text.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(answer, style: text.titleMedium),
                ],
              ),
            ),
            if (severity != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              StatusChip(severity: severity!),
            ],
          ],
        ),
      ),
    );
  }
}
