import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color, Text, TextDirection, TextStyle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/math/formula.dart';
import '../../core/platform/widget_image.dart';
import '../../domain/model/worksheet.dart';
import '../../domain/services/worksheet_layout.dart';
import '../../domain/services/worksheet_maker.dart';

const _ink = PdfColor.fromInt(0xFF1A1D3A);
const _slate = PdfColor.fromInt(0xFF6B7090);
const _indigo = PdfColor.fromInt(0xFF2B3990);
const _green = PdfColor.fromInt(0xFF237A35);
const _line = PdfColor.fromInt(0xFFDCDFEA);
const _dots = PdfColor.fromInt(0xFF9AA0B8);
const _header = PdfColor.fromInt(0xFFEEF0FA);
const _size = 11.0;
final _arabicLetter = RegExp(r'[\u0600-\u06FF]');

/// The right choice in the teacher's version: a green round with a white tick.
const _checked =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="#237A35"/>'
    '<path d="M7 12.5l3.2 3.2L17 9" fill="none" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>';

/// A formula drawn as a picture: the PNG and its size in points.
typedef FormulaImage = ({Uint8List png, double width, double height});

/// Draws a formula ("3/4 + 1/2") for the PDF.
typedef FormulaPainter = Future<FormulaImage> Function(String source, {required bool answer, required double size});

/// Draws a formula with the screen's renderer (flutter_math_fork), five times sharper than printed.
Future<FormulaImage> paintFormula(String source, {required bool answer, required double size}) async {
  final style = TextStyle(fontSize: size, color: answer ? const Color(0xFF237A35) : const Color(0xFF1A1D3A));
  final fallback = Text(source, style: style, textDirection: TextDirection.ltr);
  final tex = tryFormulaTex(source);
  final (png, s) = await widgetToPng(
    tex == null || tex.isEmpty ? fallback : Math.tex(tex, mathStyle: MathStyle.text, textStyle: style, onErrorFallback: (_) => fallback),
  );
  return (png: png, width: s.width, height: s.height);
}

/// The worksheet as an A4 PDF (designs `r3/Fiche.png`, `r3/FicheVersions.png`): the header with the brand,
/// the title, the place, the teacher and the date, the name line, then the blocks; page numbers below. The
/// text stays text (it can be searched and copied); formulas are drawn as sharp pictures.
class PdfWorksheetMaker implements WorksheetMaker {
  PdfWorksheetMaker({FormulaPainter? formulas, Dio? dio}) : _formulas = formulas ?? paintFormula, _dio = dio ?? Dio();

  final FormulaPainter _formulas;
  final Dio _dio;

  Future<pw.Font> _font(String file) async => pw.Font.ttf(await rootBundle.load('assets/google_fonts/$file'));

  @override
  Future<Uint8List> pdf(Worksheet sheet, {required bool arabic}) async {
    final regular = await _font('PlusJakartaSans-Regular.ttf');
    final bold = await _font('PlusJakartaSans-Bold.ttf');
    final italic = await _font('PlusJakartaSans-Italic.ttf');
    final boldItalic = await _font('PlusJakartaSans-BoldItalic.ttf');
    final arRegular = await _font('IBMPlexSansArabic-Regular.ttf');
    final arBold = await _font('IBMPlexSansArabic-Bold.ttf');
    final arabicTheme = pw.ThemeData.withFont(base: arRegular, bold: arBold, italic: arRegular, boldItalic: arBold, fontFallback: [regular, bold]);
    final latinTheme = pw.ThemeData.withFont(base: regular, bold: bold, italic: italic, boldItalic: boldItalic, fontFallback: [arRegular, arBold]);
    final theme = arabic ? arabicTheme : latinTheme;
    final logo = pw.MemoryImage((await rootBundle.load('assets/brand/symbol.png')).buffer.asUint8List());
    final render = _Renderer(await _formulaImages(sheet), await _pictures(sheet), arabicTheme);

    final doc = pw.Document(title: sheet.title, creator: 'NextGeneration Class');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 40, marginRight: 40, marginTop: 36, marginBottom: 30),
        theme: theme,
        textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        footer: (context) => pw.Center(
          child: pw.Text(
            'NextGeneration Class · ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _dots),
          ),
        ),
        build: (context) => [_top(sheet, logo), for (final block in sheet.blocks) render.block(block)],
      ),
    );
    return doc.save();
  }

  /// Every formula of the sheet drawn once, by its text, colour and size; one that cannot be drawn is printed as typed.
  Future<Map<String, FormulaImage>> _formulaImages(Worksheet sheet) async {
    final out = <String, FormulaImage>{};
    Future<void> add(Iterable<SheetSpan> spans, double size) async {
      for (final span in spans.whereType<SheetFormula>()) {
        final key = _Renderer.key(span.source, span.answer, size);
        if (out.containsKey(key) || span.source.trim().isEmpty) continue;
        try {
          out[key] = await _formulas(span.source, answer: span.answer, size: size);
        } on Object {
          // Printed as typed.
        }
      }
    }

    for (final block in sheet.blocks) {
      switch (block) {
        case SheetLine(:final spans, :final heading):
          await add(spans, _Renderer.headingSize(heading));
        case SheetQuestion(:final spans):
          await add(spans, _size);
        case SheetChoices(:final choices):
          for (final (text, right) in choices) {
            await add(formulaSpans(text, answer: right), _size + 1);
          }
        case SheetTable(:final rows):
          for (final cell in rows.expand((row) => row)) {
            await add(formulaSpans(cell), _size - 1);
          }
        case SheetPicture() || SheetLines() || SheetRule() || SheetPageBreak():
          break;
      }
    }
    return out;
  }

  /// The pictures of the sheet, fetched once; one that cannot be fetched leaves an empty frame.
  Future<Map<String, Uint8List>> _pictures(Worksheet sheet) async {
    final out = <String, Uint8List>{};
    for (final url in sheet.blocks.whereType<SheetPicture>().map((p) => p.url).nonNulls.toSet()) {
      try {
        final response = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
        if (response.data != null) out[url] = Uint8List.fromList(response.data!);
      } on Object {
        // An empty frame.
      }
    }
    return out;
  }

  pw.Widget _top(Worksheet sheet, pw.ImageProvider logo) {
    final side = [?sheet.teacherName, ?sheet.date];
    final label = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _indigo, width: 2)),
          ),
          child: pw.Row(
            children: [
              pw.Image(logo, height: 22),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      sheet.title,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _ink),
                    ),
                    if (sheet.place != null)
                      pw.Text(
                        sheet.place!,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 9, color: _slate),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [for (final s in side) pw.Text(s, style: const pw.TextStyle(fontSize: 9, color: _slate))],
              ),
            ],
          ),
        ),
        if (sheet.nameLine)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('${sheet.nameLabel} ', style: label),
                pw.Expanded(child: _dotted(12)),
                if (sheet.mark != null) ...[
                  pw.SizedBox(width: 16),
                  pw.Text('${sheet.markLabel} ', style: label),
                  pw.SizedBox(width: 40, child: _dotted(12)),
                  pw.Text(' ${sheet.mark}', style: label),
                ],
              ],
            ),
          ),
        pw.SizedBox(height: 10),
      ],
    );
  }
}

pw.Widget _dotted(double height) => pw.Container(
  height: height,
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(color: _dots, style: pw.BorderStyle.dotted),
    ),
  ),
);

class _Renderer {
  _Renderer(this.formulas, this.pictures, this.arabicTheme);

  final Map<String, FormulaImage> formulas;
  final Map<String, Uint8List> pictures;

  /// A line written from the right is set in the Arabic font first, so its letters join (a French sheet too).
  final pw.ThemeData arabicTheme;

  static String key(String source, bool answer, double size) => '$answer|$size|$source';

  static double headingSize(int? heading) => switch (heading) {
    1 => 17,
    2 => 14.5,
    3 => 12.5,
    _ => _size,
  };

  pw.InlineSpan span(SheetSpan s, double size) => switch (s) {
    SheetText() => pw.TextSpan(
      text: s.text,
      style: pw.TextStyle(
        fontSize: s.size ?? size,
        fontWeight: s.bold || s.answer ? pw.FontWeight.bold : null,
        fontStyle: s.italic ? pw.FontStyle.italic : null,
        decoration: s.underline ? pw.TextDecoration.underline : null,
        color: s.answer ? _green : (s.color == null ? _ink : PdfColor.fromHex(s.color!)),
      ),
    ),
    SheetFormula() => _formula(s, size),
    SheetGap(:final answer) =>
      answer == null
          ? pw.WidgetSpan(child: pw.SizedBox(width: 90, child: _dotted(size + 2)))
          : pw.TextSpan(
              text: ' $answer ',
              style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: _green, decoration: pw.TextDecoration.underline),
            ),
  };

  pw.InlineSpan _formula(SheetFormula f, double size) {
    final image = formulas[key(f.source, f.answer, size)];
    if (image == null) {
      return pw.TextSpan(
        text: f.source,
        style: pw.TextStyle(fontSize: size, color: f.answer ? _green : _ink),
      );
    }
    return pw.WidgetSpan(
      // A fraction sits on the line like the screen shows it: its bar near the text's middle.
      baseline: -(image.height - size) / 2,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 1),
        child: pw.Image(pw.MemoryImage(image.png), width: image.width, height: image.height),
      ),
    );
  }

  pw.Widget rich(List<SheetSpan> spans, double size, {pw.TextAlign? align, pw.TextDirection? direction}) => pw.RichText(
    textAlign: align,
    textDirection: direction,
    text: pw.TextSpan(children: [for (final s in spans) span(s, size)]),
  );

  /// A table cell: an Arabic one is written from the right, in the Arabic font.
  pw.Widget _cell(String cell) {
    final content = rich(formulaSpans(cell), _size - 1, direction: _arabicLetter.hasMatch(cell) ? pw.TextDirection.rtl : pw.TextDirection.ltr);
    return _arabicLetter.hasMatch(cell) ? pw.Theme(data: arabicTheme, child: content) : content;
  }

  pw.Widget block(SheetBlock b) => switch (b) {
    SheetLine() => _textLine(b),
    SheetQuestion() => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 16,
            child: pw.Text(
              '${b.number}.',
              style: pw.TextStyle(fontSize: _size, fontWeight: pw.FontWeight.bold, color: _indigo),
            ),
          ),
          pw.Expanded(
            child: b.rtl
                ? pw.Theme(
                    data: arabicTheme,
                    child: rich(b.spans, _size, align: pw.TextAlign.start, direction: pw.TextDirection.rtl),
                  )
                : rich(b.spans, _size, align: pw.TextAlign.start, direction: pw.TextDirection.ltr),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            b.points,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _slate),
          ),
        ],
      ),
    ),
    SheetChoices() => pw.Padding(
      padding: const pw.EdgeInsetsDirectional.only(start: 16, top: 2, bottom: 6),
      child: pw.Wrap(
        spacing: 22,
        runSpacing: 8,
        crossAxisAlignment: pw.WrapCrossAlignment.center,
        children: [
          for (final (text, right) in b.choices)
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (right)
                  pw.SvgImage(svg: _checked, width: 12, height: 12)
                else
                  pw.Container(
                    width: 11,
                    height: 11,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: _ink, width: 1.1),
                    ),
                  ),
                pw.SizedBox(width: 6),
                rich(formulaSpans(text, answer: right), _size + 1),
              ],
            ),
        ],
      ),
    ),
    // Tables and pictures keep the editor's layout, from the left, in an Arabic sheet too.
    SheetTable(:final rows) => pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.8),
          children: [
            for (var r = 0; r < rows.length; r++)
              pw.TableRow(
                decoration: r == 0 ? const pw.BoxDecoration(color: _header) : null,
                children: [
                  for (final cell in rows[r])
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      constraints: const pw.BoxConstraints(minHeight: 22),
                      child: _cell(cell),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
    SheetPicture(:final url, :final maxWidth) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Align(
          alignment: pw.AlignmentDirectional.centerStart,
          child: switch (pictures[url]) {
            final Uint8List bytes => pw.Image(pw.MemoryImage(bytes), width: maxWidth, fit: pw.BoxFit.contain),
            null => pw.Container(
              width: maxWidth ?? 150,
              height: 60,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
            ),
          },
        ),
      ),
    ),
    SheetLines(:final count, :final indent) => pw.Padding(
      padding: pw.EdgeInsetsDirectional.only(start: indent, top: 2, bottom: 4),
      child: pw.Column(children: [for (var i = 0; i < count; i++) _dotted(20)]),
    ),
    SheetRule() => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Divider(color: _line, thickness: 0.6, height: 1),
    ),
    SheetPageBreak() => pw.NewPage(),
  };

  pw.Widget _textLine(SheetLine l) {
    final size = headingSize(l.heading);
    final spans = l.heading == null
        ? l.spans
        : [
            for (final s in l.spans)
              if (s is SheetText)
                SheetText(s.text, bold: true, italic: s.italic, underline: s.underline, color: s.color, size: size, answer: s.answer)
              else
                s,
          ];
    // A page keeps its own directions, like the editor: a line written in Arabic says so, whoever prints it.
    final direction = l.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final line = pw.Directionality(
      textDirection: direction,
      child: pw.Padding(
        padding: pw.EdgeInsetsDirectional.only(start: l.indent, top: l.heading == null ? 1.5 : 7, bottom: l.heading == null ? 1.5 : 3),
        child: l.spans.isEmpty
            ? pw.SizedBox(height: size)
            : pw.SizedBox(
                width: double.infinity,
                child: rich(
                  [if (l.bullet != null) SheetText('${l.bullet}  '), ...spans],
                  size,
                  align: l.center ? pw.TextAlign.center : (l.end ? pw.TextAlign.end : pw.TextAlign.start),
                  direction: direction,
                ),
              ),
      ),
    );
    return l.rtl ? pw.Theme(data: arabicTheme, child: line) : line;
  }
}
