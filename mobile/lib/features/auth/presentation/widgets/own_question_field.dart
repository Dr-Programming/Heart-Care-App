import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/answer_normalizer.dart';

/// A question is 5 to 150 characters, so it reads as a question.
const int minOwnQuestionLength = 5;
const int maxOwnQuestionLength = 150;

/// State for [OwnQuestionField]: whether the patient adds their own question,
/// and its text and answer.
class OwnQuestionController {
  bool enabled = false;
  final TextEditingController question = TextEditingController();
  final TextEditingController answer = TextEditingController();

  String? questionErrorKey;
  String? answerErrorKey;

  /// Checks what was typed. Returns false with an error set when the section
  /// is on and something is missing; true when it is off or complete.
  bool validate() {
    questionErrorKey = null;
    answerErrorKey = null;
    if (!enabled) return true;
    final int length = question.text.trim().runes.length;
    if (length < minOwnQuestionLength || length > maxOwnQuestionLength) {
      questionErrorKey = 'auth.ownQuestion.questionLength';
    }
    if (!isValidAnswer(answer.text)) {
      answerErrorKey = 'auth.securityQuestions.answerLength';
    }
    return questionErrorKey == null && answerErrorKey == null;
  }

  /// The question and answer to save, or null when the section is off.
  ({String question, String answer})? get value =>
      enabled ? (question: question.text.trim(), answer: answer.text) : null;

  void clear() {
    enabled = false;
    question.clear();
    answer.clear();
    questionErrorKey = null;
    answerErrorKey = null;
  }

  void dispose() {
    question.dispose();
    answer.dispose();
  }
}

/// "Add your own question": an optional extra question the patient writes
/// themselves. It is kept on this phone and asked there when resetting the PIN.
class OwnQuestionField extends StatefulWidget {
  const OwnQuestionField({
    required this.controller,
    this.enabled = true,
    this.currentQuestion,
    this.onToggled,
    super.key,
  });

  /// Called when the patient switches the section on or off.
  final VoidCallback? onToggled;

  final OwnQuestionController controller;
  final bool enabled;

  /// The question already saved, shown so the patient knows it is set.
  final String? currentQuestion;

  @override
  State<OwnQuestionField> createState() => _OwnQuestionFieldState();
}

class _OwnQuestionFieldState extends State<OwnQuestionField> {
  @override
  Widget build(BuildContext context) {
    final OwnQuestionController c = widget.controller;
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      key: const Key('ownQuestionCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const IconCircle(
                icon: Icons.edit_note_rounded,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'auth.ownQuestion.title'.tr(),
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'auth.ownQuestion.hint'.tr(),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const Key('ownQuestionSwitch'),
                value: c.enabled,
                onChanged: widget.enabled
                    ? (bool on) {
                        setState(() => c.enabled = on);
                        widget.onToggled?.call();
                      }
                    : null,
              ),
            ],
          ),
          if (!c.enabled && widget.currentQuestion != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'auth.ownQuestion.current'.tr(
                namedArgs: <String, String>{
                  'question': widget.currentQuestion!,
                },
              ),
              key: const Key('ownQuestionCurrent'),
              style: text.bodyMedium,
            ),
          ],
          if (c.enabled) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: const Key('ownQuestionText'),
              label: 'auth.ownQuestion.question'.tr(),
              hint: 'auth.ownQuestion.questionHint'.tr(),
              controller: c.question,
              enabled: widget.enabled,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              errorText: c.questionErrorKey?.tr(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: const Key('ownQuestionAnswer'),
              label: 'auth.securityQuestions.answer'.tr(),
              controller: c.answer,
              enabled: widget.enabled,
              keyboardType: TextInputType.text,
              errorText: c.answerErrorKey?.tr(),
            ),
          ],
        ],
      ),
    );
  }
}
