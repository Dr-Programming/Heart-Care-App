import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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

  /// Checks the rules (three different questions, each answer 2–100
  /// characters) and returns the answers, or null with [errorKey] set.
  List<SecurityAnswer>? validate() {
    if (chosen.toSet().length != chosen.length) {
      errorKey = 'auth.securityQuestions.distinct';
      return null;
    }
    if (!answers.every((TextEditingController c) => isValidAnswer(c.text))) {
      errorKey = 'auth.securityQuestions.answerLength';
      return null;
    }
    errorKey = null;
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
  State<SecurityQuestionsFields> createState() => _SecurityQuestionsFieldsState();
}

class _SecurityQuestionsFieldsState extends State<SecurityQuestionsFields> {
  @override
  Widget build(BuildContext context) {
    final SecurityQuestionsFieldsController c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          DropdownButtonFormField<SecurityQuestion>(
            key: Key('securityQuestionPicker$i'),
            initialValue: c.chosen[i],
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'auth.securityQuestions.question'.tr(
                namedArgs: <String, String>{'n': '${i + 1}'},
              ),
            ),
            items: <DropdownMenuItem<SecurityQuestion>>[
              for (final SecurityQuestion q in SecurityQuestion.values)
                DropdownMenuItem<SecurityQuestion>(value: q, child: Text(q.labelKey.tr())),
            ],
            onChanged: widget.enabled
                ? (SecurityQuestion? q) {
                    if (q != null) setState(() => c.chosen[i] = q);
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'auth.securityQuestions.answer'.tr(),
            controller: c.answers[i],
            enabled: widget.enabled,
            errorText: i == 0 ? c.errorKey?.tr() : null,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
