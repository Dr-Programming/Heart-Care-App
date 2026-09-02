import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/language.dart';
import '../../../core/providers/core_providers.dart';
import 'providers/profile_providers.dart';

/// Switches the app's displayed language, immediately (M2 design, Decision
/// 5). `LanguageStore` is the authoritative, device-local record — this is
/// the one place that writes to it and the one place that calls
/// `setLocale`, so every language toggle in this slice renders the same way
/// and cannot drift from the app's actual locale.
Future<void> switchDeviceLanguage(
  BuildContext context,
  WidgetRef ref,
  AppLanguage language,
) async {
  await ref.read(languageStoreProvider).write(language);
  if (context.mounted) {
    await context.setLocale(language.locale);
  }
}

/// [switchDeviceLanguage], plus mirroring the choice onto the patient's
/// profile so the server's copy is not stale.
///
/// Only for screens where a profile already exists to mirror onto — Settings
/// and the profile edit form. The onboarding wizard writes the profile
/// exactly once, on finish or skip (Decision 4); calling this from step 1
/// would push a partial profile to the server before the wizard is done, so
/// the wizard uses [switchDeviceLanguage] alone and carries the choice
/// through `OnboardingState` instead.
Future<void> changeAppLanguage(
  BuildContext context,
  WidgetRef ref,
  AppLanguage language,
) async {
  await switchDeviceLanguage(context, ref, language);
  unawaited(ref.read(setLanguageProvider)(language.code));
  ref.invalidate(patientProfileProvider);
}
