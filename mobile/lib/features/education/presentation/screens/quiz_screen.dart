import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/quiz.dart';
import '../../education_providers.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({required this.topicId, super.key});

  final String topicId;

  static String topicIdFromRoute(GoRouterState state) =>
      state.uri.queryParameters['topic']!;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _questionIndex = 0;
  int? _selectedOptionIndex;

  void _selectOption(int index) {
    if (_selectedOptionIndex != null) return;
    setState(() => _selectedOptionIndex = index);
  }

  void _next(int totalQuestions) {
    setState(() {
      _questionIndex++;
      _selectedOptionIndex = null;
    });
  }

  void _retake() {
    setState(() {
      _questionIndex = 0;
      _selectedOptionIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String languageCode = context.locale.languageCode;
    final AsyncValue<Quiz?> state = ref.watch(
      quizForTopicProvider((widget.topicId, languageCode)),
    );

    return AppScaffold(
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(
            quizForTopicProvider((widget.topicId, languageCode)),
          ),
        ),
        data: (Quiz? quiz) {
          if (quiz == null || quiz.questions.isEmpty) {
            return EmptyState(title: 'education.quiz.notFound'.tr());
          }
          if (_questionIndex >= quiz.questions.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('education.quiz.done'.tr(), textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(label: 'education.quiz.retake'.tr(), onPressed: _retake),
                ],
              ),
            );
          }

          final QuizQuestion question = quiz.questions[_questionIndex];
          final bool answered = _selectedOptionIndex != null;
          final bool isLast = _questionIndex == quiz.questions.length - 1;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
            child: ListView(
              children: <Widget>[
                Text(
                  'education.quiz.questionOf'.tr(
                    namedArgs: <String, String>{
                      'current': '${_questionIndex + 1}',
                      'total': '${quiz.questions.length}',
                    },
                  ),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(question.question, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                for (int i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _OptionTile(
                      option: question.options[i],
                      selected: _selectedOptionIndex == i,
                      revealed: answered,
                      onTap: () => _selectOption(i),
                    ),
                  ),
                if (answered) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: isLast
                        ? 'education.quiz.finish'.tr()
                        : 'education.quiz.next'.tr(),
                    onPressed: () => _next(quiz.questions.length),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.revealed,
    required this.onTap,
  });

  final QuizOption option;
  final bool selected;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool showAsCorrect = revealed && option.correct;
    final bool showAsWrong = revealed && selected && !option.correct;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(
            color: showAsCorrect
                ? AppColors.success
                : showAsWrong
                ? AppColors.critical
                : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(option.text, style: Theme.of(context).textTheme.bodyLarge),
            if (revealed && selected) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                option.correct
                    ? 'education.quiz.correctLabel'.tr()
                    : 'education.quiz.incorrectLabel'.tr(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: option.correct ? AppColors.success : AppColors.critical,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(option.explanation, style: Theme.of(context).textTheme.bodyMedium),
            ] else if (revealed && showAsCorrect) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(option.explanation, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
