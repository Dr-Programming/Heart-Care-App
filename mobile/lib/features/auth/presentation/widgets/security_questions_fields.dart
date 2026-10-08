import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/answer_normalizer.dart';
import '../../domain/security_question.dart';

/// State for [SecurityQuestionsFields]: the three chosen questions and their
/// answer boxes. Shared by sign-up and Settings → Security questions so both
/// apply exactly the same rules.
class SecurityQuestionsFieldsController {
  SecurityQuestionsFieldsController({List<SecurityQuestion>? initial})
    : chosen = List<SecurityQuestion>.of(
        initial != null && initial.length == 3
            ? initial
            : const <SecurityQuestion>[
                SecurityQuestion.firstSchool,
                SecurityQuestion.childhoodFriend,
                SecurityQuestion.favoriteTeacher,
              ],
      );

  final List<SecurityQuestion> chosen;
  final List<TextEditingController> answers =
      List<TextEditingController>.generate(3, (_) => TextEditingController());

  /// Translation key of the current error, if any.
  String? errorKey;

  /// Which question/answer pair the error is about, so it shows there.
  int? errorIndex;

  /// Checks the rules (three different questions, each answer 2–100
  /// characters) and returns the answers, or null with [errorKey] set.
  List<SecurityAnswer>? validate() {
    for (int i = 1; i < chosen.length; i++) {
      if (chosen.sublist(0, i).contains(chosen[i])) {
        errorKey = 'auth.securityQuestions.distinct';
        errorIndex = i;
        return null;
      }
    }
    for (int i = 0; i < answers.length; i++) {
      if (!isValidAnswer(answers[i].text)) {
        errorKey = 'auth.securityQuestions.answerLength';
        errorIndex = i;
        return null;
      }
    }
    errorKey = null;
    errorIndex = null;
    return <SecurityAnswer>[
      for (int i = 0; i < 3; i++) SecurityAnswer(chosen[i], answers[i].text),
    ];
  }

  void replaceQuestions(List<SecurityQuestion> questions) {
    if (questions.length != 3) return;
    chosen
      ..clear()
      ..addAll(questions);
  }

  void clearAnswers() {
    for (final TextEditingController c in answers) {
      c.clear();
    }
  }

  void dispose() {
    for (final TextEditingController c in answers) {
      c.dispose();
    }
  }
}

/// Three question pickers, each with an answer box.
class SecurityQuestionsFields extends StatefulWidget {
  const SecurityQuestionsFields({
    required this.controller,
    this.enabled = true,
    super.key,
  });

  final SecurityQuestionsFieldsController controller;
  final bool enabled;

  @override
  State<SecurityQuestionsFields> createState() =>
      _SecurityQuestionsFieldsState();
}

class _SecurityQuestionsFieldsState extends State<SecurityQuestionsFields> {
  @override
  Widget build(BuildContext context) {
    final SecurityQuestionsFieldsController c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          _QuestionPicker(
            key: Key('securityQuestionPicker$i'),
            label: 'auth.securityQuestions.question'.tr(
              namedArgs: <String, String>{'n': '${i + 1}'},
            ),
            value: c.chosen[i],
            enabled: widget.enabled,
            onChanged: (SecurityQuestion q) => setState(() => c.chosen[i] = q),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'auth.securityQuestions.answer'.tr(),
            controller: c.answers[i],
            enabled: widget.enabled,
            errorText: i == c.errorIndex ? c.errorKey?.tr() : null,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// Shows the chosen question in full, wrapping onto as many lines as it
/// needs (a dropdown keeps it to one line and cuts long questions off, in
/// Amharic especially). Tapping opens the list of questions.
class _QuestionPicker extends StatelessWidget {
  const _QuestionPicker({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final String label;
  final SecurityQuestion value;
  final bool enabled;
  final ValueChanged<SecurityQuestion> onChanged;

  Future<void> _choose(BuildContext context) async {
    final SecurityQuestion? picked =
        await showModalBottomSheet<SecurityQuestion>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (BuildContext sheet) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final SecurityQuestion q in SecurityQuestion.values)
                  ListTile(
                    title: Text(q.labelKey.tr()),
                    trailing: q == value ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(sheet).pop(q),
                  ),
              ],
            ),
          ),
        );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _choose(context) : null,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value.labelKey.tr(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: enabled ? AppColors.ink : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
