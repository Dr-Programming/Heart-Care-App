import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Collects the free-text note that rides along with a dose log
/// (FR-MED-008 — `DoseLogs.note`).
///
/// A bottom sheet, not a dialog, for the same reason `ConfirmSheet` is one:
/// the action lands under the thumb on a large phone held one-handed. It is
/// deliberately *not* part of the logging tap itself — Decision 6 says logging
/// a dose is one tap, so the note is a second, optional step offered on the
/// already-logged row rather than a prompt standing between the patient and
/// recording the dose.
///
/// Returns the text the user saved (trimmed, and possibly empty — which means
/// "clear the note"), or null when the sheet was dismissed without saving.
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

/// Owns the `TextEditingController` itself rather than letting
/// [DoseNoteSheet.show] create and dispose one around the `await`.
///
/// That shape looked simpler but was wrong: `showModalBottomSheet`'s future
/// completes when the route is popped, while the sheet keeps rebuilding — and
/// so keeps reading the controller — throughout its exit animation. Disposing
/// on the far side of the await therefore threw "A TextEditingController was
/// used after being disposed" on the next frame. Tying the controller to this
/// widget's own lifetime disposes it only once the sheet is really gone.
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
      // Lifts the sheet clear of the soft keyboard, which otherwise covers the
      // very field this sheet exists to expose.
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
