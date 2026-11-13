import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/homework.dart';
import '../../../../domain/model/quiz.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stateManager/common/load_status.dart';
import '../../../stateManager/quiz_player/quiz_correction_cubit.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/homework_widgets.dart';
import '../../../widgets/page_frame.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/text_field.dart';
import '../../shared/quiz/quiz_review_view.dart';

/// A pupil's quiz in "À corriger" (release 3): every answer is shown corrected, the open questions take the
/// teacher's points in half points, then "Enregistrer et suivant".
class QuizCorrectionBody extends StatelessWidget {
  const QuizCorrectionBody({super.key, required this.assignment, required this.copies, required this.index});

  final Assignment assignment;
  final List<RecipientRow> copies;
  final int index;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => QuizCorrectionCubit(sl.get(), assignment.id, copies, index: index)..load(),
    child: _Body(assignment: assignment),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.assignment});

  final Assignment assignment;

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go(Routes.teacherAssignments);

  Future<void> _save(BuildContext context, {required bool next}) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<QuizCorrectionCubit>();
    final ok = await cubit.save();
    if (!context.mounted) return;
    if (!ok) {
      final failure = cubit.state.failure;
      if (failure != null) showNotice(context, failureText(l10n, failure));
      return;
    }
    showNotice(context, l10n.correctionSaved);
    if (next) {
      if (cubit.state.index + 1 < cubit.copies.length) {
        await cubit.go(cubit.state.index + 1);
      } else if (context.mounted) {
        _back(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final phone = isPhone(context);
    final state = context.watch<QuizCorrectionCubit>().state;
    final cubit = context.read<QuizCorrectionCubit>();
    final correction = state.correction;
    final review = state.attempt;
    final count = cubit.copies.length;

    final topBar = Container(
      padding: EdgeInsetsDirectional.fromSTEB(phone ? 12 : 24, 12, phone ? 12 : 24, 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: BrandColors.line))),
      child: Row(
        children: [
          IconSquareButton(icon: LucideIcons.arrowLeftDir, tooltip: l10n.back, onPressed: () => _back(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.style(phone ? 16 : 18, FontWeight.w800)),
                Text(
                  correction == null ? '' : correction.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.style(13, FontWeight.w600, color: BrandColors.slate),
                ),
              ],
            ),
          ),
          if (count > 1) ...[
            IconSquareButton(
              icon: LucideIcons.chevronLeftDir,
              tooltip: l10n.previousCopy,
              size: phone ? 40 : 44,
              onPressed: state.index > 0 ? () => cubit.go(state.index - 1) : null,
            ),
            if (!phone)
              SizedBox(
                width: 110,
                child: Text(l10n.copyOf(state.index + 1, count), textAlign: TextAlign.center, style: text.style(14, FontWeight.w700)),
              )
            else
              const SizedBox(width: 6),
            IconSquareButton(
              icon: LucideIcons.chevronRightDir,
              tooltip: l10n.nextCopy,
              size: phone ? 40 : 44,
              onPressed: state.index + 1 < count ? () => cubit.go(state.index + 1) : null,
            ),
          ],
        ],
      ),
    );

    final Widget body;
    if (state.status == LoadStatus.failure && correction == null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(24), child: FailureBanner(state.failure!, onRetry: cubit.load)));
    } else if (correction == null) {
      body = const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(minHeight: 3));
    } else if (review == null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.quizNotTakenYet, style: text.small)));
    } else {
      body = SingleChildScrollView(
        padding: EdgeInsets.all(phone ? 16 : 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(correction.fullName, style: text.style(20, FontWeight.w800))),
                    if (correction.status != null) HomeworkStatusChip(correction.status),
                  ],
                ),
                if (correction.attempts.length > 1) ...[
                  const SizedBox(height: 10),
                  PillTabs<String>(
                    items: [for (final a in correction.attempts) TabItem(a.id, l10n.attemptNumber(a.number))],
                    value: review.id,
                    onChanged: cubit.showAttempt,
                  ),
                ],
                const SizedBox(height: 12),
                AttemptScoreCard(review: review),
                const SizedBox(height: 12),
                AttemptItemsView(
                  review: review,
                  teacher: true,
                  extra: (item) => item.question.type != QuestionType.open
                      ? null
                      : Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: FormInput(
                                key: ValueKey('score-${review.id}-${item.question.id}'),
                                hint: l10n.scoreHint,
                                initialValue: state.scores[item.question.id] ?? '',
                                dense: true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                errorText: state.errors.contains(item.question.id) ? l10n.scoreOutOf(item.maxPoints) : null,
                                onChanged: (value) => cubit.setScore(item.question.id, value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('/ ${item.maxPoints}', style: text.style(15, FontWeight.w700, color: BrandColors.slate)),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                FormInput(
                  key: ValueKey('comment-${review.id}'),
                  label: l10n.commentLabel,
                  labelSuffix: l10n.optional,
                  hint: l10n.commentHint,
                  initialValue: state.comment,
                  maxLines: 3,
                  onChanged: cubit.setComment,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final waiting = review?.items.any((i) => i.question.type == QuestionType.open) ?? false;
    return Scaffold(
      backgroundColor: BrandColors.chalk,
      body: SafeArea(
        child: Column(
          children: [
            topBar,
            Expanded(child: body),
            if (review != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: BrandColors.line))),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!waiting) ...[Text(l10n.quizCorrectedAlone, style: text.small), const SizedBox(height: 8)],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: SecondaryButton(label: l10n.save, height: 48, onPressed: state.saving ? null : () => _save(context, next: false)),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              flex: phone ? 2 : 1,
                              child: PrimaryButton(
                                key: const Key('quiz-save-next'),
                                label: l10n.saveAndNext,
                                height: 48,
                                loading: state.saving,
                                onPressed: () => _save(context, next: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
