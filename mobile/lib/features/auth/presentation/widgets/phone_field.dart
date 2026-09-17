import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/widgets/widgets.dart';

/// The `+251` phone field shared by Login and Register.
///
/// Restricts input to digits and a leading `+` and caps the length at 13
/// characters (`+251` plus 9 digits) — the format the backend requires, kept
/// unenterable rather than merely validated after the fact.
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.label,
    required this.hint,
    required this.controller,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
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
      keyboardType: TextInputType.phone,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
        LengthLimitingTextInputFormatter(13),
      ],
      prefixIcon: Iconsax.call,
    );
  }
}
