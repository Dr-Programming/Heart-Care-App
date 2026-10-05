import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'confirm_sheet.dart';

/// Asks before leaving a form the patient has started filling in, so Back
/// (the button or the system gesture) doesn't silently throw it away.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    required this.dirty,
    required this.child,
    super.key,
  });

  /// True once anything was entered and not yet saved.
  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        final bool leave = await ConfirmSheet.show(
          context,
          title: 'common.discard.title'.tr(),
          message: 'common.discard.message'.tr(),
          confirmLabel: 'common.discard.confirm'.tr(),
          cancelLabel: 'common.discard.keepEditing'.tr(),
          isDestructive: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
