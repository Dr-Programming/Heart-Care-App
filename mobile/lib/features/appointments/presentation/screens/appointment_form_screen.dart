import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/clinic/clinic_contact.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../appointment_providers.dart';
import '../../domain/appointment.dart';
import '../appointment_text.dart';

/// Add an appointment, or change or delete the one with [appointmentId].
class AppointmentFormScreen extends ConsumerStatefulWidget {
  const AppointmentFormScreen({this.appointmentId, super.key});

  final String? appointmentId;

  static String idFromRoute(GoRouterState state) => state.pathParameters['id']!;

  @override
  ConsumerState<AppointmentFormScreen> createState() =>
      _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  final TextEditingController _place = TextEditingController();
  final TextEditingController _note = TextEditingController();
  DateTime? _at;
  Set<ReminderTiming> _reminders = ReminderTiming.values.toSet();
  Appointment? _existing;
  bool _loaded = false;
  bool _saving = false;
  String? _whenError;

  bool get _isEdit => widget.appointmentId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final List<Appointment> all = await ref
          .read(appointmentStoreProvider)
          .all();
      for (final Appointment a in all) {
        if (a.id == widget.appointmentId) _existing = a;
      }
      final Appointment? a = _existing;
      if (a != null) {
        _place.text = a.place;
        _note.text = a.note;
        _at = a.at;
        _reminders = a.reminders.toSet();
      }
    } else {
      // Most visits are at the patient's own clinic.
      final ClinicContact? clinic = await ref
          .read(clinicContactStoreProvider)
          .read();
      if (clinic != null && clinic.name.isNotEmpty) _place.text = clinic.name;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        _at ?? DateTime(now.year, now.month, now.day + 1, 9);
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: _isEdit && initial.isBefore(now)
          ? initial
          : DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _whenError = null;
    });
  }

  Future<void> _save() async {
    final DateTime? at = _at;
    String? error;
    if (at == null) {
      error = 'appointments.form.whenRequired';
    } else if (!at.isAfter(DateTime.now()) && at != _existing?.at) {
      error = 'appointments.form.whenPast';
    }
    if (error != null) {
      setState(() => _whenError = error);
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(appointmentActionsProvider)
        .save(
          Appointment(
            id: _existing?.id ?? const Uuid().v4(),
            at: at!,
            place: _place.text.trim(),
            note: _note.text.trim(),
            reminders: _reminders,
          ),
        );
    if (!mounted) return;
    showAppToast(
      context,
      'appointments.form.saved'.tr(),
      icon: Icons.check_circle_outline,
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final bool confirmed = await ConfirmSheet.show(
      context,
      title: 'appointments.form.deleteTitle'.tr(),
      message: 'appointments.form.deleteMessage'.tr(),
      confirmLabel: 'appointments.form.delete'.tr(),
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(appointmentActionsProvider).delete(widget.appointmentId!);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime? at = _at;
    return AppScaffold(
      title:
          (_isEdit
                  ? 'appointments.form.editTitle'
                  : 'appointments.form.addTitle')
              .tr(),
      scrollable: true,
      body: !_loaded
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text('appointments.form.when'.tr(), style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  key: const Key('appointmentWhen'),
                  label: at == null
                      ? 'appointments.form.pickWhen'.tr()
                      : appointmentWhen(context, Appointment(id: '', at: at)),
                  icon: Icons.event_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _pickWhen,
                ),
                if (_whenError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _whenError!.tr(),
                    key: const Key('appointmentWhenError'),
                    style: text.bodySmall?.copyWith(color: AppColors.critical),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  key: const Key('appointmentPlace'),
                  label: 'appointments.form.place'.tr(),
                  controller: _place,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  key: const Key('appointmentNote'),
                  label: 'appointments.form.note'.tr(),
                  hint: 'appointments.form.noteHint'.tr(),
                  controller: _note,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'appointments.form.remindMe'.tr(),
                  style: text.titleMedium,
                ),
                for (final ReminderTiming t in ReminderTiming.values)
                  CheckboxListTile(
                    key: Key('appointmentReminder_${t.code}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _reminders.contains(t),
                    title: Text('appointments.reminder.${t.code}'.tr()),
                    onChanged: (bool? on) => setState(() {
                      _reminders = <ReminderTiming>{
                        ..._reminders.where((ReminderTiming r) => r != t),
                        if (on ?? false) t,
                      };
                    }),
                  ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  key: const Key('appointmentSave'),
                  label: 'appointments.form.save'.tr(),
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
                if (_isEdit) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    key: const Key('appointmentDelete'),
                    label: 'appointments.form.delete'.tr(),
                    variant: AppButtonVariant.danger,
                    onPressed: _saving ? null : _delete,
                  ),
                ],
              ],
            ),
    );
  }
}
