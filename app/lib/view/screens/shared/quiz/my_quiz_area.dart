import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/formatting.dart';
import '../../../../core/l10n/tunis_time.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/quiz.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stateManager/common/load_status.dart';
import '../../../stateManager/language/language_cubit.dart';
import '../../../stateManager/quiz_player/my_quiz_cubit.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/panels.dart';
import 'quiz_player_screen.dart';
import 'quiz_review_view.dart';

/// A quiz homework on the pupil's or the parent's homework page: what it is, "Commencer" or "Reprendre",
/// each attempt sent with its grade, and the grade that counts.
class MyQuizArea extends StatelessWidget {
  const MyQuizArea({super.key, required this.assignmentId, this.studentId, this.name, this.onChanged});

  final String assignmentId;
  final String? studentId;
  final String? name;

  /// After an attempt: the homework page reloads its status.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MyQuizCubit(sl.get(), assignmentId, studentId: studentId)..load(),
    child: _Area(name: name, onChanged: onChanged),
  );
}

class _Area extends StatelessWidget {
  const _Area({required this.name, required this.onChanged});

  final String? name;
  final VoidCallback? onChanged;

  Future<void> _play(BuildContext context, MyQuiz quiz) async {
    final cubit = context.read<MyQuizCubit>();
    final sent = await QuizPlayerScreen.open(
      context,
      assignmentId: quiz.assignmentId,
      title: quiz.title,
      studentId: cubit.studentId,
      name: name,
    );
    await cubit.load();
    if (sent) onChanged?.call();
  }

  Future<void> _see(BuildContext context, AttemptSummary attempt) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MyQuizCubit>();
    try {
      final review = await cubit.attempt(attempt.id);
      if (!context.mounted) return;
      await showSidePanel<void>(
        context,
        width: 680,
        builder: (panelContext) => SidePanel(
          icon: LucideIcons.listChecks,
          accent: Accent.violet,
          title: l10n.attemptNumber(attempt.number),
          actions: [PrimaryButton(label: l10n.close, height: 44, onPressed: () => Navigator.of(panelContext).pop())],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AttemptScoreCard(review: review, name: name),
              if (!review.answersShown) ...[const SizedBox(height: 12), InfoNoteText(l10n.answersLaterNote)],
              const SizedBox(height: 12),
              AttemptItemsView(review: review),
            ],
          ),
        ),
      );
    } on Object catch (error) {
      if (context.mounted) showNotice(context, failureText(l10n, ApiFailure.from(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final state = context.watch<MyQuizCubit>().state;
    final quiz = state.quiz;
    if (quiz == null) {
      if (state.status == LoadStatus.failure) return FailureBanner(state.failure!, onRetry: context.read<MyQuizCubit>().load);
      return const LinearProgressIndicator(minHeight: 3);
    }
    final facts = [
      l10n.questionsCount(quiz.questionCount),
      l10n.pointsCount(quiz.totalPoints),
      quiz.timeLimitMin == null ? l10n.durationNone : l10n.minutesShort(quiz.timeLimitMin!),
      l10n.attemptsAllowed(quiz.attemptsAllowed),
    ].join(l10n.dotSeparator);
    final now = DateTime.now().toUtc();
    final String? refused = quiz.current != null || quiz.canStart
        ? null
        : (quiz.attemptsLeft == 0 ? l10n.noAttemptLeft : (quiz.deadlineAt.isBefore(now) ? l10n.quizDeadlinePassed : l10n.quizClosed));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: BrandColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Accent.violet.soft, borderRadius: BorderRadius.circular(AppRadii.md)),
                    child: Icon(LucideIcons.listChecks, size: 22, color: Accent.violet.onSoft),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.kindQuiz, style: text.style(16, FontWeight.w800)),
                        Text(facts, style: text.style(13, FontWeight.w500, color: BrandColors.slate)),
                      ],
                    ),
                  ),
                ],
              ),
              if (quiz.kept != null) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.quizKept(scoreText(quiz.kept!), quiz.totalPoints),
                  key: const Key('quiz-kept'),
                  style: text.style(15, FontWeight.w800, color: Accent.green.onSoft),
                ),
              ],
              const SizedBox(height: 14),
              if (quiz.current != null)
                PrimaryButton(key: const Key('quiz-resume'), label: l10n.resumeQuiz, icon: LucideIcons.play, height: 52, onPressed: () => _play(context, quiz))
              else if (quiz.canStart)
                PrimaryButton(
                  key: const Key('quiz-start'),
                  label: quiz.attempts.isEmpty ? l10n.startQuiz : l10n.startAgain,
                  icon: LucideIcons.play,
                  height: 52,
                  onPressed: () => _play(context, quiz),
                )
              else if (refused != null)
                Text(refused, style: text.small),
              if (quiz.current == null && quiz.canStart && quiz.timeLimitMin != null) ...[
                const SizedBox(height: 8),
                Text(l10n.timerNote(quiz.timeLimitMin!), style: text.small),
              ],
            ],
          ),
        ),
        if (quiz.attempts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: BrandColors.line),
            ),
            child: Column(
              children: [
                for (final a in quiz.attempts.reversed)
                  ListTile(
                    key: Key('attempt-${a.number}'),
                    onTap: () => _see(context, a),
                    title: Text(l10n.attemptNumber(a.number), style: text.style(15, FontWeight.w700)),
                    subtitle: Text(
                      a.submittedAt == null ? '' : l10n.sentOn(l10n.dueOn(dayInSentence(TunisTime.day(a.submittedAt!), language), hm(a.submittedAt!))),
                      style: text.small,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          a.pending ? l10n.waitingShort : '${scoreText(a.score ?? 0)}/${quiz.totalPoints}',
                          style: text.style(15, FontWeight.w800, color: a.pending ? Accent.amber.onSoft : BrandColors.ink),
                        ),
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.chevronRightDir, size: 18, color: BrandColors.slate),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
