import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/theme/app_spacing.dart';
import 'package:libu_care/core/utils/date_formatter.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';

/// One history entry: its formatted value, when it was measured, its
/// clinical status, and — if still owed to the server — a pending-sync icon.
class ReadingRow extends StatelessWidget {
  const ReadingRow({required this.reading, this.syncStatus, super.key});

  final VitalReading reading;
  final LocalSyncStatus? syncStatus;

  @override
  Widget build(BuildContext context) {
    final String languageCode = context.locale.languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _formatValue(reading),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  DateFormatter.displayDateTime(
                    reading.measuredAt,
                    languageCode,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (syncStatus == LocalSyncStatus.pending) ...<Widget>[
            const Icon(Icons.cloud_upload_outlined, size: 16),
            const SizedBox(width: AppSpacing.sm),
          ],
          StatusChip.flagged(flagged: reading.flagged),
        ],
      ),
    );
  }

  String _formatValue(VitalReading r) {
    final String unit = vitalDescriptors[r.type]!.unit;
    final String value = switch (r.type) {
      VitalType.bloodPressure =>
        '${r.values['systolic']!.toStringAsFixed(0)}/${r.values['diastolic']!.toStringAsFixed(0)}',
      VitalType.glucose => r.values['glucose']!.toStringAsFixed(1),
      VitalType.heartRate => r.values['heartRate']!.toStringAsFixed(0),
      VitalType.weight => r.values['weight']!.toStringAsFixed(1),
      VitalType.cholesterol => r.values['total']!.toStringAsFixed(1),
    };
    return '$value $unit';
  }
}
