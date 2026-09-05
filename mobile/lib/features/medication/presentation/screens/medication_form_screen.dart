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
import '../../data/medication_instructions_store.dart';
import '../../domain/entities/medication.dart';
import '../../domain/medication_library.dart';
import '../../medication_providers.dart';
import '../controllers/medication_form_controller.dart';
import '../controllers/medication_list_controller.dart';
import '../widgets/time_list_field.dart';
import 'review_medication_screen.dart';

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

  final MedicationLibraryEntry? prefillEntry;

  @override
  ConsumerState<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  bool _loaded = false;

  bool _caregiverEnabled = false;

  final TextEditingController _caregiverPhoneController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();

  MedicationInstructions? _instructions;

  @override
  void initState() {
    super.initState();
    _loaded = widget.editingId == null;

    ref.listenManual<MedicationFormState>(
      medicationFormControllerProvider,
      (MedicationFormState? _, MedicationFormState _) {},
    );

    final MedicationLibraryEntry? entry = widget.prefillEntry;
    if (widget.editingId == null && entry != null) {

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final MedicationFormController controller =
            ref.read(medicationFormControllerProvider.notifier);
        controller.setName(entry.name);
        _nameController.text = entry.name;
        final String dose = _formatDose(entry.doseMg);
        controller.setDoseMg(dose);
        _doseController.text = dose;
      });
    }
  }

  @override
  void dispose() {
    _caregiverPhoneController.dispose();
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

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

  void _persistInstructions() {
    final String? id = widget.editingId;
    if (id == null) return;
    unawaited(
      ref
          .read(medicationInstructionsStoreProvider)
          .set(id, _instructions ?? MedicationInstructions.none),
    );
  }

  void _setInstructions(MedicationInstructions value) {
    setState(() => _instructions = _instructions == value ? MedicationInstructions.none : value);
    _persistInstructions();
  }

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
              _nameController.text = found.name;
              _doseController.text = _formatDose(found.doseMg);
            }

            final CaregiverNotifySettings settings =
                await ref.read(caregiverNotifyStoreProvider).get(widget.editingId!);

            final MedicationInstructions instructions =
                await ref.read(medicationInstructionsStoreProvider).get(widget.editingId!);
            if (mounted) {
              setState(() {
                _caregiverEnabled = settings.enabled;
                _caregiverPhoneController.text = settings.phone;
                _instructions = instructions;
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
      nameController: _nameController,
      doseController: _doseController,
      caregiverEnabled: _caregiverEnabled,
      caregiverPhoneController: _caregiverPhoneController,
      onCaregiverEnabledChanged: _setCaregiverEnabled,
      onCaregiverPhoneChanged: _onCaregiverPhoneChanged,
      instructions: _instructions ?? MedicationInstructions.none,
      onInstructionsChanged: _setInstructions,
    );
  }
}

String _formatDose(double doseMg) =>
    doseMg == doseMg.roundToDouble() ? doseMg.toStringAsFixed(0) : doseMg.toString();

class _FormBody extends ConsumerWidget {
  const _FormBody({
    required this.editingId,
    required this.nameController,
    required this.doseController,
    required this.caregiverEnabled,
    required this.caregiverPhoneController,
    required this.onCaregiverEnabledChanged,
    required this.onCaregiverPhoneChanged,
    required this.instructions,
    required this.onInstructionsChanged,
  });

  final String? editingId;

  final TextEditingController nameController;
  final TextEditingController doseController;

  final bool caregiverEnabled;
  final TextEditingController caregiverPhoneController;
  final ValueChanged<bool> onCaregiverEnabledChanged;
  final ValueChanged<String> onCaregiverPhoneChanged;

  final MedicationInstructions instructions;
  final ValueChanged<MedicationInstructions> onInstructionsChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MedicationFormState state = ref.watch(medicationFormControllerProvider);
    final MedicationFormController controller =
        ref.read(medicationFormControllerProvider.notifier);

    final bool isAsNeeded =
        state.frequency == MedicationFrequency.custom && state.scheduleTimes.isEmpty;

    return AppScaffold.banded(

      showBack: false,

      bandHeight: 130,
      scrollable: true,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.xs),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'meds.form.title'.tr(),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'meds.form.subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: nameController,
            label: 'meds.form.name'.tr(),
            hint: 'meds.form.nameHint'.tr(),
            errorText: state.nameError?.tr(),
            onChanged: controller.setName,
          ),

          if (editingId == null && state.doseMg.trim().isEmpty)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: nameController,
              builder: (BuildContext context, TextEditingValue value, Widget? _) {
                final String query = value.text.trim();

                if (query.length < 2) return const SizedBox.shrink();
                final List<MedicationLibraryEntry> suggestions = searchMedicationLibrary(
                  query,
                ).take(4).toList();
                if (suggestions.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final MedicationLibraryEntry entry in suggestions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _NameSuggestionTile(
                            entry: entry,
                            onTap: () {
                              controller.setName(entry.name);
                              nameController.text = entry.name;
                              final String dose = _formatDose(entry.doseMg);
                              controller.setDoseMg(dose);
                              doseController.text = dose;
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'meds.form.dosageLabel'.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DoseQuickPicks(
            medicationName: state.name,
            onSelected: (String dose) {
              controller.setDoseMg(dose);
              doseController.text = dose;
            },
          ),
          AppTextField(
            controller: doseController,
            label: 'meds.form.doseMg'.tr(),
            keyboardType: TextInputType.number,
            errorText: state.doseError?.tr(),
            onChanged: controller.setDoseMg,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'meds.form.frequencyLabel'.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final MedicationFrequency f in MedicationFrequency.values)
                _FrequencyChip(
                  frequency: f,

                  selected: f == MedicationFrequency.custom
                      ? (state.frequency == MedicationFrequency.custom &&
                            state.scheduleTimes.isNotEmpty)
                      : state.frequency == f,
                  onSelected: () => controller.setFrequency(f),
                ),
              _AsNeededChip(
                selected: isAsNeeded,
                onSelected: () {
                  controller.setFrequency(MedicationFrequency.custom);

                  controller.setScheduleTimes(const <String>[]);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isAsNeeded) ...<Widget>[
            Text(
              'meds.form.asNeededCaption'.tr(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ] else ...<Widget>[
            TimeListField(times: state.scheduleTimes, onChanged: controller.setScheduleTimes),
            if (state.scheduleError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(state.scheduleError!.tr(), style: Theme.of(context).textTheme.bodySmall),
            ],
          ],

          const SizedBox(height: AppSpacing.lg),
          Text(
            'meds.form.instructions.sectionLabel'.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final MedicationInstructions option in const <MedicationInstructions>[
                MedicationInstructions.afterMeal,
                MedicationInstructions.withFood,
                MedicationInstructions.beforeMeal,
              ])
                _InstructionsChip(
                  option: option,
                  selected: instructions == option,
                  onSelected: () => onInstructionsChanged(option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('meds.form.notifyCaregiver'.tr()),
            value: caregiverEnabled,
            onChanged: onCaregiverEnabledChanged,
          ),
          if (caregiverEnabled) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'meds.form.caregiverPhone'.tr(),
              controller: caregiverPhoneController,
              keyboardType: TextInputType.phone,
              onChanged: onCaregiverPhoneChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          _ReviewButton(
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

  void _reviewIfValid(BuildContext context, MedicationFormController controller) {
    if (!controller.validate()) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReviewMedicationScreen(
          notifyCaregiverEnabled: caregiverEnabled,
          caregiverPhone: caregiverPhoneController.text,
          instructions: instructions,
        ),
      ),
    );
  }

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

    await ref
        .read(medicationListControllerProvider.notifier)
        .deactivate(clientRecordId);
    if (context.mounted) context.pop();
  }
}

class _DoseQuickPicks extends StatelessWidget {
  const _DoseQuickPicks({required this.medicationName, required this.onSelected});

  final String medicationName;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<MedicationLibraryEntry> matches = searchMedicationLibrary(medicationName);
    if (matches.isEmpty) return const SizedBox.shrink();

    final List<double> doses = <double>{
      for (final MedicationLibraryEntry entry in matches) entry.doseMg,
    }.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final double dose in doses)
            ActionChip(
              label: Text('${_formatDose(dose)} mg'),
              onPressed: () => onSelected(_formatDose(dose)),
              backgroundColor: AppColors.surfaceAlt,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.lg),
              ),
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _NameSuggestionTile extends StatelessWidget {
  const _NameSuggestionTile({required this.entry, required this.onTap});

  final MedicationLibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String dose = _formatDose(entry.doseMg);
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${entry.name} $dose mg',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.ink, fontWeight: FontWeight.bold),
                ),
                Text(
                  entry.drugClass,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.north_west, size: 16, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('meds.form.reviewButton'.tr()),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}

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

class _AsNeededChip extends StatelessWidget {
  const _AsNeededChip({required this.selected, required this.onSelected});

  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('meds.frequency.asNeeded'.tr()),
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

class _InstructionsChip extends StatelessWidget {
  const _InstructionsChip({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final MedicationInstructions option;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('meds.form.instructions.${option.name}'.tr()),
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
