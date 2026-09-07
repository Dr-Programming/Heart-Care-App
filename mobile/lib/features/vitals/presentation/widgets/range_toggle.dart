import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The 7-day / 30-day switch atop a trend chart.
class RangeToggle extends StatelessWidget {
  const RangeToggle({
    required this.windowDays,
    required this.onChanged,
    super.key,
  });

  final int windowDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        ButtonSegment<int>(value: 7, label: Text('vitals.range7'.tr())),
        ButtonSegment<int>(value: 30, label: Text('vitals.range30'.tr())),
      ],
      selected: <int>{windowDays},
      onSelectionChanged: (Set<int> selection) => onChanged(selection.first),
    );
  }
}
