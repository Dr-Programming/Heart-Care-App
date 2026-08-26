import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart' hide Medication;
import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';
import '../../medication_providers.dart';
import '../../notifications/reminder_bootstrap.dart';
import '../controllers/medication_list_controller.dart';

class _NotificationsEnabledController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final String? raw = await ref
        .watch(appDatabaseProvider)
        .preferencesDao
        .get(PreferenceKeys.notificationsEnabled);
    return raw != 'false';
  }

  Future<void> setEnabled(bool value) async {
    // The preference is written first on purpose: `scheduleFor` reads this
    // key itself and refuses to arm anything while it says `false`, so
    // re-enabling would silently schedule nothing if the order were flipped.
    await ref
        .read(appDatabaseProvider)
        .preferencesDao
        .set(PreferenceKeys.notificationsEnabled, value.toString());

    // Decision 4 / spec: "cancel everything when it is off — do not just
    // suppress display". Turning the switch off has to reach the OS, because
    // an alarm that is already armed keeps firing no matter what this app
    // would have chosen to render.
    final MedicationReminderBootstrap bootstrap = ref.read(
      medicationReminderBootstrapProvider,
    );
    if (value) {
      await bootstrap.rescheduleAll();
    } else {
      await bootstrap.cancelAll();
    }

    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<_NotificationsEnabledController, bool>
_notificationsEnabledProvider =
    AsyncNotifierProvider<_NotificationsEnabledController, bool>(
      _NotificationsEnabledController.new,
    );

class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MedicationListState> meds = ref.watch(medicationListControllerProvider);
    final AsyncValue<bool> enabled = ref.watch(_notificationsEnabledProvider);

    return AppScaffold(
      title: 'meds.reminders.title'.tr(),
      body: meds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
        data: (MedicationListState data) => ListView(
          children: <Widget>[
            SwitchListTile(
              title: Text('meds.reminders.enabled'.tr()),
              value: enabled.value ?? true,
              onChanged: (bool value) =>
                  ref.read(_notificationsEnabledProvider.notifier).setEnabled(value),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final Medication medication in data.medications)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SectionCard(
                  title: medication.name,
                  child: Text(
                    '${medication.scheduleTimes.join(' · ')} · ${'meds.reminders.followUp'.tr()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
