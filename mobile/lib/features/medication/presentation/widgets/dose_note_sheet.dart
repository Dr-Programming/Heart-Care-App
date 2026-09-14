import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

abstract final class DoseNoteSheet {
  static Future<String?> show(BuildContext context, {String? initialNote}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      builder: (BuildContext sheetContext) => _NoteSheetBody(initialNote: initialNote),
    );
  }
}

class _NoteSheetBody extends StatefulWidget {
  const _NoteSheetBody({required this.initialNote});

  final String? initialNote;

  @override
  State<_NoteSheetBody> createState() => _NoteSheetBodyState();
}

class _NoteSheetBodyState extends State<_NoteSheetBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save(String value) => Navigator.of(context).pop(value.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(

      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'meds.note.title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'meds.note.label'.tr(),
              hint: 'meds.note.hint'.tr(),
              controller: _controller,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: _save,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'meds.note.save'.tr(),
              onPressed: () => _save(_controller.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'common.cancel'.tr(),
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
