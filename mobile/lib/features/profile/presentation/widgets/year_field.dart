import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';

class YearField extends StatelessWidget {
  const YearField({
    required this.controller,
    required this.label,
    this.errorText,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AppTextField(
        controller: controller,
        label: label,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        errorText: errorText,
        onChanged: onChanged,
      ),
    );
  }
}
