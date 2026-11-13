import 'package:equatable/equatable.dart';

/// A printed worksheet ("Fiche", release 3 step 4, designs `r3/Fiche.png`, `r3/FicheVersions.png`): what it
/// shows, in the order printed. The on-screen preview and the PDF both draw these blocks, so they match.
class WorksheetOptions extends Equatable {
  const WorksheetOptions({
    required this.title,
    this.teacher = false,
    this.showPlace = true,
    this.showDate = true,
    this.showTeacher = true,
    this.showNameLine = true,
    this.saveToLibrary = false,
  });

  final String title;

  /// The teacher's version: the right answers, explanations and the Corrigé. The pupils' otherwise.
  final bool teacher;
  final bool showPlace;
  final bool showDate;
  final bool showTeacher;

  /// "Nom et prénom" and, for a quiz, the mark.
  final bool showNameLine;

  /// Also kept in Contenus as a PDF once printed or downloaded.
  final bool saveToLibrary;

  WorksheetOptions copyWith({
    String? title,
    bool? teacher,
    bool? showPlace,
    bool? showDate,
    bool? showTeacher,
    bool? showNameLine,
    bool? saveToLibrary,
  }) => WorksheetOptions(
    title: title ?? this.title,
    teacher: teacher ?? this.teacher,
    showPlace: showPlace ?? this.showPlace,
    showDate: showDate ?? this.showDate,
    showTeacher: showTeacher ?? this.showTeacher,
    showNameLine: showNameLine ?? this.showNameLine,
    saveToLibrary: saveToLibrary ?? this.saveToLibrary,
  );

  @override
  List<Object?> get props => [title, teacher, showPlace, showDate, showTeacher, showNameLine, saveToLibrary];
}

/// A piece of a line.
sealed class SheetSpan extends Equatable {
  const SheetSpan();
}

class SheetText extends SheetSpan {
  const SheetText(this.text, {this.bold = false, this.italic = false, this.underline = false, this.color, this.size, this.answer = false});

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  /// "#RRGGBB".
  final String? color;

  /// Points; the sheet's size otherwise.
  final double? size;

  /// A right answer, written in green in the teacher's version.
  final bool answer;

  @override
  List<Object?> get props => [text, bold, italic, underline, color, size, answer];
}

/// A formula in the simple notation ("3/4 + 1/2").
class SheetFormula extends SheetSpan {
  const SheetFormula(this.source, {this.answer = false});

  final String source;
  final bool answer;

  @override
  List<Object?> get props => [source, answer];
}

/// A gap: dots to write on, or its answer in the teacher's version.
class SheetGap extends SheetSpan {
  const SheetGap({this.answer});

  final String? answer;

  @override
  List<Object?> get props => [answer];
}

/// A block of the sheet.
sealed class SheetBlock extends Equatable {
  const SheetBlock();
}

/// A line of text: [heading] 1 to 3 for titles; [bullet] "•" or "1."; [rtl] written from the right.
class SheetLine extends SheetBlock {
  const SheetLine(this.spans, {this.heading, this.bullet, this.center = false, this.end = false, this.rtl = false, this.indent = 0});

  final List<SheetSpan> spans;
  final int? heading;
  final String? bullet;
  final bool center;
  final bool end;
  final bool rtl;

  /// Points from the start (a question's answers sit under its text).
  final double indent;

  @override
  List<Object?> get props => [spans, heading, bullet, center, end, rtl, indent];
}

/// A table: the first row is the header; a cell holds text with formulas between two $.
class SheetTable extends SheetBlock {
  const SheetTable(this.rows);

  final List<List<String>> rows;

  @override
  List<Object?> get props => [rows];
}

class SheetPicture extends SheetBlock {
  const SheetPicture({this.url, this.maxWidth});

  final String? url;

  /// Points; the line's width otherwise.
  final double? maxWidth;

  @override
  List<Object?> get props => [url, maxWidth];
}

/// Dotted lines to answer on.
class SheetLines extends SheetBlock {
  const SheetLines(this.count, {this.indent = 0});

  final int count;
  final double indent;

  @override
  List<Object?> get props => [count, indent];
}

/// A quiz question's start: its number and its points beside its first line.
class SheetQuestion extends SheetBlock {
  const SheetQuestion({required this.number, required this.points, required this.spans, this.rtl = false});

  final int number;
  final String points;
  final List<SheetSpan> spans;

  /// Its first line is written from the right (the editor keeps each line's direction, whatever the app's language).
  final bool rtl;

  @override
  List<Object?> get props => [number, points, spans, rtl];
}

/// Choices side by side: a round each, filled for the right one in the teacher's version.
class SheetChoices extends SheetBlock {
  const SheetChoices(this.choices);

  /// Text with formulas between two $, and whether it is the right one (shown in the teacher's version only).
  final List<(String, bool)> choices;

  @override
  List<Object?> get props => [choices];
}

/// A thin line between questions.
class SheetRule extends SheetBlock {
  const SheetRule();

  @override
  List<Object?> get props => [];
}

/// A new page (the Corrigé of a page starts on its own).
class SheetPageBreak extends SheetBlock {
  const SheetPageBreak();

  @override
  List<Object?> get props => [];
}

/// The whole sheet: its header, then its blocks.
class Worksheet extends Equatable {
  const Worksheet({
    required this.title,
    this.place,
    this.date,
    this.teacherName,
    this.nameLine = false,
    this.nameLabel = '',
    this.markLabel = '',
    this.mark,
    this.blocks = const [],
  });

  final String title;

  /// "Mathématiques · 4ème année · Les fractions".
  final String? place;
  final String? date;
  final String? teacherName;
  final bool nameLine;

  /// "Nom et prénom :" and "Note :", in the teacher's language.
  final String nameLabel;
  final String markLabel;

  /// "/ 10" for a quiz.
  final String? mark;
  final List<SheetBlock> blocks;

  @override
  List<Object?> get props => [title, place, date, teacherName, nameLine, nameLabel, markLabel, mark, blocks];
}
