import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../caregiver/caregiver_editor.dart';
import '../db/app_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'clinic_contact.dart';
import 'urgent_pattern.dart';

Future<void> _dialPhone(String number) =>
    launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', '')));

/// Add, change or remove the patient's clinic.
Future<ClinicContact?> showClinicEditor(
  BuildContext context,
  ClinicContactStore store,
) => showContactEditor(
  context,
  store,
  textPrefix: 'profile.clinic',
  keyPrefix: 'clinic',
);

/// Asks whether to call the clinic now; "Call" opens the phone's dialler. With
/// no clinic saved yet it offers to add one first. [dial] is replaceable for
/// tests.
Future<void> showClinicCallOptions(
  BuildContext context,
  ClinicContactStore store, {
  Future<void> Function(String number) dial = _dialPhone,
}) async {
  final ClinicContact? clinic = await store.read();
  if (!context.mounted) return;
  bool addRequested = false;
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialog) {
      final TextTheme text = Theme.of(dialog).textTheme;
      return AlertDialog(
        icon: const Icon(
          Icons.local_hospital_outlined,
          color: AppColors.accent,
          size: 40,
        ),
        title: Text('clinic.call.title'.tr(), textAlign: TextAlign.center),
        content: Text(
          clinic == null
              ? 'clinic.call.noClinic'.tr()
              : 'clinic.call.body'.tr(
                  namedArgs: <String, String>{
                    'name': clinic.displayName,
                    'phone': clinic.phone,
                  },
                ),
          style: text.bodyLarge,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actionsOverflowButtonSpacing: AppSpacing.sm,
        actions: <Widget>[
          if (clinic != null)
            FilledButton.icon(
              key: const Key('clinicCallNow'),
              icon: const Icon(Icons.call),
              label: Text('clinic.call.callNow'.tr()),
              onPressed: () {
                Navigator.of(dialog).pop();
                dial(clinic.phone);
              },
            )
          else
            FilledButton.icon(
              key: const Key('clinicAdd'),
              icon: const Icon(Icons.add),
              label: Text('clinic.add'.tr()),
              onPressed: () {
                addRequested = true;
                Navigator.of(dialog).pop();
              },
            ),
          TextButton(
            key: const Key('clinicNotNow'),
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text('clinic.call.notNow'.tr()),
          ),
        ],
      );
    },
  );
  if (!addRequested || !context.mounted) return;
  final ClinicContact? saved = await showClinicEditor(context, store);
  if (saved != null && context.mounted) {
    await showClinicCallOptions(context, store, dial: dial);
  }
}

/// After an urgent reading: when there have been [urgentPatternThreshold] or
/// more in the last week, a notification card drops in over the top of the
/// app. Tapping it offers to call the clinic. It stays, even after the form
/// closes, until the patient taps it or dismisses it.
Future<void> remindToCallClinicIfNeeded(
  BuildContext context, {
  required AppDatabase db,
  required ClinicContactStore store,
}) async {
  final UrgentPattern pattern = await readUrgentPattern(db);
  if (!pattern.shouldRemind || !context.mounted) return;
  // The notice outlives this screen, so it lives in the root overlay and
  // opens the dialog from the root navigator, which both stay mounted.
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final OverlayState? overlay = navigator.overlay;
  if (overlay == null) return;

  _activeNotice?.remove();
  late final OverlayEntry entry;
  void close() {
    if (identical(_activeNotice, entry)) _activeNotice = null;
    if (entry.mounted) entry.remove();
  }

  void openOptions() {
    close();
    if (overlay.mounted) showClinicCallOptions(overlay.context, store);
  }

  entry = OverlayEntry(
    builder: (BuildContext context) => _ClinicNotice(
      count: pattern.count,
      onCall: openOptions,
      onDismiss: () {
        close();
        dismissClinicReminder(db);
      },
    ),
  );
  _activeNotice = entry;
  overlay.insert(entry);
}

OverlayEntry? _activeNotice;

class _ClinicNotice extends StatelessWidget {
  const _ClinicNotice({
    required this.count,
    required this.onCall,
    required this.onDismiss,
  });

  final int count;
  final VoidCallback onCall;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Material(
            key: const Key('clinicReminderBanner'),
            elevation: 8,
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.lg),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onCall,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.critical, width: 5),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.local_hospital_outlined,
                          color: AppColors.critical,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'clinic.reminder.title'.tr(),
                                style: text.titleMedium?.copyWith(
                                  color: AppColors.critical,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'clinic.reminder.body'.tr(
                                  namedArgs: <String, String>{
                                    'count': '$count',
                                  },
                                ),
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: onDismiss,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: Text('clinic.reminder.dismiss'.tr()),
                        ),
                        TextButton.icon(
                          onPressed: onCall,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.critical,
                          ),
                          icon: const Icon(Icons.call, size: 18),
                          label: Text('clinic.reminder.call'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
