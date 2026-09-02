import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_spacing.dart';
import 'selectable_chip.dart';

/// The curated comorbidity list (M2 design, Decision 6).
///
/// A free-text-only field produces "sukar", "ስኳር" and "diabetes" as three
/// different conditions and is useless to aggregate. [value] is the stable,
/// English, wire-format string that is actually stored and sent to the
/// server; [labelKey] is what gets shown, in whichever language is active.
/// Never show [value] to a patient and never store the translated label.
enum ComorbidityOption {
  diabetes('diabetes', 'profile.comorbidityOptions.diabetes'),
  hypertension('hypertension', 'profile.comorbidityOptions.hypertension'),
  kidneyDisease(
    'kidney_disease',
    'profile.comorbidityOptions.kidneyDisease',
  ),
  highCholesterol(
    'high_cholesterol',
    'profile.comorbidityOptions.highCholesterol',
  ),
  previousHeartAttack(
    'previous_heart_attack',
    'profile.comorbidityOptions.previousHeartAttack',
  ),
  stroke('stroke', 'profile.comorbidityOptions.stroke');

  const ComorbidityOption(this.value, this.labelKey);

  final String value;
  final String labelKey;

  static final Set<String> _knownValues = ComorbidityOption.values
      .map((ComorbidityOption o) => o.value)
      .toSet();

  static bool isKnown(String value) => _knownValues.contains(value);
}

/// Splits a stored comorbidities list back into the curated chips that are
/// still selected and whatever free text was entered under "Other" — the
/// inverse of [mergeComorbidities]. Needed anywhere a saved profile is
/// loaded back into the wizard or the edit form.
({Set<String> selected, String otherText}) splitComorbidities(
  List<String> stored,
) {
  final Set<String> selected = stored
      .where(ComorbidityOption.isKnown)
      .toSet();
  final String otherText = stored
      .where((String c) => !ComorbidityOption.isKnown(c))
      .join(', ');
  return (selected: selected, otherText: otherText);
}

/// Combines the curated selection with the free-text "Other" entry into the
/// flat list the wire format expects.
List<String> mergeComorbidities(Set<String> selected, String otherText) {
  final List<String> result = <String>[...selected];
  final String trimmed = otherText.trim();
  if (trimmed.isNotEmpty) result.add(trimmed);
  return result;
}

/// Renders a stored comorbidities list for display: curated values are
/// translated, anything else (the free-text entries) is shown verbatim.
String describeComorbidities(List<String> stored) {
  if (stored.isEmpty) return 'profile.values.noneRecorded'.tr();
  return stored
      .map((String value) {
        for (final ComorbidityOption option in ComorbidityOption.values) {
          if (option.value == value) return option.labelKey.tr();
        }
        return value;
      })
      .join(', ');
}

/// The curated comorbidity chips, shared by the onboarding wizard and the
/// profile edit form so the two never drift apart (spec §3).
class ComorbidityChips extends StatelessWidget {
  const ComorbidityChips({
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ComorbidityOption.values.map((ComorbidityOption option) {
        return SelectableChip(
          label: option.labelKey.tr(),
          selected: selected.contains(option.value),
          onTap: () => onToggle(option.value),
        );
      }).toList(),
    );
  }
}
