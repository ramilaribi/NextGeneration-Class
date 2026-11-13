import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_text.dart';
import '../../core/theme/brand_colors.dart';
import '../../domain/model/worksheet.dart';
import '../../domain/services/worksheet_layout.dart';
import '../../l10n/app_localizations.dart';
import 'written_page.dart';

const _ink = Color(0xFF1A1D3A);
const _slate = Color(0xFF6B7090);
const _green = Color(0xFF237A35);
const _line = Color(0xFFDCDFEA);
const _dots = Color(0xFF9AA0B8);
const _size = 11.0;

/// A4 in points, as the PDF draws it: the preview is laid out at this size, then scaled to the room it has.
const _a4Width = 595.0;
const _a4Height = 842.0;
const _margin = 40.0;

/// The sheet on screen (designs `r3/Fiche.png`, `r3/FicheVersions.png`): the same blocks as the PDF, in the same
/// sizes, one white A4 sheet per printed part (a page's Corrigé starts its own).
class WorksheetPreview extends StatelessWidget {
  const WorksheetPreview({super.key, required this.sheet, required this.rtl});

  final Worksheet sheet;

  /// The teacher's language reads from the right: the header and the questions follow it.
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final parts = <List<SheetBlock>>[[]];
    for (final block in sheet.blocks) {
      if (block is SheetPageBreak) {
        parts.add([]);
      } else {
        parts.last.add(block);
      }
    }
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            _Sheet(sheet: sheet, blocks: parts[i], withHeader: i == 0),
          ],
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.sheet, required this.blocks, required this.withHeader});

  final Worksheet sheet;
  final List<SheetBlock> blocks;
  final bool withHeader;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : _a4Width;
      return Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [BoxShadow(color: Color(0x1F1C2566), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _a4Width, maxWidth: _a4Width, minHeight: _a4Height),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_margin, 36, _margin, 22),
              child: _Content(sheet: sheet, blocks: blocks, withHeader: withHeader),
            ),
          ),
        ),
      );
    },
  );
}

/// The app's font at a size and weight: on the web each weight is its own font, so it is picked here, never by
/// changing the weight of another style.
class _Pen {
  const _Pen(this.text);

  final AppText text;

  TextStyle call(double size, {FontWeight weight = FontWeight.w500, Color color = _ink}) => text.style(size, weight, color: color, height: 1.35);
}

class _Content extends StatelessWidget {
  const _Content({required this.sheet, required this.blocks, required this.withHeader});

  final Worksheet sheet;
  final List<SheetBlock> blocks;
  final bool withHeader;

  @override
  Widget build(BuildContext context) {
    final pen = _Pen(AppText.of(context));
    // The footer sits at the foot of the sheet; a long sheet grows instead (the PDF goes on to the next page).
    return DefaultTextStyle(
      style: pen(_size),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (withHeader) _Top(sheet: sheet, pen: pen),
                for (final block in blocks) _Block(block: block, pen: pen),
              ],
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: Center(
              child: Text(AppLocalizations.of(context).appTitle, style: pen(8, color: _dots)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Top extends StatelessWidget {
  const _Top({required this.sheet, required this.pen});

  final Worksheet sheet;
  final _Pen pen;

  @override
  Widget build(BuildContext context) {
    final label = pen(10, weight: FontWeight.w700);
    final quiet = pen(9, color: _slate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: BrandColors.indigo, width: 2)),
          ),
          child: Row(
            children: [
              Image.asset('assets/brand/symbol.png', height: 22, excludeFromSemantics: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      sheet.title,
                      textAlign: TextAlign.center,
                      style: pen(15, weight: FontWeight.w800),
                    ),
                    if (sheet.place != null) Text(sheet.place!, textAlign: TextAlign.center, style: quiet),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (sheet.teacherName != null) Text(sheet.teacherName!, style: quiet),
                  if (sheet.date != null) Text(sheet.date!, style: quiet),
                ],
              ),
            ],
          ),
        ),
        if (sheet.nameLine)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${sheet.nameLabel} ', style: label),
                const Expanded(child: _Dots(height: 12)),
                if (sheet.mark != null) ...[
                  const SizedBox(width: 16),
                  Text('${sheet.markLabel} ', style: label),
                  const SizedBox(width: 40, child: _Dots(height: 12)),
                  Text(' ${sheet.mark}', style: label),
                ],
              ],
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// A dotted line to write on.
class _Dots extends StatelessWidget {
  const _Dots({this.height = 18, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: width,
    child: const CustomPaint(painter: _DotsPainter()),
  );
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _dots
      ..strokeWidth = 0.8;
    for (var x = 0.0; x < size.width; x += 2.4) {
      canvas.drawLine(Offset(x, size.height - 0.5), Offset(x + 0.8, size.height - 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

double _headingSize(int? heading) => switch (heading) {
  1 => 17,
  2 => 14.5,
  3 => 12.5,
  _ => _size,
};

InlineSpan _span(SheetSpan s, _Pen pen, double size, FontWeight weight) => switch (s) {
  SheetText() => TextSpan(
    text: s.text,
    style: pen(
      s.size ?? size,
      weight: s.bold || s.answer ? FontWeight.w700 : weight,
      color: s.answer ? _green : (s.color == null ? _ink : _hex(s.color!)),
    ).copyWith(fontStyle: s.italic ? FontStyle.italic : null, decoration: s.underline ? TextDecoration.underline : null),
  ),
  SheetFormula() => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: FormulaView(
        source: s.source,
        style: pen(size, color: s.answer ? _green : _ink),
      ),
    ),
  ),
  SheetGap(:final answer) =>
    answer == null
        ? const WidgetSpan(child: _Dots(width: 90, height: 13))
        : TextSpan(
            text: ' $answer ',
            style: pen(size, weight: FontWeight.w700, color: _green).copyWith(decoration: TextDecoration.underline),
          ),
};

Color _hex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? _ink : Color(0xFF000000 | value);
}

Widget _rich(List<SheetSpan> spans, _Pen pen, double size, {FontWeight weight = FontWeight.w500, TextAlign? align, TextDirection? direction}) =>
    Text.rich(
      TextSpan(children: [for (final s in spans) _span(s, pen, size, weight)]),
      textAlign: align,
      textDirection: direction,
      style: pen(size, weight: weight),
    );

class _Block extends StatelessWidget {
  const _Block({required this.block, required this.pen});

  final SheetBlock block;
  final _Pen pen;

  @override
  Widget build(BuildContext context) => switch (block) {
    final SheetLine l => _textLine(l),
    final SheetQuestion q => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '${q.number}.',
              style: pen(_size, weight: FontWeight.w700, color: BrandColors.indigo),
            ),
          ),
          Expanded(
            child: _rich(q.spans, pen, _size, align: TextAlign.start, direction: q.rtl ? TextDirection.rtl : TextDirection.ltr),
          ),
          const SizedBox(width: 8),
          Text(
            q.points,
            style: pen(8.5, weight: FontWeight.w700, color: _slate),
          ),
        ],
      ),
    ),
    final SheetChoices c => Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, top: 2, bottom: 6),
      child: Wrap(
        spacing: 22,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (text, right) in c.choices)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (right)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _green),
                    child: const Icon(LucideIcons.check, size: 9, color: Colors.white),
                  )
                else
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _ink, width: 1.1),
                    ),
                  ),
                const SizedBox(width: 6),
                _rich(formulaSpans(text, answer: right), pen, _size + 1),
              ],
            ),
        ],
      ),
    ),
    // Tables and pictures keep the editor's layout, from the left, in an Arabic sheet too.
    final SheetTable t => Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Table(
          border: TableBorder.all(color: _line, width: 0.8),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var r = 0; r < t.rows.length; r++)
              TableRow(
                decoration: r == 0 ? const BoxDecoration(color: Color(0xFFEEF0FA)) : null,
                children: [
                  for (final cell in t.rows[r])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      constraints: const BoxConstraints(minHeight: 22),
                      child: _rich(formulaSpans(cell), pen, _size - 1),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
    final SheetPicture p => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: p.url == null
              ? _emptyPicture(p.maxWidth)
              : Image.network(p.url!, width: p.maxWidth, fit: BoxFit.contain, errorBuilder: (_, _, _) => _emptyPicture(p.maxWidth)),
        ),
      ),
    ),
    final SheetLines l => Padding(
      padding: EdgeInsetsDirectional.only(start: l.indent, top: 2, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < l.count; i++) const _Dots(height: 20)]),
    ),
    SheetRule() => const Padding(
      padding: EdgeInsets.only(top: 6),
      child: Divider(color: _line, thickness: 0.6, height: 1),
    ),
    SheetPageBreak() => const SizedBox.shrink(),
  };

  static Widget _emptyPicture(double? width) => Container(
    width: width ?? 150,
    height: 60,
    decoration: BoxDecoration(border: Border.all(color: _line)),
  );

  Widget _textLine(SheetLine l) {
    final size = _headingSize(l.heading);
    // A page keeps its own directions, like the editor: a line written in Arabic says so, whoever reads it.
    final direction = l.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: l.indent, top: l.heading == null ? 1.5 : 7, bottom: l.heading == null ? 1.5 : 3),
        child: l.spans.isEmpty
            ? SizedBox(height: size)
            : _rich(
                [if (l.bullet != null) SheetText('${l.bullet}  '), ...l.spans],
                pen,
                size,
                weight: l.heading == null ? FontWeight.w500 : FontWeight.w800,
                align: l.center ? TextAlign.center : (l.end ? TextAlign.end : TextAlign.start),
                direction: direction,
              ),
      ),
    );
  }
}
