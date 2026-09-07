import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/widgets/widgets.dart';

/// A 4-digit obscured PIN field, used for both the PIN and confirm-PIN.
class PinInput extends StatelessWidget {
  const PinInput({
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      hint: hint,
      controller: controller,
      errorText: errorText,
      enabled: enabled,
      obscureText: true,
      maxLength: 4,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      prefixIcon: Iconsax.lock,
    );
  }
}
