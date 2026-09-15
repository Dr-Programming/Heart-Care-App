import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  final String? errorText;

  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final int maxLines;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          enabled: enabled,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          textInputAction: textInputAction,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            errorMaxLines: 4,

            counterText: '',
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: AppColors.textTertiary),
            suffixIcon: suffix,
          ),
        ),
        if (helper != null && errorText == null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(helper!, style: text.bodySmall),
        ],
      ],
    );
  }
}
