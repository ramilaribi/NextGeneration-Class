import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/l10n/formatting.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/theme/brand_colors.dart';
import '../../../../../domain/model/quiz.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../stateManager/language/language_cubit.dart';
import '../../../../stateManager/library/library_cubit.dart';
import '../../../../stateManager/quiz_editor/quiz_editor_cubit.dart';
import '../../../../stateManager/reference/reference_cubit.dart';
import '../../../../widgets/controls.dart';
import '../../../../widgets/text_field.dart';

/// The durations offered at once; "Autre" for any other.
const _quickDuration = 15;

/// "Réglages" (design `r3/QuizEditeur.png`): the place, the timer, attempts, the grade kept, when the
/// answers are shown, the order; then what the quiz holds, computed.
class QuizSettingsCard extends StatefulWidget {
  const QuizSettingsCard({super.key, required this.onEditPlace});

  /// The chapter changes in "Modifier les détails", like any document's.
  final VoidCallback onEditPlace;

  @override
  State<QuizSettingsCard> createState() => _QuizSettingsCardState();
}

class _QuizSettingsCardState extends State<QuizSettingsCard> {
  /// "Autre" chosen: the minutes field shows even before a number is typed.
  bool _other = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final reference = context.watch<ReferenceCubit>().state.reference;
    final library = context.watch<LibraryCubit>().state.library;
    final cubit = context.read<QuizEditorCubit>();
    final quiz = context.watch<QuizEditorCubit>().state.quiz!;
    final settings = quiz.settings;
    final document = quiz.document;
    final subject = reference?.subjects.where((s) => s.id == document.subjectId).firstOrNull;
    final level = reference?.levels.where((l) => l.id == document.levelId).firstOrNull;
    final chapter = library.chapters.where((c) => c.id == document.chapterId).firstOrNull;
    final place = [
      if (subject != null) isolated(subject.name.of(language)),
      if (level != null) isolated(level.name.of(language)),
      chapter == null ? l10n.unfiled : isolated(chapter.title),
    ].join(l10n.dotSeparator);

    final minutes = settings.timeLimitMin;
    final durationChoice = minutes == null && !_other ? 'none' : (minutes == _quickDuration && !_other ? 'quick' : 'other');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: BrandColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.quizSettings, style: text.style(18, FontWeight.w800)),
          const SizedBox(height: 14),
          LabeledField(
            label: l10n.chapter,
            child: Material(
              color: BrandColors.chalk,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: InkWell(
                key: const Key('quiz-place'),
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: widget.onEditPlace,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: BrandColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(place, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.style(14, FontWeight.w600))),
                      const Icon(LucideIcons.chevronDown, size: 18, color: BrandColors.slate),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: l10n.quizDuration,
            child: SegmentedChoice<String>(
              value: durationChoice,
              onChanged: (choice) {
                setState(() => _other = choice == 'other');
                if (choice == 'none') cubit.setSettings(settings.copyWith(timeLimitMin: () => null));
                if (choice == 'quick') cubit.setSettings(settings.copyWith(timeLimitMin: () => _quickDuration));
              },
              options: [
                SelectOption('none', l10n.durationNone),
                SelectOption('quick', l10n.minutesShort(_quickDuration)),
                SelectOption('other', l10n.durationOther),
              ],
            ),
          ),
          if (durationChoice == 'other') ...[
            const SizedBox(height: 8),
            FormInput(
              key: const Key('quiz-minutes'),
              hint: l10n.durationMinutesHint,
              initialValue: minutes == null ? '' : '$minutes',
              keyboardType: TextInputType.number,
              dense: true,
              suffix: Padding(padding: const EdgeInsetsDirectional.only(end: 12), child: Text(l10n.minutesUnit, style: text.small)),
              onChanged: (value) {
                final n = int.tryParse(value.trim());
                if (n != null && n >= 1 && n <= 300) cubit.setSettings(settings.copyWith(timeLimitMin: () => n));
              },
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectField<int>(
                  label: l10n.quizAttempts,
                  hint: '1',
                  value: settings.attemptsAllowed,
                  onChanged: (n) => cubit.setSettings(settings.copyWith(attemptsAllowed: n)),
                  options: [for (var n = 1; n <= 10; n++) SelectOption(n, '$n')],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: settings.attemptsAllowed > 1 ? 1 : 0.5,
                  child: IgnorePointer(
                    ignoring: settings.attemptsAllowed <= 1,
                    child: SelectField<ScorePolicy>(
                      label: l10n.quizScoreKept,
                      hint: l10n.scoreBest,
                      value: settings.scorePolicy,
                      onChanged: (p) => cubit.setSettings(settings.copyWith(scorePolicy: p)),
                      options: [SelectOption(ScorePolicy.best, l10n.scoreBest), SelectOption(ScorePolicy.last, l10n.scoreLast)],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: l10n.quizShowAnswers,
            child: SegmentedChoice<AnswersShown>(
              value: settings.answersShown,
              onChanged: (v) => cubit.setSettings(settings.copyWith(answersShown: v)),
              options: [
                SelectOption(AnswersShown.afterDeadline, l10n.answersAfterDeadline),
                SelectOption(AnswersShown.afterSubmit, l10n.answersRightAway),
                SelectOption(AnswersShown.never, l10n.answersNever),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              BrandSwitch(
                value: settings.shuffle,
                label: l10n.quizShuffle,
                onChanged: (v) => cubit.setSettings(settings.copyWith(shuffle: v)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.quizShuffle, style: text.style(14, FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Row(
              children: [
                Expanded(child: _Count(value: quiz.questions.length, label: l10n.questionsWord(quiz.questions.length))),
                Expanded(child: _Count(value: quiz.totalPoints, label: l10n.pointsWord(quiz.totalPoints))),
                Expanded(child: _Count(value: quiz.autoCount, label: l10n.correctedAlone(quiz.autoCount))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: text.style(22, FontWeight.w800, color: BrandColors.indigoDeep)),
        Text(label, maxLines: 2, style: text.style(12.5, FontWeight.w500, color: BrandColors.slate)),
      ],
    );
  }
}
