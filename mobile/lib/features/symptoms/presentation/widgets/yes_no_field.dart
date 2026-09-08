import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A binary symptom question — "chest pain?", "swelling?" — answered in one
/// tap. Defaults to "No" on the check-in screen (design decision 1), so the
/// common "I'm fine today" case never has to touch this control at all.
class YesNoField extends StatelessWidget {
  const YesNoField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: AppSpacing.md),
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text('symptoms.common.no'.tr()),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text('symptoms.common.yes'.tr()),
            ),
          ],
          selected: <bool>{value},
          showSelectedIcon: false,
          onSelectionChanged: (Set<bool> selection) =>
              onChanged(selection.first),
        ),
      ],
    );
  }
}
