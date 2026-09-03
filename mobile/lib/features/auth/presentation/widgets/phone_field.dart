import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

/// Phone entry pinned to the Ethiopian format the API accepts.
///
/// The field is seeded with `+251` and limited to 13 characters so the user
/// types only the 9 national digits and cannot produce a wrong country code.
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.fieldKey,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  /// Applied to the `TextFormField` itself so `enterText` has an `EditableText`
  /// to write into.
  final Key fieldKey;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.phone,
          autofillHints: const <String>[AutofillHints.telephoneNumber],
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
            LengthLimitingTextInputFormatter(13),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Iconsax.call),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
