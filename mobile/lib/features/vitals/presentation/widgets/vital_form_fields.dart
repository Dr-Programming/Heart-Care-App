import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/validators.dart';
import '../../domain/vital_descriptors.dart';

/// One numeric field per required key of [descriptor.type] — two for blood
/// pressure, three for cholesterol, one for everything else (Decision 1).
///
/// Owns its own `TextEditingController`s so retyping never fights cursor
/// position; give this widget a `key` derived from the selected type so
/// Flutter remounts (and clears) it on a type switch.
class VitalFormFields extends StatefulWidget {
  const VitalFormFields({
    required this.descriptor,
    required this.fieldErrors,
    required this.onChanged,
    this.hints = const <String, String>{},
    super.key,
  });

  final VitalDescriptor descriptor;
  final Map<String, FieldError> fieldErrors;
  final void Function(String key, String value) onChanged;
  final Map<String, String> hints;

  @override
  State<VitalFormFields> createState() => _VitalFormFieldsState();
}

class _VitalFormFieldsState extends State<VitalFormFields> {
  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
        for (final String key in widget.descriptor.requiredKeys)
          key: TextEditingController(),
      };

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final String key in widget.descriptor.requiredKeys) ...<Widget>[
          AppTextField(
            label: 'vitals.field.$key'.tr(),
            hint: widget.hints[key] ?? widget.descriptor.unit,
            controller: _controllers[key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: widget.fieldErrors[key]?.key.tr(
              namedArgs: widget.fieldErrors[key]!.args,
            ),
            onChanged: (String value) => widget.onChanged(key, value),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
