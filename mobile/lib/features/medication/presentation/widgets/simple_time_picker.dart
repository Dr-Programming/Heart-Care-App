import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// A time-entry sheet built specifically to fix what Flutter's own
/// `showTimePicker(initialEntryMode: TimePickerEntryMode.inputOnly)` cannot:
/// tapping a field that already has digits in it (any digits — even the
/// neutral "12"/"00" this picker starts from) places a cursor among them
/// rather than selecting them, so typing the intended time means deleting
/// first. Real, repeated feedback for an app whose users include sick and
/// elderly patients — for them, "select-all on tap, then just type" is not
/// a nicety, it is the difference between a field that works and one that
/// doesn't. `showTimePicker` has no parameter for this; achieving it needs
/// a custom field, so this is one, not a tweak to the built-in dialog.
///
/// A bottom sheet, not a dialog, for the same reason `ConfirmSheet` is one:
/// controls land near the thumb on a large phone held one-handed, and it
/// matches this app's one existing modal-input convention rather than
/// introducing a second, different pattern.
abstract final class SimpleTimePicker {
  static Future<TimeOfDay?> show(
    BuildContext context, {
    TimeOfDay initialTime = const TimeOfDay(hour: 0, minute: 0),
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      builder: (BuildContext sheetContext) => _SimpleTimePickerSheet(initialTime: initialTime),
    );
  }
}

class _SimpleTimePickerSheet extends StatefulWidget {
  const _SimpleTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_SimpleTimePickerSheet> createState() => _SimpleTimePickerSheetState();
}

class _SimpleTimePickerSheetState extends State<_SimpleTimePickerSheet> {
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();
  late bool _isPm;

  @override
  void initState() {
    super.initState();
    final TimeOfDayHourMinute12 initial = _to12Hour(widget.initialTime);
    _hourController = TextEditingController(text: initial.hour.toString().padLeft(2, '0'));
    _minuteController = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
    _isPm = initial.isPm;

    // The whole point of this widget: select the field's entire current
    // value the instant it gains focus, so the very first digit typed
    // replaces it rather than being inserted next to it.
    _hourFocus.addListener(() => _selectAllOnFocus(_hourFocus, _hourController));
    _minuteFocus.addListener(() => _selectAllOnFocus(_minuteFocus, _minuteController));
  }

  void _selectAllOnFocus(FocusNode node, TextEditingController controller) {
    if (!node.hasFocus) return;
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _confirm() {
    // Clamped, not rejected with an error message: a patient mistyping a
    // time should still get a sensible result, not a dead end to retry.
    final int hour12 = (int.tryParse(_hourController.text) ?? 12).clamp(1, 12);
    final int minute = (int.tryParse(_minuteController.text) ?? 0).clamp(0, 59);
    final int hour24 = switch ((hour12, _isPm)) {
      (12, false) => 0, // 12 AM -> 00
      (12, true) => 12, // 12 PM -> 12
      (_, true) => hour12 + 12,
      (_, false) => hour12,
    };
    Navigator.of(context).pop(TimeOfDay(hour: hour24, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('meds.form.pickTimeTitle'.tr(), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _NumberField(
                  label: 'meds.form.pickTimeHour'.tr(),
                  controller: _hourController,
                  focusNode: _hourFocus,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: Text(':', style: text.headlineMedium),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _NumberField(
                  label: 'meds.form.pickTimeMinute'.tr(),
                  controller: _minuteController,
                  focusNode: _minuteFocus,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _AmPmToggle(
                isPm: _isPm,
                onChanged: (bool value) => setState(() => _isPm = value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'common.confirm'.tr(), onPressed: _confirm),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'common.cancel'.tr(),
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller, required this.focusNode});

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: const InputDecoration(counterText: ''),
        ),
      ],
    );
  }
}

class _AmPmToggle extends StatelessWidget {
  const _AmPmToggle({required this.isPm, required this.onChanged});

  final bool isPm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AmPmSegment(label: 'meds.form.am'.tr(), selected: !isPm, onTap: () => onChanged(false)),
            _AmPmSegment(label: 'meds.form.pm'.tr(), selected: isPm, onTap: () => onChanged(true)),
          ],
        ),
      ),
    );
  }
}

class _AmPmSegment extends StatelessWidget {
  const _AmPmSegment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        color: selected ? AppColors.ink : Colors.transparent,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? AppColors.surface : AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// [TimeOfDay] is always stored/compared in 24-hour form; this is purely a
/// display-conversion helper for this picker's two 12-hour fields.
class TimeOfDayHourMinute12 {
  const TimeOfDayHourMinute12({required this.hour, required this.isPm});
  final int hour;
  final bool isPm;
}

TimeOfDayHourMinute12 _to12Hour(TimeOfDay time) {
  final bool isPm = time.hour >= 12;
  final int hour12 = switch (time.hour % 12) {
    0 => 12,
    final int h => h,
  };
  return TimeOfDayHourMinute12(hour: hour12, isPm: isPm);
}
