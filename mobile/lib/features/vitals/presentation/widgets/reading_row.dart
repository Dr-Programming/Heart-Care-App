import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/vital_descriptors.dart';

class ReadingRow extends StatelessWidget {
  const ReadingRow({required this.reading, required this.localeCode, super.key});

  final VitalReading reading;
  final String localeCode;

  String _formatValue() {
    switch (reading.type.wire) {
      case 'BLOOD_PRESSURE':
        return '${reading.values['systolic']!.toStringAsFixed(0)}/${reading.values['diastolic']!.toStringAsFixed(0)} mmHg';
      case 'GLUCOSE':
        return '${reading.values['glucose']!.toStringAsFixed(1)} mmol/L';
      case 'HEART_RATE':
        return '${reading.values['heartRate']!.toStringAsFixed(0)} bpm';
      case 'WEIGHT':
        final String bmiPart = reading.bmi == null
            ? ''
            : ' · BMI ${reading.bmi!.toStringAsFixed(1)}';
        return '${reading.values['weight']!.toStringAsFixed(1)} kg$bmiPart';
      case 'CHOLESTEROL':
        return '${reading.values['total']!.toStringAsFixed(1)} mmol/L total';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Severity severity = severityForVital(
      type: reading.type.wire,
      values: reading.values.cast<String, num?>(),
      bmi: reading.bmi,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  vitalDescriptors[reading.type]!.labelKey.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(_formatValue(), style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  DateFormatter.displayDateTime(reading.measuredAt, localeCode),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          StatusChip(severity: severity),
        ],
      ),
    );
  }
}
