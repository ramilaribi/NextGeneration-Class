import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/quiz.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/quiz_widgets.dart';

/// One question while the quiz is taken: its text, then the way to answer it (design `r3/SeriesQuizPhone.png`).
/// A choice is sent at once ([onChoose]); a typed answer a moment later ([onType]).
class QuizQuestionView extends StatefulWidget {
  const QuizQuestionView({
    super.key,
    required this.question,
    required this.answer,
    required this.pictureUrls,
    required this.onChoose,
    required this.onType,
    this.enabled = true,
  });

  final QuizQuestion question;
  final QuizAnswer? answer;
  final Map<String, String> pictureUrls;
  final ValueChanged<QuizAnswer> onChoose;
  final ValueChanged<QuizAnswer> onType;
  final bool enabled;

  @override
  State<QuizQuestionView> createState() => _QuizQuestionViewState();
}

class _QuizQuestionViewState extends State<QuizQuestionView> {
  late final _text = TextEditingController(text: '${widget.answer?['text'] ?? ''}');

  /// One field per gap, kept while the question shows.
  final _blanks = <String, TextEditingController>{};

  Map<String, String> get _blankValues => {for (final e in _blanks.entries) e.key: e.value.text};

  TextEditingController _blankField(String id) => _blanks.putIfAbsent(id, () {
    final saved = (widget.answer?['blanks'] as Map?)?[id];
    return TextEditingController(text: saved == null ? '' : '$saved');
  });

  @override
  void dispose() {
    _text.dispose();
    for (final c in _blanks.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _gap(BuildContext context, QuizBlank blank, TextStyle style) {
    final l10n = AppLocalizations.of(context);
    final field = _blankField(blank.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: SizedBox(
        width: 140,
        child: TextField(
          key: Key('gap-${blank.id}'),
          controller: field,
          enabled: widget.enabled,
          style: style.copyWith(fontWeight: FontWeight.w700, color: BrandColors.indigo),
          onChanged: (_) => widget.onType({'blanks': _blankValues}),
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.gapHint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true,
            fillColor: BrandColors.indigoSoft,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final q = widget.question;
    final answer = widget.answer;
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.row), borderSide: const BorderSide(color: BrandColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.row), borderSide: const BorderSide(color: BrandColors.line)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.row),
        borderSide: const BorderSide(color: BrandColors.indigo, width: 2),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (q.type == QuestionType.blanks)
          GapsText(question: q, pictureUrls: widget.pictureUrls, gap: _gap)
        else
          QuestionText(question: q, pictureUrls: widget.pictureUrls, size: 20),
        const SizedBox(height: 18),
        switch (q.type) {
          QuestionType.mcq => Column(
            children: [
              for (final c in q.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ChoiceBox(
                    key: Key('choice-${c.id}'),
                    mark: answer?['choice'] == c.id ? ChoiceMark.chosen : ChoiceMark.none,
                    onTap: widget.enabled ? () => widget.onChoose({'choice': c.id}) : null,
                    child: FormulaText(c.text, style: questionTextStyle(context, size: 19)),
                  ),
                ),
            ],
          ),
          QuestionType.trueFalse => Column(
            children: [
              for (final value in const [true, false])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ChoiceBox(
                    key: Key('tf-$value'),
                    mark: answer?['value'] == value ? ChoiceMark.chosen : ChoiceMark.none,
                    onTap: widget.enabled ? () => widget.onChoose({'value': value}) : null,
                    child: Text(value ? l10n.answerTrue : l10n.answerFalse, style: text.style(18, FontWeight.w700)),
                  ),
                ),
            ],
          ),
          QuestionType.short => TextField(
            key: const Key('short-answer'),
            controller: _text,
            enabled: widget.enabled,
            style: text.style(18, FontWeight.w600),
            onChanged: (value) => widget.onType({'text': value}),
            decoration: fieldDecoration.copyWith(hintText: l10n.shortAnswerHint),
          ),
          QuestionType.blanks => Text(l10n.gapsInstruction, style: text.small),
          QuestionType.open => TextField(
            key: const Key('open-answer'),
            controller: _text,
            enabled: widget.enabled,
            minLines: 4,
            maxLines: 10,
            style: text.style(16, FontWeight.w500, height: 1.5),
            onChanged: (value) => widget.onType({'text': value}),
            decoration: fieldDecoration.copyWith(hintText: l10n.openAnswerHint),
          ),
        },
      ],
    );
  }
}
