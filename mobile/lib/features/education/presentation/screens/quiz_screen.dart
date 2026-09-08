import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/quiz_question.dart';
import '../controllers/quiz_controller.dart';
import '../providers/education_providers.dart';

/// FR-EDU-008 — one question at a time, immediate feedback with an
/// explanation for every option, retakeable, no score kept (design
/// decision 8).
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String languageCode = context.locale.languageCode;
    final AsyncValue<List<QuizQuestion>> quiz = ref.watch(
      quizQuestionsProvider(languageCode),
    );

    return AppScaffold(
      title: 'education.quiz.title'.tr(),
      body: quiz.when(
        data: (List<QuizQuestion> questions) {
          if (questions.isEmpty) {
            return EmptyState(title: 'education.quiz.empty'.tr());
          }
          return _QuizBody(questions: questions);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
      ),
    );
  }
}

class _QuizBody extends ConsumerWidget {
  const _QuizBody({required this.questions});

  final List<QuizQuestion> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final QuizState state = ref.watch(quizControllerProvider);

    if (state.questionIndex >= questions.length) {
      return EmptyState(
        icon: Icons.celebration_outlined,
        title: 'education.quiz.finishedTitle'.tr(),
        actionLabel: 'education.quiz.retake'.tr(),
        onAction: () => ref.read(quizControllerProvider.notifier).restart(),
      );
    }

    final QuizQuestion question = questions[state.questionIndex];
    final bool answered = state.selectedOption != null;
    final bool isLast = state.questionIndex + 1 == questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${state.questionIndex + 1} / ${questions.length}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(question.question, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        for (int i = 0; i < question.options.length; i++)
          _OptionTile(
            option: question.options[i],
            isSelected: state.selectedOption == i,
            isCorrect: i == question.correctIndex,
            revealed: answered,
            onTap: answered
                ? null
                : () =>
                      ref.read(quizControllerProvider.notifier).selectOption(i),
          ),
        if (answered) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: isLast ? 'education.quiz.finish'.tr() : 'common.next'.tr(),
            onPressed: () => ref.read(quizControllerProvider.notifier).next(),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  final QuizOption option;
  final bool isSelected;
  final bool isCorrect;
  final bool revealed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color? background;
    if (revealed && isCorrect) {
      background = AppColors.successBg;
    } else if (revealed && isSelected) {
      background = AppColors.criticalBg;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: background ?? AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(option.text, style: Theme.of(context).textTheme.bodyLarge),
              if (revealed) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  option.explanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
