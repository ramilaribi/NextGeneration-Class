import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/formatting.dart';
import '../../core/math/formula.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/brand_colors.dart';
import '../../domain/model/quiz.dart';
import '../../l10n/app_localizations.dart';
import 'written_page.dart';

/// Shared pieces of quizzes (release 3): question types, points, gaps, and the question text as read.

String questionTypeLabel(AppLocalizations l10n, QuestionType type) => switch (type) {
  QuestionType.mcq => l10n.questionMcq,
  QuestionType.trueFalse => l10n.questionTrueFalse,
  QuestionType.short => l10n.questionShort,
  QuestionType.blanks => l10n.questionBlanks,
  QuestionType.open => l10n.questionOpen,
};

IconData questionTypeIcon(QuestionType type) => switch (type) {
  QuestionType.mcq => LucideIcons.listChecks,
  QuestionType.trueFalse => LucideIcons.toggleRight,
  QuestionType.short => LucideIcons.textCursor,
  QuestionType.blanks => LucideIcons.brackets,
  QuestionType.open => LucideIcons.messageCircle,
};

Accent questionTypeAccent(QuestionType type) => switch (type) {
  QuestionType.mcq => Accent.indigo,
  QuestionType.trueFalse => Accent.turquoise,
  QuestionType.short => Accent.amber,
  QuestionType.blanks => Accent.violet,
  QuestionType.open => Accent.orange,
};

/// "1 pt", "2 pts", "1,5 pt".
String pointsLabel(AppLocalizations l10n, num points) =>
    l10n.pointsShort(points.floor(), points is int ? '$points' : scoreText(points.toDouble()));

/// The type's small square, as in the design's question cards.
class QuestionTypeSquare extends StatelessWidget {
  const QuestionTypeSquare(this.type, {super.key, this.size = 30});

  final QuestionType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = questionTypeAccent(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(AppRadii.badge)),
      child: Icon(questionTypeIcon(type), size: size * 0.55, color: accent.onSoft),
    );
  }
}

/// "2 pts" in a grey pill.
class PointsPill extends StatelessWidget {
  const PointsPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.pill)),
    child: Text(label, style: AppText.of(context).style(12.5, FontWeight.w700, color: BrandColors.slate)),
  );
}

/// The question's number in its indigo square.
class QuestionNumber extends StatelessWidget {
  const QuestionNumber(this.number, {super.key});

  final int number;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 28),
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: BrandColors.indigoSoft, borderRadius: BorderRadius.circular(AppRadii.badge)),
    child: Text('$number', style: AppText.of(context).style(13, FontWeight.w800, color: BrandColors.indigo)),
  );
}

/// The text size of a question as read in a quiz: a little larger than a page's for young pupils.
TextStyle questionTextStyle(BuildContext context, {double size = 17}) =>
    pageTextStyle(context).copyWith(fontSize: size, fontWeight: FontWeight.w600, color: BrandColors.ink);

/// What a gap shows: the teacher's answers to edit, a field to type in, or the pupil's answer corrected.
typedef BlankWidgetBuilder = Widget Function(BuildContext context, QuizBlank blank, TextStyle style);

class _BlankBuilder extends EmbedBuilder {
  const _BlankBuilder(this._build);

  final BlankWidgetBuilder _build;

  @override
  String get key => blankEmbed;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    final map = data is Map ? data : const {};
    final blank = QuizBlank(id: '${map['id'] ?? ''}', answers: [for (final a in map['answers'] as List? ?? const []) '$a']);
    return _build(context, blank, embedContext.textStyle);
  }
}

/// The builder of gaps for the question's editor or reader.
EmbedBuilder blankBuilder(BlankWidgetBuilder build) => _BlankBuilder(build);

/// The teacher's gap: its first answer, highlighted ("numérateur"), the others after a slash.
Widget teacherBlank(BuildContext context, QuizBlank blank, TextStyle style, {VoidCallback? onTap}) {
  final l10n = AppLocalizations.of(context);
  final answers = blank.answers.where((a) => a.trim().isNotEmpty).toList();
  final pill = Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: Accent.violet.soft, borderRadius: BorderRadius.circular(6)),
    child: Text(
      answers.isEmpty ? l10n.blankEmpty : answers.join(' / '),
      style: style.copyWith(color: answers.isEmpty ? Accent.red.onSoft : Accent.violet.onSoft, fontWeight: FontWeight.w800),
    ),
  );
  if (onTap == null) return pill;
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(onTap: onTap, child: Tooltip(message: l10n.blankEdit, child: pill)),
  );
}

/// A question's text as read (no editing), with its gaps drawn by [blank].
class QuestionText extends StatelessWidget {
  const QuestionText({super.key, required this.question, this.pictureUrls = const {}, this.blank, this.size = 17});

  final QuizQuestion question;
  final Map<String, String> pictureUrls;
  final BlankWidgetBuilder? blank;
  final double size;

  @override
  Widget build(BuildContext context) => WrittenPageView(
    key: ValueKey(question.text),
    body: question.text,
    pictureUrls: pictureUrls,
    style: questionTextStyle(context, size: size),
    extraBuilders: [blankBuilder(blank ?? (context, b, style) => teacherBlank(context, b, style))],
  );
}

/// A choice or an accepted answer as typed: "3/4" reads as a fraction, text between two $ as a formula.
class FormulaText extends StatelessWidget {
  const FormulaText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TextWithFormulas(autoFormulas(text), style: style ?? questionTextStyle(context, size: 16));
}

/// A line typed in the fast entry as a question's text: its formulas become the page's formula embeds.
List<Map<String, dynamic>> deltaFromLine(String line) {
  final parts = autoFormulas(line.trim()).split(r'$');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        if (i.isOdd)
          {
            'insert': {PageEmbeds.formula: parts[i]},
          }
        else
          {'insert': parts[i]},
    {'insert': '\n'},
  ];
}

/// "3/4" typed in the fast entry becomes a fraction: each word that reads as a formula (a /, a ^, sqrt(…))
/// is put between two $; text already between $ stays as it is.
String autoFormulas(String line) {
  if (line.contains(r'$')) return line;
  final words = line.split(' ');
  return [
    for (final word in words) _looksLikeFormula(word) ? '\$${word.trim()}\$' : word,
  ].join(' ');
}

final _formulaMark = RegExp(r'(\d\s*/\s*\d|\^|sqrt\(|racine\(|<=|>=|!=)');
final _wordLetters = RegExp(r'[A-Za-zÀ-ɏ؀-ۿ]{3,}');

bool _looksLikeFormula(String word) {
  final w = word.trim();
  if (w.isEmpty || !_formulaMark.hasMatch(w) || _wordLetters.hasMatch(w.replaceAll(RegExp(r'sqrt|racine'), ''))) return false;
  return tryFormulaTex(w) != null;
}

/// "Réponses acceptées : 1 · 4/4 · 1,0" as small green pills.
class AnswerPills extends StatelessWidget {
  const AnswerPills({super.key, required this.answers, this.accent = Accent.green});

  final List<String> answers;
  final Accent accent;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final a in answers)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(AppRadii.pill)),
          child: FormulaText(a, style: AppText.of(context).style(13, FontWeight.w700, color: accent.onSoft)),
        ),
    ],
  );
}

/// The round of a choice: empty, chosen (indigo), right (green tick) or wrong (red cross).
enum ChoiceMark { none, chosen, right, wrong }

class ChoiceRound extends StatelessWidget {
  const ChoiceRound(this.mark, {super.key, this.size = 22});

  final ChoiceMark mark;
  final double size;

  @override
  Widget build(BuildContext context) => switch (mark) {
    ChoiceMark.none => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BrandColors.slate.withValues(alpha: 0.5), width: 1.6)),
    ),
    ChoiceMark.chosen => Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BrandColors.indigo, width: 2)),
      child: const DecoratedBox(decoration: BoxDecoration(color: BrandColors.indigo, shape: BoxShape.circle)),
    ),
    ChoiceMark.right => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Accent.green.strong, shape: BoxShape.circle),
      child: Icon(LucideIcons.check, size: size * 0.62, color: Colors.white),
    ),
    ChoiceMark.wrong => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Accent.red.strong, shape: BoxShape.circle),
      child: Icon(LucideIcons.x, size: size * 0.62, color: Colors.white),
    ),
  };
}

/// A choice in its rounded box (design `r3/SeriesQuizPhone.png`): the round, then the text with formulas.
class ChoiceBox extends StatelessWidget {
  const ChoiceBox({super.key, required this.child, required this.mark, this.onTap, this.highlight});

  final Widget child;
  final ChoiceMark mark;
  final VoidCallback? onTap;

  /// The box's colour: green for the right one, indigo for the chosen one.
  final Accent? highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ?? (mark == ChoiceMark.chosen ? Accent.indigo : null);
    final box = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent == Accent.green ? accent!.soft : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.row),
        border: Border.all(color: accent?.strong ?? BrandColors.line, width: accent == null ? 1 : 2),
      ),
      child: Row(
        children: [
          ChoiceRound(mark),
          const SizedBox(width: 14),
          Expanded(child: child),
        ],
      ),
    );
    if (onTap == null) return box;
    return Semantics(
      button: true,
      selected: mark == ChoiceMark.chosen,
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: BorderRadius.circular(AppRadii.row), onTap: onTap, child: box),
      ),
    );
  }
}

const _plain = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i',
  'î': 'i', 'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y',
  'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};
final _arabicMarks = RegExp('[\u064B-\u0652\u0670]');

/// As the server compares a typed answer: lower case, accents removed, spaces trimmed and collapsed, the final
/// full stop removed, 2,5 read as 2.5.
String normalizeAnswer(String value) {
  var out = value.toLowerCase().split('').map((c) => _plain[c] ?? c).join().replaceAll(_arabicMarks, '');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  while (out.endsWith('.')) {
    out = out.substring(0, out.length - 1).trim();
  }
  return out.replaceAllMapped(RegExp(r'(\d)\s*,\s*(\d)'), (m) => '${m[1]}.${m[2]}');
}

final _arabicLetter = RegExp('[\\u0600-\\u06FF]');
final _anyLetter = RegExp('[A-Za-z\\u00C0-\\u024F\\u0600-\\u06FF]');

/// A "Texte à trous" while it is answered: its text, formulas and pictures laid out with plain widgets, the
/// gaps as real fields (inside the page editor, a field never takes the focus on the web). Each line keeps
/// its own direction, as a page does.
class GapsText extends StatelessWidget {
  const GapsText({super.key, required this.question, required this.gap, this.pictureUrls = const {}, this.size = 20});

  final QuizQuestion question;
  final BlankWidgetBuilder gap;
  final Map<String, String> pictureUrls;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = questionTextStyle(context, size: size);
    final lines = <List<Widget>>[[]];
    final lineText = <StringBuffer>[StringBuffer()];
    final blocks = <int, Widget>{};
    void newLine() {
      lines.add([]);
      lineText.add(StringBuffer());
    }

    for (final op in question.text) {
      final insert = op['insert'];
      final attributes = op['attributes'] is Map ? op['attributes'] as Map : const {};
      final style = base.copyWith(
        fontWeight: attributes['bold'] == true ? FontWeight.w800 : null,
        fontStyle: attributes['italic'] == true ? FontStyle.italic : null,
        decoration: attributes['underline'] == true ? TextDecoration.underline : null,
      );
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) newLine();
          for (final word in RegExp(r'\S+\s*|\s+').allMatches(parts[i]).map((m) => m.group(0)!)) {
            lines.last.add(Text(word, style: style));
            lineText.last.write(word);
          }
        }
      } else if (insert is Map) {
        final data = insert.values.isEmpty ? null : insert.values.first;
        switch (insert.keys.firstOrNull) {
          case blankEmbed:
            final map = data is Map ? data : const {};
            lines.last.add(gap(context, QuizBlank(id: '${map['id'] ?? ''}'), style));
          case PageEmbeds.formula:
            lines.last.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4), child: FormulaView(source: '${data ?? ''}', style: style)));
          case PageEmbeds.table:
            blocks[lines.length - 1] = PageTableView(data: TableData.from(data), style: base.copyWith(fontSize: size - 3));
          case PageEmbeds.picture:
            final picture = PictureData.from(data);
            blocks[lines.length - 1] = PagePictureView(url: pictureUrls[picture.id], size: picture.size);
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (blocks[i] != null) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: blocks[i]),
          if (lines[i].isNotEmpty)
            Directionality(
              textDirection: _arabicLetter.hasMatch(_anyLetter.firstMatch(lineText[i].toString())?.group(0) ?? '')
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: lines[i]),
              ),
            ),
        ],
      ],
    );
  }
}
