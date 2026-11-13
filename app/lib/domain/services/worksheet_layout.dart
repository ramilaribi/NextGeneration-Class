import '../../core/math/formula.dart';
import '../model/quiz.dart';
import '../model/written_page.dart';
import '../model/worksheet.dart';

/// The words a sheet prints, in the teacher's language (the app passes them).
class SheetWords {
  const SheetWords({
    required this.answerTrue,
    required this.answerFalse,
    required this.answer,
    required this.or,
    required this.explanation,
    required this.toCorrect,
    required this.corrige,
    required this.points,
    this.rtl = false,
  });

  final String answerTrue;
  final String answerFalse;

  /// "Réponse :".
  final String answer;

  /// " ou ".
  final String or;

  /// "Explication :".
  final String explanation;

  /// "Question ouverte : à corriger."
  final String toCorrect;
  final String corrige;

  /// "2 pts".
  final String Function(int points) points;

  /// The words are written from the right (Arabic): their lines are too.
  final bool rtl;
}

/// Pictures in a page are given a width by their size, scaled from the screen page (794) to A4 (595 points).
const _pictureWidths = {'small': 150.0, 'medium': 255.0};

/// The blocks of a page written in the app; its Corrigé after a page break in the teacher's version.
List<SheetBlock> pageBlocks(
  List<Map<String, dynamic>> body,
  List<Map<String, dynamic>> answerBody, {
  required bool teacher,
  required Map<String, String> pictureUrls,
  required SheetWords words,
}) => [
  ...deltaBlocks(body, pictureUrls: pictureUrls, teacher: teacher),
  if (teacher && _hasText(answerBody)) ...[
    const SheetPageBreak(),
    SheetLine([SheetText(words.corrige)], heading: 1, rtl: words.rtl),
    ...deltaBlocks(answerBody, pictureUrls: pictureUrls, teacher: true),
  ],
];

bool _hasText(List<Map<String, dynamic>> delta) =>
    delta.any((op) => op['insert'] is Map || (op['insert'] is String && (op['insert'] as String).trim().isNotEmpty));

/// The blocks of a quiz: each question with its number and points, what to answer on, and in the teacher's
/// version the right answers and explanations (design `r3/FicheVersions.png`: only the answers differ).
List<SheetBlock> quizBlocks(Quiz quiz, {required bool teacher, required SheetWords words}) {
  final out = <SheetBlock>[];
  for (var i = 0; i < quiz.questions.length; i++) {
    final q = quiz.questions[i];
    final text = deltaBlocks(q.text, pictureUrls: quiz.pictureUrls, teacher: teacher, indent: 16);
    final first = text.whereType<SheetLine>().firstOrNull;
    out
      ..add(const SheetRule())
      ..add(SheetQuestion(number: i + 1, points: words.points(q.points), spans: first?.spans ?? const [], rtl: first?.rtl ?? false))
      ..addAll(text.where((b) => !identical(b, first)));
    switch (q.type) {
      case QuestionType.mcq:
        out.add(SheetChoices([for (final c in q.choices) (autoFormulas(c.text), teacher && c.id == q.correct)]));
      case QuestionType.trueFalse:
        out.add(SheetChoices([(words.answerTrue, teacher && q.answer == true), (words.answerFalse, teacher && q.answer == false)]));
      case QuestionType.short:
        out.add(
          SheetLine(
            [
              SheetText('${words.answer} '),
              if (teacher) ...formulaSpans(q.accepted.map(autoFormulas).join(words.or), answer: true) else const SheetGap(),
            ],
            indent: 16,
            rtl: words.rtl,
          ),
        );
      case QuestionType.blanks:
        break;
      case QuestionType.open:
        out.add(const SheetLines(3, indent: 16));
        if (teacher) out.add(SheetLine([SheetText(words.toCorrect, answer: true, italic: true)], indent: 16, rtl: words.rtl));
    }
    if (teacher && q.explanation.trim().isNotEmpty) {
      out.add(
        SheetLine(
          [SheetText('${words.explanation} ', answer: true), ...formulaSpans(autoFormulas(q.explanation), answer: true)],
          indent: 16,
          rtl: words.rtl,
        ),
      );
    }
  }
  return out;
}

/// Text with formulas between two $ ("$3/5 = 21/35$ et …"): its text and formula spans.
List<SheetSpan> formulaSpans(String text, {bool answer = false}) {
  final parts = text.split(r'$');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) i.isOdd ? SheetFormula(parts[i], answer: answer) : SheetText(parts[i], answer: answer),
  ];
}

/// A Delta (the page editor's document) as sheet blocks: lines with their formats, formulas and gaps inline,
/// tables, pictures and answer lines on their own.
List<SheetBlock> deltaBlocks(List<Map<String, dynamic>> delta, {required Map<String, String> pictureUrls, required bool teacher, double indent = 0}) {
  final out = <SheetBlock>[];
  var spans = <SheetSpan>[];
  var number = 0;

  void endLine(Map<String, dynamic> attributes) {
    final list = attributes['list'];
    final rtl = attributes['direction'] == 'rtl';
    final align = attributes['align'];
    number = list == 'ordered' ? number + 1 : 0;
    final header = attributes['header'];
    out.add(
      SheetLine(
        spans,
        heading: header is int ? header : null,
        bullet: list == 'bullet' ? '•' : (list == 'ordered' ? '$number.' : null),
        center: align == 'center',
        end: (align == 'right' && !rtl) || (align == 'left' && rtl),
        rtl: rtl,
        indent: indent,
      ),
    );
    spans = <SheetSpan>[];
  }

  void flush() {
    if (spans.isNotEmpty) endLine(const {});
  }

  for (final op in delta) {
    final insert = op['insert'];
    final attributes = op['attributes'] is Map ? Map<String, dynamic>.from(op['attributes'] as Map) : const <String, dynamic>{};
    if (insert is String) {
      final pieces = insert.split('\n');
      for (var i = 0; i < pieces.length; i++) {
        if (pieces[i].isNotEmpty) {
          final size = double.tryParse('${attributes['size'] ?? ''}');
          spans.add(
            SheetText(
              pieces[i],
              bold: attributes['bold'] == true,
              italic: attributes['italic'] == true,
              underline: attributes['underline'] == true,
              color: attributes['color'] as String?,
              size: size == null ? null : size * 0.75,
            ),
          );
        }
        if (i < pieces.length - 1) endLine(attributes);
      }
    } else if (insert is Map) {
      final type = insert.keys.isEmpty ? '' : '${insert.keys.first}';
      final data = insert.values.isEmpty ? null : insert.values.first;
      switch (type) {
        case 'formula':
          spans.add(SheetFormula('${data ?? ''}'));
        case 'blank':
          final answers = data is Map ? [for (final a in data['answers'] as List? ?? const []) '$a'] : const <String>[];
          spans.add(SheetGap(answer: teacher ? answers.firstOrNull : null));
        case 'table':
          flush();
          final rows = data is Map ? data['rows'] : null;
          out.add(
            SheetTable([
              for (final row in rows is List ? rows : const []) [for (final cell in row is List ? row : const []) '${cell ?? ''}'],
            ]),
          );
        case 'picture':
          flush();
          final id = data is Map ? '${data['id'] ?? ''}' : '$data';
          final size = data is Map ? '${data['size'] ?? 'medium'}' : 'medium';
          out.add(SheetPicture(url: pictureUrls[id], maxWidth: _pictureWidths[size]));
        case 'lines':
          flush();
          final count = data is Map ? (data['count'] as num? ?? 2).toInt() : 2;
          out.add(SheetLines(count, indent: indent));
      }
    }
  }
  flush();
  // The editor ends every document with an empty line: not printed.
  while (out.isNotEmpty && out.last is SheetLine && (out.last as SheetLine).spans.isEmpty) {
    out.removeLast();
  }
  return out;
}

/// What the header prints, in the teacher's language (the app passes it).
class SheetLabels {
  const SheetLabels({
    required this.words,
    required this.place,
    required this.date,
    required this.teacherName,
    required this.nameLabel,
    required this.markLabel,
    required this.corrigeTitle,
  });

  final SheetWords words;

  /// "Mathématiques · 4ème année · Les fractions".
  final String place;
  final String date;
  final String teacherName;
  final String nameLabel;
  final String markLabel;

  /// "Quiz : les fractions · Corrigé".
  final String Function(String title) corrigeTitle;
}

/// The sheet of a page or a quiz with the teacher's choices: what the preview shows and the PDF prints.
Worksheet worksheetOf({WrittenPage? page, Quiz? quiz, required WorksheetOptions options, required SheetLabels labels}) {
  final title = options.title.trim().isEmpty ? (page?.document.title ?? quiz?.document.title ?? '') : options.title.trim();
  return Worksheet(
    title: quiz != null && options.teacher ? labels.corrigeTitle(title) : title,
    place: options.showPlace && labels.place.isNotEmpty ? labels.place : null,
    date: options.showDate ? labels.date : null,
    teacherName: options.showTeacher && labels.teacherName.isNotEmpty ? labels.teacherName : null,
    nameLine: options.showNameLine,
    nameLabel: labels.nameLabel,
    markLabel: labels.markLabel,
    mark: quiz == null ? null : '/ ${quiz.totalPoints}',
    blocks: [
      if (page != null) ...pageBlocks(page.body, page.answerBody, teacher: options.teacher, pictureUrls: page.pictureUrls, words: labels.words),
      if (quiz != null) ...quizBlocks(quiz, teacher: options.teacher, words: labels.words),
    ],
  );
}
