import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vital_form_controller.dart';
import '../widgets/vital_accent_card.dart';

class VitalFormScreen extends ConsumerStatefulWidget {
  const VitalFormScreen({super.key});

  @override
  ConsumerState<VitalFormScreen> createState() => _VitalFormScreenState();
}

class _VitalFormScreenState extends ConsumerState<VitalFormScreen> {
  late final Map<VitalType, Map<String, TextEditingController>> _controllers;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final VitalFormState state = ref.read(vitalFormControllerProvider);
    final VitalFormController controller = ref.read(
      vitalFormControllerProvider.notifier,
    );
    _controllers = <VitalType, Map<String, TextEditingController>>{
      for (final VitalType type in VitalType.values)
        type: <String, TextEditingController>{
          for (final VitalFieldSpec field in vitalDescriptors[type]!.fields)
            field.key:
                TextEditingController(
                  text: state.valueFor(type, field.key)?.toString() ?? '',
                )..addListener(() {
                  final String raw = _controllers[type]![field.key]!.text;
                  controller.updateValue(type, field.key, double.tryParse(raw));
                }),
        },
    };
    _noteController = TextEditingController(text: state.note ?? '')
      ..addListener(() => controller.updateNote(_noteController.text));
  }

  @override
  void dispose() {
    for (final Map<String, TextEditingController> fields
        in _controllers.values) {
      for (final TextEditingController c in fields.values) {
        c.dispose();
      }
    }
    _noteController.dispose();
    super.dispose();
  }

  String? _fieldError(String? key, VitalFieldSpec field) {
    if (key == null) return null;
    return key.tr(
      namedArgs: <String, String>{
        'field': field.labelKey.tr(),
        'min': _plain(field.min),
        'max': _plain(field.max),
        'unit': field.unit,
      },
    );
  }

  String _plain(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  @override
  Widget build(BuildContext context) {
    final VitalFormState state = ref.watch(vitalFormControllerProvider);
    final VitalFormController controller = ref.read(
      vitalFormControllerProvider.notifier,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'vitals.log.title'.tr(),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: <Widget>[
          Text('vitals.log.chooseType'.tr(), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${'vitals.log.measuredAt'.tr()}: ${DateFormatter.displayDateTime(state.measuredAt, context.locale.languageCode)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final DateTime? date = await showDatePicker(
                    context: context,
                    initialDate: state.measuredAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date == null || !context.mounted) return;
                  final TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(state.measuredAt),
                  );
                  if (time == null || !context.mounted) return;
                  controller.updateMeasuredAt(
                    DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                },
                child: Text('vitals.log.edit'.tr()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final VitalType type in VitalType.values) ...<Widget>[
            VitalAccentCard(
              accent: vitalAccents[type]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  VitalAccentHeader(
                    icon: vitalDescriptors[type]!.icon,
                    accent: vitalAccents[type]!,
                    label: vitalDescriptors[type]!.labelKey.tr(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final VitalFieldSpec field
                      in vitalDescriptors[type]!.fields) ...<Widget>[
                    AppTextField(
                      label: '${field.labelKey.tr()} (${field.unit})',
                      controller: _controllers[type]![field.key],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      errorText: _fieldError(
                        state.errorsByType[type]?[field.key],
                        field,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
          AppTextField(
            label: 'vitals.log.note'.tr(),
            controller: _noteController,
            maxLines: 3,
          ),
          if (state.generalError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.generalError!.tr(),
              style: text.bodyMedium?.copyWith(color: Colors.red),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'vitals.log.confirmAndSave'.tr(),
            isLoading: state.isSaving,
            onPressed: () async {
              final bool ok = await controller.save();
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('vitals.log.saved'.tr())),
                );
                context.pop();
              }
            },
          ),
        ],
      ),
    );
  }
}
