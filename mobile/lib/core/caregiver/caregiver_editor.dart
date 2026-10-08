import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import 'caregiver_contact.dart';

/// Add, change or remove the caregiver called in an emergency. Returns the
/// saved contact, or null when there is none afterwards.
Future<CaregiverContact?> showCaregiverEditor(
  BuildContext context,
  CaregiverContactStore store,
) => showContactEditor(
  context,
  store,
  textPrefix: 'profile.caregiver',
  keyPrefix: 'caregiver',
);

/// Add, change or remove a saved contact. Texts come from `<textPrefix>.*`
/// (title, hint, name, phone, save, remove); fields are keyed
/// `<keyPrefix>_name` and `<keyPrefix>_phone`.
Future<SavedContact?> showContactEditor(
  BuildContext context,
  ContactStore store, {
  required String textPrefix,
  required String keyPrefix,
}) async {
  final SavedContact? current = await store.read();
  if (!context.mounted) return current;
  final SavedContact? result = await showModalBottomSheet<SavedContact?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheet) => _ContactSheet(
      store: store,
      current: current,
      textPrefix: textPrefix,
      keyPrefix: keyPrefix,
    ),
  );
  return result ?? await store.read();
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({
    required this.store,
    required this.current,
    required this.textPrefix,
    required this.keyPrefix,
  });

  final ContactStore store;
  final SavedContact? current;
  final String textPrefix;
  final String keyPrefix;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.current?.name,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.current?.phone,
  );
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? error = validateCaregiverPhone(_phone.text);
    if (error != null) {
      setState(() => _phoneError = error);
      return;
    }
    final SavedContact contact = SavedContact(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
    );
    await widget.store.save(contact);
    if (mounted) Navigator.of(context).pop(contact);
  }

  Future<void> _remove() async {
    await widget.store.clear();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('${widget.textPrefix}.title'.tr(), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('${widget.textPrefix}.hint'.tr(), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            key: Key('${widget.keyPrefix}_name'),
            label: '${widget.textPrefix}.name'.tr(),
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: Key('${widget.keyPrefix}_phone'),
            label: '${widget.textPrefix}.phone'.tr(),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            errorText: _phoneError?.tr(),
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: '${widget.textPrefix}.save'.tr(), onPressed: _save),
          if (widget.current != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: '${widget.textPrefix}.remove'.tr(),
              variant: AppButtonVariant.text,
              onPressed: _remove,
            ),
          ],
        ],
      ),
    );
  }
}
