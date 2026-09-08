import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared by the Profile and Settings screens (M2 spec §3 lists sign out on
/// both) so the confirmation dialog and the actual sign-out behaviour can
/// never drift apart between the two entry points.
///
/// TODO(M2/M1): call the real sign-out once M1's AuthGate/session management
/// lands — there is no session to clear yet, so this only navigates home.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('profile.settings.signOutTitle'.tr()),
      content: Text('profile.settings.signOutBody'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('home.signOut'.tr()),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    // ignore: use_build_context_synchronously
    if (context.mounted) context.go('/');
  }
}