import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_text.dart';
import '../../../../../core/theme/brand_colors.dart';
import '../../../../../domain/model/quiz.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../widgets/buttons.dart';
import '../../../../widgets/panels.dart';
import '../../../../widgets/quiz_widgets.dart';
import '../../../../widgets/text_field.dart';

/// A question typed in the fast entry: its line, then one line per choice.
class TypedQuestion {
  const TypedQuestion(this.text, this.choices);

  final String text;
  final List<String> choices;
}

/// Reads the fast entry: a blank line between questions; in each, the question then one choice per line
/// (2 to 6). A block with fewer than two choices waits.
List<TypedQuestion> readTypedQuestions(String text) {
  final out = <TypedQuestion>[];
  for (final block in text.split(RegExp(r'\n\s*\n'))) {
    final lines = [for (final l in block.split('\n')) if (l.trim().isNotEmpty) l.trim()];
    if (lines.length < 3) continue;
    out.add(TypedQuestion(lines.first, lines.skip(1).take(6).toList()));
  }
  return out;
}

/// "Saisie rapide QCM" (design `r3/QuizSaisieRapide.png`): a line for the question, a line per choice,
/// a blank line for the next one; a click on a round marks the right choice. Each question then keeps its
/// own ribbon in the builder. Returns the questions made, or null.
class QuickQcmPanel extends StatefulWidget {
  const QuickQcmPanel({super.key, required this.firstNumber, required this.newId});

  /// The number the first typed question will have in the quiz.
  final int firstNumber;

  /// New ids for questions and choices.
  final String Function(String prefix) newId;

  static Future<List<QuizQuestion>?> open(BuildContext context, {required int firstNumber, required String Function(String) newId}) =>
      showSidePanel<List<QuizQuestion>>(context, width: 560, builder: (_) => QuickQcmPanel(firstNumber: firstNumber, newId: newId));

  @override
  State<QuickQcmPanel> createState() => _QuickQcmPanelState();
}

class _QuickQcmPanelState extends State<QuickQcmPanel> {
  String _text = '';

  /// The right choice of each typed question, by its place.
  final Map<int, int> _right = {};

  List<TypedQuestion> get _typed => readTypedQuestions(_text);

  int get _ready => [for (var i = 0; i < _typed.length; i++) if (_right[i] != null && _right[i]! < _typed[i].choices.length) i].length;

  void _add() {
    final typed = _typed;
    final out = <QuizQuestion>[];
    for (var i = 0; i < typed.length; i++) {
      final right = _right[i];
      if (right == null || right >= typed[i].choices.length) continue;
      final choices = [for (final c in typed[i].choices) QuizChoice(id: widget.newId('c'), text: c)];
      out.add(
        QuizQuestion(
          id: widget.newId('q'),
          type: QuestionType.mcq,
          text: deltaFromLine(typed[i].text),
          choices: choices,
          correct: choices[right].id,
        ),
      );
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final typed = _typed;
    final ready = _ready;
    return SidePanel(
      icon: LucideIcons.zap,
      title: l10n.quickQcmTitle,
      subtitle: l10n.quickQcmSubtitle,
      actions: [
        GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(context).pop()),
        PrimaryButton(
          key: const Key('quick-add'),
          label: l10n.addQuestions(ready),
          icon: LucideIcons.plus,
          height: 44,
          onPressed: ready == 0 ? null : _add,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormInput(
            key: const Key('quick-text'),
            hint: l10n.quickQcmHint,
            maxLines: 10,
            autofocus: true,
            onChanged: (value) => setState(() => _text = value),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < typed.length; i++) ...[
            _TypedCard(
              number: widget.firstNumber + i,
              question: typed[i],
              right: _right[i],
              onRight: (choice) => setState(() => _right[i] = choice),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info, size: 15, color: BrandColors.slate),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.quickQcmNote, style: text.small)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Text(l10n.quickQcmReady(ready), style: text.style(14, FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TypedCard extends StatelessWidget {
  const _TypedCard({required this.number, required this.question, required this.right, required this.onRight});

  final int number;
  final TypedQuestion question;
  final int? right;
  final ValueChanged<int> onRight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: right == null ? BrandColors.line : BrandColors.indigo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number.', style: text.style(15, FontWeight.w800, color: BrandColors.indigo)),
              const SizedBox(width: 8),
              Expanded(child: FormulaText(question.text, style: text.style(15, FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 6),
          for (var c = 0; c < question.choices.length; c++)
            Semantics(
              button: true,
              selected: right == c,
              label: l10n.markRightChoice,
              child: InkWell(
                key: Key('typed-$number-$c'),
                borderRadius: BorderRadius.circular(AppRadii.badge),
                onTap: () => onRight(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      ChoiceRound(right == c ? ChoiceMark.right : ChoiceMark.none, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: FormulaText(question.choices[c], style: text.style(15, FontWeight.w500))),
                    ],
                  ),
                ),
              ),
            ),
          if (right == null) Text(l10n.quickQcmPickRight, style: text.small.copyWith(color: Accent.amber.onSoft)),
        ],
      ),
    );
  }
}
