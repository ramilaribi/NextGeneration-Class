import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/l10n/formatting.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/quiz.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/quiz_widgets.dart';

/// The grade of an attempt in its square: "6 /7", or the points so far while open questions wait.
class AttemptScoreCard extends StatelessWidget {
  const AttemptScoreCard({super.key, required this.review, this.name});

  final AttemptReview review;

  /// "Bien joué, Adam !"; without a name, "C'est envoyé !".
  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final score = review.score ?? review.autoScore ?? 0;
    final pendingPoints = review.items.where((i) => i.waiting).fold<int>(0, (sum, i) => sum + i.maxPoints);
    final pendingQuestion = review.items.where((i) => i.waiting).firstOrNull;
    final title = review.pending ? l10n.quizSentTitle : (name == null ? l10n.wellDone : l10n.wellDoneName(name!));
    final subtitle = review.pending
        ? (pendingQuestion != null && review.items.where((i) => i.waiting).length == 1
              ? l10n.quizWaitingOne(pendingQuestion.number, pendingPoints)
              : l10n.quizWaitingSome(pendingPoints))
        : l10n.quizScoreOutOf(scoreText(score), review.maxScore);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: BrandColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 86,
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Accent.violet.soft, borderRadius: BorderRadius.circular(AppRadii.tile)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(scoreText(score), key: const Key('quiz-score'), style: text.style(30, FontWeight.w800, color: Accent.violet.onSoft)),
                  Text('/${review.maxScore}', style: text.style(14, FontWeight.w700, color: Accent.violet.onSoft)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.style(19, FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: text.style(13.5, FontWeight.w500, color: BrandColors.slate, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Each question after sending (design `r3/SeriesQuizPhone.png`, "La note"): right, wrong or waiting, what
/// was answered, and once the answers are shown, the right one and the explanation. [extra] adds the
/// teacher's score field under an open question.
class AttemptItemsView extends StatelessWidget {
  const AttemptItemsView({super.key, required this.review, this.extra, this.teacher = false});

  final AttemptReview review;
  final Widget? Function(ReviewItem item)? extra;

  /// The teacher reads "a répondu" rather than "tu as répondu".
  final bool teacher;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      border: Border.all(color: BrandColors.line),
    ),
    child: Column(
      children: [
        for (var i = 0; i < review.items.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: BrandColors.line, indent: 16, endIndent: 16),
          _ItemRow(item: review.items[i], review: review, extra: extra?.call(review.items[i]), teacher: teacher),
        ],
      ],
    ),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.review, required this.extra, required this.teacher});

  final ReviewItem item;
  final AttemptReview review;
  final Widget? extra;
  final bool teacher;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final q = item.question;
    final answer = item.answer ?? const <String, dynamic>{};
    final shown = review.answersShown;
    final quiet = text.style(14, FontWeight.w500, color: BrandColors.slate, height: 1.4);
    final green = text.style(14, FontWeight.w700, color: Accent.green.onSoft, height: 1.4);
    final icon = item.waiting
        ? Icon(LucideIcons.clock, size: 22, color: Accent.amber.onSoft)
        : (item.right ?? false)
        ? Icon(LucideIcons.circleCheck, size: 22, color: Accent.green.strong)
        : (item.points ?? 0) > 0
        ? Icon(LucideIcons.circleDot, size: 22, color: Accent.amber.strong)
        : Icon(LucideIcons.circleX, size: 22, color: Accent.red.strong);

    String given() => switch (q.type) {
      QuestionType.mcq => q.choices.where((c) => c.id == answer['choice']).firstOrNull?.text ?? '',
      QuestionType.trueFalse => answer['value'] == null ? '' : (answer['value'] == true ? l10n.answerTrue : l10n.answerFalse),
      _ => '${answer['text'] ?? ''}',
    };
    String right() => switch (q.type) {
      QuestionType.mcq => q.choices.where((c) => c.id == q.correct).firstOrNull?.text ?? '',
      QuestionType.trueFalse => q.answer == null ? '' : (q.answer! ? l10n.answerTrue : l10n.answerFalse),
      QuestionType.short => q.accepted.firstOrNull ?? '',
      _ => '',
    };

    final details = <Widget>[];
    switch (q.type) {
      case QuestionType.mcq || QuestionType.trueFalse || QuestionType.short:
        final value = given();
        details.add(
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(value.isEmpty ? l10n.noAnswer : (teacher ? l10n.answeredTeacher : l10n.answeredPupil), style: quiet),
              if (value.isNotEmpty) FormulaText(value, style: text.style(14, FontWeight.w700, height: 1.4)),
            ],
          ),
        );
        if (shown && item.right == false && right().isNotEmpty) {
          details.add(
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(l10n.rightAnswerIs, style: green),
                FormulaText(right(), style: green),
              ],
            ),
          );
        }
      case QuestionType.blanks:
        if (shown && item.right == false) {
          final rights = [for (final b in q.blanks) if (b.answers.isNotEmpty) b.answers.first];
          if (rights.isNotEmpty) details.add(Text('${l10n.rightAnswerIs} ${rights.join(', ')}', style: green));
        }
      case QuestionType.open:
        final value = given();
        details.add(
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Text(value.trim().isEmpty ? l10n.noAnswer : value, textDirection: writtenDirection(value), style: text.style(14.5, FontWeight.w500, height: 1.5)),
          ),
        );
        if (item.waiting && extra == null) {
          details.add(Text(l10n.waitingCorrection(item.maxPoints), style: text.style(13.5, FontWeight.w700, color: Accent.amber.onSoft)));
        }
    }
    if (shown && q.explanation.trim().isNotEmpty) {
      details.add(FormulaText(q.explanation, style: text.style(13.5, FontWeight.w500, color: BrandColors.body, height: 1.45)));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.number}.', style: text.style(16, FontWeight.w800)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: QuestionText(
                        question: q,
                        pictureUrls: review.pictureUrls,
                        size: 16,
                        blank: (context, blank, style) => _givenGap(context, blank, style, answer, shown),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.waiting ? '–/${item.maxPoints}' : '${scoreText(item.points!)}/${item.maxPoints}',
                      style: text.style(13, FontWeight.w700, color: BrandColors.slate),
                    ),
                  ],
                ),
                for (final d in details) ...[const SizedBox(height: 6), d],
                if (extra != null) ...[const SizedBox(height: 10), extra!],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A gap as answered: green when right, red when not.
  static Widget _givenGap(BuildContext context, QuizBlank blank, TextStyle style, Map<String, dynamic> answer, bool shown) {
    final value = '${(answer['blanks'] as Map?)?[blank.id] ?? ''}';
    final right = blank.answers.isEmpty ? null : blank.answers.any((a) => _same(a, value));
    final accent = right == null ? Accent.indigo : (right ? Accent.green : Accent.red);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(6)),
      child: Text(value.trim().isEmpty ? '…' : value, style: style.copyWith(color: accent.onSoft, fontWeight: FontWeight.w800)),
    );
  }

  /// The server's matching (business rules 4), for colouring only.
  static bool _same(String a, String b) => normalizeAnswer(a) == normalizeAnswer(b);
}
