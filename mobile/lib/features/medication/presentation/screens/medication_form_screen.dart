import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/caregiver_notify_store.dart';
import '../../domain/entities/medication.dart';
import '../../domain/medication_library.dart';
import '../../medication_providers.dart';
import '../controllers/medication_form_controller.dart';
import '../controllers/medication_list_controller.dart';
import '../widgets/time_list_field.dart';
import 'review_medication_screen.dart';

// `FutureProvider.autoDispose.family<StateT, ArgT>(...)` returns
// `FutureProviderFamily<StateT, ArgT>` in riverpod 3.4.2, but that type is
// an internal implementation detail not exported from the public barrel
// (neither is `AutoDisposeFutureProviderFamily`, which doesn't exist at
// all in this package version) — so the variable is left untyped and
// inferred rather than explicitly annotated.
final _medicationByIdProvider =
    FutureProvider.autoDispose.family<Medication?, String>((Ref ref, String id) async {
  final List<Medication> medications =
      await ref.watch(medicationRepositoryProvider).allMedications(includeInactive: true);
  for (final Medication m in medications) {
    if (m.clientRecordId == id) return m;
  }
  return null;
});

class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({this.editingId, this.prefillEntry, super.key});

  final String? editingId;

  /// A library entry picked on `MedicationSearchScreen` (M3 Figma rework) —
  /// pre-fills name and dose in add mode. Ignored when [editingId] is set;
  /// editing an existing medication always loads that medication's own
  /// values instead.
  final MedicationLibraryEntry? prefillEntry;

  @override
  ConsumerState<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  bool _loaded = false;

  /// Caregiver-notify state (M3 Figma rework, Decision B). Local `State`
  /// rather than part of `MedicationFormState`: `CaregiverNotifyStore` is
  /// storage `MedicationFormController` doesn't own (see its own doc
  /// comment), so this screen reads/writes it directly instead of routing it
  /// through the controller.
  bool _caregiverEnabled = false;

  /// A real `TextEditingController` (unlike the name/dose fields below it,
  /// which this task leaves exactly as it found them) because this field is
  /// new in this task: a phone number loaded from storage that never renders
  /// once typed would be a fresh bug, not a preserved quirk.
  final TextEditingController _caregiverPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loaded = widget.editingId == null;

    // Pins the auto-disposed form controller to this screen's lifetime.
    //
    // Without it there is a window with no listener at all: in edit mode the
    // only touch before `_FormBody` mounts is a `ref.read(...).loadForEdit()`
    // from a post-frame callback, and a `read` schedules disposal as soon as
    // it returns — so the just-loaded medication could be thrown away before
    // the form body ever watched it. Holding a subscription for as long as
    // the screen is mounted closes that window, while still letting the
    // controller dispose (and so reset) the moment the screen is popped,
    // which is the whole point of making it auto-dispose.
    ref.listenManual<MedicationFormState>(
      medicationFormControllerProvider,
      (MedicationFormState? _, MedicationFormState _) {},
    );

    final MedicationLibraryEntry? entry = widget.prefillEntry;
    if (widget.editingId == null && entry != null) {
      // Deferred to a post-frame callback rather than called straight from
      // `initState`: Riverpod forbids modifying a provider's state during the
      // widget tree's build phase (`initState` counts), asserting exactly
      // that if this runs synchronously here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final MedicationFormController controller =
            ref.read(medicationFormControllerProvider.notifier);
        controller.setName(entry.name);
        controller.setDoseMg(_formatDose(entry.doseMg));
      });
    }
  }

  @override
  void dispose() {
    _caregiverPhoneController.dispose();
    super.dispose();
  }

  /// Writes the caregiver toggle + phone to storage. A no-op in add mode:
  /// there is no `clientRecordId` to key it by until the medication is
  /// actually saved (which happens later, from `ReviewMedicationScreen`, and
  /// generates that id inside `MedicationRepository.add` with no way back to
  /// here) — a known, narrow limitation of this local-only feature, not a
  /// bug in the edit-mode path this actually supports.
  void _persistCaregiverSettings() {
    final String? id = widget.editingId;
    if (id == null) return;
    unawaited(
      ref.read(caregiverNotifyStoreProvider).set(
        id,
        CaregiverNotifySettings(
          enabled: _caregiverEnabled,
          phone: _caregiverPhoneController.text,
        ),
      ),
    );
  }

  void _setCaregiverEnabled(bool value) {
    setState(() => _caregiverEnabled = value);
    _persistCaregiverSettings();
  }

  void _onCaregiverPhoneChanged(String _) => _persistCaregiverSettings();

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final AsyncValue<Medication?> medication =
          ref.watch(_medicationByIdProvider(widget.editingId!));
      return medication.when(
        loading: () => const AppScaffold(body: Center(child: CircularProgressIndicator())),
        error: (Object e, StackTrace _) =>
            AppScaffold(body: ErrorView(failure: UnknownFailure(e.toString()))),
        data: (Medication? found) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (found != null) {
              ref.read(medicationFormControllerProvider.notifier).loadForEdit(found);
            }
            // Loaded alongside the medication itself, same as `loadForEdit`
            // above — the caregiver settings and the medication both belong
            // to `widget.editingId` and both need to be in place before
            // `_FormBody` first mounts.
            final CaregiverNotifySettings settings =
                await ref.read(caregiverNotifyStoreProvider).get(widget.editingId!);
            if (mounted) {
              setState(() {
                _caregiverEnabled = settings.enabled;
                _caregiverPhoneController.text = settings.phone;
                _loaded = true;
              });
            }
          });
          return const AppScaffold(body: Center(child: CircularProgressIndicator()));
        },
      );
    }
    return _FormBody(
      editingId: widget.editingId,
      caregiverEnabled: _caregiverEnabled,
      caregiverPhoneController: _caregiverPhoneController,
      onCaregiverEnabledChanged: _setCaregiverEnabled,
      onCaregiverPhoneChanged: _onCaregiverPhoneChanged,
    );
  }
}

/// Matches `_SuggestionCard`'s own dose formatting on `MedicationSearchScreen`
/// — a whole-number dose (e.g. `50.0`) prefills as `50`, not `50.0`.
String _formatDose(double doseMg) =>
    doseMg == doseMg.roundToDouble() ? doseMg.toStringAsFixed(0) : doseMg.toString();

class _FormBody extends ConsumerWidget {
  const _FormBody({
    required this.editingId,
    required this.caregiverEnabled,
    required this.caregiverPhoneController,
    required this.onCaregiverEnabledChanged,
    required this.onCaregiverPhoneChanged,
  });

  /// Null in add mode. Drives the deactivate action, which only makes sense
  /// for a medication that already exists (spec §3).
  final String? editingId;

  final bool caregiverEnabled;
  final TextEditingController caregiverPhoneController;
  final ValueChanged<bool> onCaregiverEnabledChanged;
  final ValueChanged<String> onCaregiverPhoneChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MedicationFormState state = ref.watch(medicationFormControllerProvider);
    final MedicationFormController controller =
        ref.read(medicationFormControllerProvider.notifier);

    // Caregiver settings are keyed by `clientRecordId` in
    // `CaregiverNotifyStore`, and add mode has no id yet (see
    // `_persistCaregiverSettings`'s doc comment) — so in add mode the toggle
    // and phone field are shown disabled with an explanatory note instead of
    // silently accepting input that would then be discarded on Save.
    final bool caregiverSettingsAvailable = editingId != null;

    // No `ref.listen(...saved...)` here (unlike before the M3 Figma rework):
    // this screen's Save button no longer calls `controller.save()` directly
    // — it pushes `ReviewMedicationScreen`, which owns the actual save() call
    // and its own pop-on-saved listener. Keeping a second listener here would
    // fire it too, on the very same `saved` transition, popping this screen
    // out from underneath Review's own (correct) pop.

    return AppScaffold(
      title: 'meds.form.title'.tr(),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            label: 'meds.form.name'.tr(),
            hint: 'meds.form.nameHint'.tr(),
            errorText: state.nameError?.tr(),
            onChanged: controller.setName,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'meds.form.doseMg'.tr(),
            keyboardType: TextInputType.number,
            errorText: state.doseError?.tr(),
            onChanged: controller.setDoseMg,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final MedicationFrequency f in MedicationFrequency.values)
                _FrequencyChip(
                  frequency: f,
                  selected: state.frequency == f,
                  onSelected: () => controller.setFrequency(f),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TimeListField(times: state.scheduleTimes, onChanged: controller.setScheduleTimes),
          if (state.scheduleError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(state.scheduleError!.tr(), style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('meds.form.notifyCaregiver'.tr()),
            value: caregiverEnabled,
            onChanged: caregiverSettingsAvailable ? onCaregiverEnabledChanged : null,
          ),
          if (!caregiverSettingsAvailable) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'meds.form.caregiverUnavailableNote'.tr(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
          if (caregiverEnabled || !caregiverSettingsAvailable) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'meds.form.caregiverPhone'.tr(),
              controller: caregiverPhoneController,
              keyboardType: TextInputType.phone,
              enabled: caregiverSettingsAvailable,
              onChanged: caregiverSettingsAvailable ? onCaregiverPhoneChanged : null,
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'common.save'.tr(),
            isLoading: state.isSaving,
            onPressed: () => _reviewIfValid(context, controller),
          ),
          if (editingId != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'meds.deactivate'.tr(),
              variant: AppButtonVariant.danger,
              onPressed: () => _confirmDeactivate(context, ref, editingId!),
            ),
          ],
        ],
      ),
    );
  }

  /// Re-validates (via `controller.validate()`, the same check `save()`
  /// itself runs — see that method's doc comment) and, only if everything
  /// passes, pushes `ReviewMedicationScreen` rather than saving immediately.
  /// The actual persistence — and its I7 error handling — now lives on that
  /// screen, reached from here purely as a navigation decision.
  void _reviewIfValid(BuildContext context, MedicationFormController controller) {
    if (!controller.validate()) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ReviewMedicationScreen()),
    );
  }

  /// Deactivating is a soft stop, never a delete (Decision 1) — the confirm
  /// sheet says so in as many words, because "delete" is what the button
  /// looks like it does.
  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    String clientRecordId,
  ) async {
    final bool confirmed = await ConfirmSheet.show(
      context,
      title: 'meds.deactivateTitle'.tr(),
      message: 'meds.deactivateBody'.tr(),
      confirmLabel: 'meds.deactivateConfirm'.tr(),
      isDestructive: true,
    );
    if (!confirmed) return;

    // `MedicationListController.deactivate` also cancels this medication's
    // pending reminders, which is why the call goes through the controller
    // rather than straight to the repository.
    await ref
        .read(medicationListControllerProvider.notifier)
        .deactivate(clientRecordId);
    if (context.mounted) context.pop();
  }
}

/// One frequency `ChoiceChip`, restyled to match Figma frame `368:2706`
/// (M3 Figma-fidelity restyle, visual-only — see [TimeListField] for the
/// matching time-chip restyle).
///
/// Selected fill (`AppColors.ink`) + white label reuses the same
/// selected/unselected convention already used for the pill segmented
/// control on `MedicationsScreen`'s tab bar (`_MedicationsTabBar`), rather
/// than inventing a new selected-state colour. Only colour/spacing/shape
/// change here — the `Wrap` this is built inside (and so its overflow
/// safety) is untouched.
class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({
    required this.frequency,
    required this.selected,
    required this.onSelected,
  });

  final MedicationFrequency frequency;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('meds.frequency.${frequency.name}'.tr()),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.surfaceAlt,
      side: BorderSide(color: selected ? AppColors.ink : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.lg)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: selected ? AppColors.surface : AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
