import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';

class GoalField extends StatelessWidget {
  const GoalField({
    required this.controller,
    required this.label,
    this.errorText,
    this.suffixText,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? suffixText;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AppTextField(
        controller: controller,
        label: label,
        errorText: errorText,
        keyboardType: keyboardType,
        suffix: suffixText == null ? null : Text(suffixText!),
      ),
    );
  }
}
