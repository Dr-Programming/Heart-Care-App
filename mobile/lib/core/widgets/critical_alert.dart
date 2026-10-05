import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../caregiver/caregiver_contact.dart';
import '../caregiver/caregiver_editor.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

Future<void> _dialPhone(String number) =>
    launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', '')));

/// Shown when a reading or check-in reaches the emergency level. The wording
/// is the clinician's ("Sit down, rest, and call your emergency contact
/// now"); the button calls the patient's [caregiver], or offers to add one
/// when none is saved. [dial] is replaceable for tests.
Future<void> showCriticalAlert(
  BuildContext context, {
  required CaregiverContact? caregiver,
  required VoidCallback onAddCaregiver,
  Future<void> Function(String number) dial = _dialPhone,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialog) {
      final TextTheme text = Theme.of(dialog).textTheme;
      final CaregiverContact? contact = caregiver;
      return AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.critical,
          size: 40,
        ),
        title: Text(
          'clinical.critical.title'.tr(),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'clinical.critical.body'.tr(),
              style: text.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (contact == null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                'clinical.critical.noCaregiver'.tr(),
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actionsOverflowButtonSpacing: AppSpacing.sm,
        actions: <Widget>[
          if (contact != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.critical,
              ),
              icon: const Icon(Icons.call),
              label: Text(
                'clinical.critical.callCaregiver'.tr(
                  namedArgs: <String, String>{
                    'name': contact.name.isEmpty ? contact.phone : contact.name,
                  },
                ),
              ),
              onPressed: () => dial(contact.phone),
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('clinical.critical.addCaregiver'.tr()),
              onPressed: () {
                Navigator.of(dialog).pop();
                onAddCaregiver();
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text('clinical.critical.understood'.tr()),
          ),
        ],
      );
    },
  );
}

/// Reads the saved caregiver and shows [showCriticalAlert]; "Add caregiver"
/// opens the editor so the patient can save one and call straight away.
Future<void> showCriticalAlertFor(
  BuildContext context,
  CaregiverContactStore store,
) async {
  final CaregiverContact? caregiver = await store.read();
  if (!context.mounted) return;
  bool addRequested = false;
  await showCriticalAlert(
    context,
    caregiver: caregiver,
    onAddCaregiver: () => addRequested = true,
  );
  // Awaited here, so the screen behind stays open until this is done.
  if (!addRequested || !context.mounted) return;
  final CaregiverContact? saved = await showCaregiverEditor(context, store);
  if (saved != null && context.mounted) {
    await showCriticalAlert(context, caregiver: saved, onAddCaregiver: () {});
  }
}
