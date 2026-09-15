import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/vital_descriptors.dart';

class VitalFormFields extends StatelessWidget {
  const VitalFormFields({
    required this.descriptor,
    required this.controllers,
    required this.errors,
    super.key,
  });

  final VitalDescriptor descriptor;
  final Map<String, TextEditingController> controllers;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final VitalFieldSpec field in descriptor.fields) ...<Widget>[
          AppTextField(
            label: '${field.labelKey.tr()} (${field.unit})',
            controller: controllers[field.key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            errorText: errors[field.key]?.tr(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
