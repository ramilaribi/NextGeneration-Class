import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/formatting.dart';
import '../../core/l10n/tunis_time.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/brand_colors.dart';
import '../../domain/model/results.dart';
import '../../l10n/app_localizations.dart';
import 'buttons.dart';
import 'cards.dart';
import 'controls.dart';
import 'panels.dart';

const _grid = Color(0xFFEEF0F5);
const _axis = Color(0xFFC9CCDA);
const _homework = BrandColors.indigo;
const _attendance = Color(0xFF12A39A);

/// Each subject keeps its own colour and gets its own marker shape: told apart without the colours too.
enum _Marker { circle, square, diamond, triangle }

_Marker _markerOf(int index) => _Marker.values[index % _Marker.values.length];

/// The school year a chart covers: September to June, from the first month the server sent.
DateTime _yearStart(MyResults results, DateTime now) {
  final first = results.months.firstOrNull?.month;
  if (first != null) return first;
  final day = TunisTime.day(now);
  return DateTime.utc(day.month >= 9 ? day.year : day.year - 1, 9);
}

/// Every month name when they fit their slots, else one in two or three (long Arabic names on a phone).
int _labelStep(List<String> labels, double slot, TextStyle style) {
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(text: TextSpan(text: label, style: style), textDirection: TextDirection.ltr)..layout();
    widest = math.max(widest, painter.width);
  }
  return math.max(1, ((widest + 6) / slot).ceil());
}

/// A line of the grades chart: one subject's counted grades on /20, oldest first.
class _Line {
  const _Line(this.result, this.color, this.marker, this.grades);

  final SubjectResult result;
  final Color color;
  final _Marker marker;
  final List<GradeItem> grades;
}

List<_Line> _lines(MyResults results) => [
  for (final (i, s) in results.subjects.indexed)
    if (s.grades.any((g) => g.counted))
      _Line(s, colorFromHex(s.subject.color), _markerOf(i), s.grades.where((g) => g.counted).toList().reversed.toList()),
];

/// "Les notes au fil de l'année" (Release 4, designs `r4/Progression.png`, `r4/ProgressionPhone.png`): one line per
/// subject, each point a grade on /20, September to June. A point shows its grade when touched or hovered.
class GradesChartCard extends StatelessWidget {
  const GradesChartCard({super.key, required this.results, required this.now, required this.onTable});

  final MyResults results;
  final DateTime now;
  final VoidCallback onTable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final lines = _lines(results);
    final count = lines.fold(0, (sum, l) => sum + l.grades.length);
    final legend = Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final line in lines) _LegendKey(color: line.color, marker: line.marker, label: line.result.subject.name.of(_languageOf(context))),
      ],
    );
    return SectionCard(
      title: l10n.chartGradesTitle,
      trailing: Tooltip(
        message: l10n.showAsTable,
        child: IconButton(
          key: const Key('grades-table'),
          onPressed: onTable,
          icon: const Icon(LucideIcons.table, size: 20, color: BrandColors.indigo),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(count < 2 ? l10n.chartOneGrade : l10n.chartGradesHint, style: text.style(13, FontWeight.w500, color: BrandColors.slate)),
          if (count >= 2) ...[
            const SizedBox(height: 12),
            legend,
            const SizedBox(height: 12),
            _GradesChart(lines: lines, start: _yearStart(results, now)),
          ],
        ],
      ),
    );
  }
}

AppLanguage _languageOf(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar' ? AppLanguage.ar : AppLanguage.fr;

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.color, required this.label, this.marker, this.bar = false});

  final Color color;
  final String label;
  final _Marker? marker;
  final bool bar;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (bar)
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        )
      else
        SizedBox(width: 22, height: 12, child: CustomPaint(painter: _KeyPainter(color, marker!))),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.of(context).style(13, FontWeight.w600, color: BrandColors.body)),
      ),
    ],
  );
}

class _KeyPainter extends CustomPainter {
  const _KeyPainter(this.color, this.marker);

  final Color color;
  final _Marker marker;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
    _drawMarker(canvas, Offset(size.width / 2, y), marker, color, 4);
  }

  @override
  bool shouldRepaint(_KeyPainter old) => old.color != color || old.marker != marker;
}

void _drawMarker(Canvas canvas, Offset c, _Marker marker, Color color, double r) {
  final fill = Paint()..color = color;
  final ring = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Path path;
  switch (marker) {
    case _Marker.circle:
      canvas
        ..drawCircle(c, r + 1, ring)
        ..drawCircle(c, r, fill);
      return;
    case _Marker.square:
      path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 2 * r, height: 2 * r), const Radius.circular(1.5)));
    case _Marker.diamond:
      final d = r * 1.35;
      path = Path()
        ..moveTo(c.dx, c.dy - d)
        ..lineTo(c.dx + d, c.dy)
        ..lineTo(c.dx, c.dy + d)
        ..lineTo(c.dx - d, c.dy)
        ..close();
    case _Marker.triangle:
      final d = r * 1.3;
      path = Path()
        ..moveTo(c.dx, c.dy - d)
        ..lineTo(c.dx + d, c.dy + d * 0.8)
        ..lineTo(c.dx - d, c.dy + d * 0.8)
        ..close();
  }
  canvas
    ..drawPath(path, ring)
    ..drawPath(path, fill);
}

/// A point of the chart, where it is drawn and what it is.
class _Point {
  const _Point(this.offset, this.line, this.grade);

  final Offset offset;
  final _Line line;
  final GradeItem grade;
}

class _GradesChart extends StatefulWidget {
  const _GradesChart({required this.lines, required this.start});

  final List<_Line> lines;
  final DateTime start;

  @override
  State<_GradesChart> createState() => _GradesChartState();
}

class _GradesChartState extends State<_GradesChart> {
  _Point? _selected;

  static const _months = 10;

  /// The pick nearest to [position], within a finger's reach.
  _Point? _nearest(List<_Point> points, Offset position) {
    _Point? best;
    var distance = 28.0;
    for (final p in points) {
      final d = (p.offset - position).distance;
      if (d < distance) {
        distance = d;
        best = p;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final language = _languageOf(context);
    final text = AppText.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 560;
        final height = wide ? 260.0 : 200.0;
        final layout = _ChartLayout(width: width, height: height, rtl: rtl, endRoom: wide ? 80 : 8);
        double xOf(DateTime date) {
          final months = (date.year - widget.start.year) * 12 + date.month - widget.start.month;
          final day = TunisTime.day(date);
          final days = DateUtils.getDaysInMonth(day.year, day.month);
          return layout.x((months + (day.day - 1) / days) / _months);
        }

        final points = [
          for (final line in widget.lines)
            for (final g in line.grades) _Point(Offset(xOf(g.date), layout.y(g.score20! / 20)), line, g),
        ];
        final labels = [for (var i = 0; i < _months; i++) monthShort(DateTime.utc(widget.start.year, widget.start.month + i), language)];
        final selected = _selected;
        return Semantics(
          label: AppLocalizations.of(context).chartGradesTitle,
          child: MouseRegion(
            onHover: (e) => setState(() => _selected = _nearest(points, e.localPosition)),
            onExit: (_) => setState(() => _selected = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => setState(() => _selected = _nearest(points, d.localPosition)),
              child: SizedBox(
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GradesPainter(
                          layout: layout,
                          lines: widget.lines,
                          points: points,
                          months: labels,
                          selected: selected,
                          endLabels: wide,
                          textStyle: text.style(11, FontWeight.w500, color: BrandColors.slate),
                          labelStyle: text.style(12, FontWeight.w700),
                          shortName: (line) => line.result.subject.name.of(language),
                        ),
                      ),
                    ),
                    if (selected != null) _Tooltip(point: selected, layout: layout, language: language),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Where the plot sits inside the chart: room for the axis on the start side, the months below, labels at the end.
class _ChartLayout {
  _ChartLayout({required this.width, required this.height, required this.rtl, this.startRoom = 30, this.endRoom = 8});

  final double width;
  final double height;
  final bool rtl;
  final double startRoom;
  final double endRoom;
  static const top = 8.0;
  static const bottom = 24.0;

  double get plotWidth => width - startRoom - endRoom;
  double get plotHeight => height - top - bottom;

  /// [t] from 0 (September) to 1 (end of June), mirrored in Arabic.
  double x(double t) => rtl ? width - startRoom - t * plotWidth : startRoom + t * plotWidth;

  /// [v] from 0 to 1, bottom to top.
  double y(double v) => top + plotHeight * (1 - v);
}

class _GradesPainter extends CustomPainter {
  _GradesPainter({
    required this.layout,
    required this.lines,
    required this.points,
    required this.months,
    required this.selected,
    required this.endLabels,
    required this.textStyle,
    required this.labelStyle,
    required this.shortName,
  });

  final _ChartLayout layout;
  final List<_Line> lines;
  final List<_Point> points;
  final List<String> months;
  final _Point? selected;
  final bool endLabels;
  final TextStyle textStyle;
  final TextStyle labelStyle;
  final String Function(_Line) shortName;

  void _text(Canvas canvas, String value, Offset at, TextStyle style, {TextAlign align = TextAlign.center, bool ltr = false}) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: ltr || !layout.rtl ? TextDirection.ltr : TextDirection.rtl,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => at.dx - painter.width / 2,
      TextAlign.right => at.dx - painter.width,
      _ => at.dx,
    };
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    final startX = l.x(0);
    final endX = l.x(1);
    for (final v in [0, 5, 10, 15, 20]) {
      final y = l.y(v / 20);
      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        Paint()
          ..color = v == 0 ? _axis : _grid
          ..strokeWidth = 1,
      );
      _text(canvas, '$v', Offset(l.rtl ? startX + 6 : startX - 6, y), textStyle, align: l.rtl ? TextAlign.left : TextAlign.right, ltr: true);
    }
    final step = _labelStep(months, l.plotWidth / months.length, textStyle);
    for (var i = 0; i < months.length; i += step) {
      _text(canvas, months[i], Offset(l.x((i + 0.5) / months.length), l.height - 10), textStyle);
    }
    final bySubject = <_Line, List<_Point>>{};
    for (final p in points) {
      bySubject.putIfAbsent(p.line, () => []).add(p);
    }
    bySubject.forEach((line, pts) {
      final path = Path()..moveTo(pts.first.offset.dx, pts.first.offset.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.offset.dx, p.offset.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      for (final p in pts) {
        _drawMarker(canvas, p.offset, line.marker, line.color, 4);
      }
    });
    if (endLabels) {
      // Each line's name and last grade at its end, pushed apart so they never touch.
      final ends = [for (final e in bySubject.entries) (e.value.last, shortName(e.key))]..sort((a, b) => a.$1.offset.dy.compareTo(b.$1.offset.dy));
      final farthest = bySubject.values.map((p) => p.last.offset.dx).reduce(l.rtl ? math.min : math.max);
      var last = -100.0;
      for (final (p, name) in ends) {
        final y = math.max(p.offset.dy, last + 15);
        last = y;
        final x = farthest + (l.rtl ? -12 : 12);
        canvas.drawLine(
          p.offset,
          Offset(x + (l.rtl ? 4 : -4), y),
          Paint()
            ..color = _axis
            ..strokeWidth = 1,
        );
        _text(canvas, '$name ${scoreText(p.grade.score20!)}', Offset(x, y), labelStyle, align: l.rtl ? TextAlign.right : TextAlign.left);
      }
    }
    final s = selected;
    if (s != null) {
      final dash = Paint()
        ..color = _axis
        ..strokeWidth = 1;
      for (var y = _ChartLayout.top; y < l.y(0); y += 6) {
        canvas.drawLine(Offset(s.offset.dx, y), Offset(s.offset.dx, math.min(y + 3, l.y(0))), dash);
      }
      canvas.drawCircle(
        s.offset,
        7,
        Paint()
          ..color = s.line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_GradesPainter old) => old.selected != selected || old.points != points || old.layout.width != layout.width;
}

/// The grade under the finger: its subject, its work and the date.
class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.point, required this.layout, required this.language});

  final _Point point;
  final _ChartLayout layout;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    const width = 210.0;
    final g = point.grade;
    // Beside the point, on the side with room; under the lines when it would leave the chart.
    final left = (point.offset.dx + 12 + width > layout.width ? point.offset.dx - 12 - width : point.offset.dx + 12)
        .clamp(0.0, math.max(0.0, layout.width - width))
        .toDouble();
    final top = (point.offset.dy - 30).clamp(0.0, math.max(0.0, layout.height - 90)).toDouble();
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: IgnorePointer(
        child: Container(
          key: const Key('grade-tooltip'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BrandColors.line),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x241C2566), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: _LegendKey(color: point.line.color, marker: point.line.marker, label: point.line.result.subject.name.of(language)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(g.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.style(14, FontWeight.w700)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${scoreText(g.score!)}/${g.maxScore}', textDirection: TextDirection.ltr, style: text.style(18, FontWeight.w800)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dayInSentence(TunisTime.day(g.date), language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.style(12, FontWeight.w500, color: BrandColors.slate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Chaque mois" (Release 4): homework sent and attendance per month, in %, all subjects. One value is written:
/// the lowest under 80 %, the one that asks for a look.
class MonthlyChartCard extends StatelessWidget {
  const MonthlyChartCard({super.key, required this.months});

  final List<MonthProgress> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = _languageOf(context);
    final empty = months.every((m) => m.homeworkRate == null && m.attendanceRate == null);
    return SectionCard(
      title: l10n.chartMonthlyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(empty ? l10n.monthNoData : l10n.chartMonthlyHint, style: text.style(13, FontWeight.w500, color: BrandColors.slate)),
          if (!empty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendKey(color: _homework, label: l10n.chartHomework, bar: true),
                _LegendKey(color: _attendance, label: l10n.chartAttendance, bar: true),
              ],
            ),
            const SizedBox(height: 12),
            _MonthlyChart(months: months, language: language),
          ],
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatefulWidget {
  const _MonthlyChart({required this.months, required this.language});

  final List<MonthProgress> months;
  final AppLanguage language;

  @override
  State<_MonthlyChart> createState() => _MonthlyChartState();
}

class _MonthlyChartState extends State<_MonthlyChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _ChartLayout(width: constraints.maxWidth, height: 180, rtl: rtl, startRoom: 40);
        final n = widget.months.length;
        int? monthAt(Offset p) {
          final t = rtl ? (layout.width - layout.startRoom - p.dx) / layout.plotWidth : (p.dx - layout.startRoom) / layout.plotWidth;
          final i = (t * n).floor();
          return i >= 0 && i < n ? i : null;
        }

        final selected = _selected;
        final m = selected == null ? null : widget.months[selected];
        return Semantics(
          label: l10n.chartMonthlyTitle,
          child: MouseRegion(
            onHover: (e) => setState(() => _selected = monthAt(e.localPosition)),
            onExit: (_) => setState(() => _selected = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => setState(() => _selected = monthAt(d.localPosition)),
              child: SizedBox(
                height: layout.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MonthlyPainter(
                          layout: layout,
                          months: widget.months,
                          labels: [for (final m in widget.months) monthShort(m.month, widget.language)],
                          selected: selected,
                          textStyle: text.style(11, FontWeight.w500, color: BrandColors.slate),
                          valueStyle: text.style(11, FontWeight.w700),
                        ),
                      ),
                    ),
                    if (m != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              key: const Key('month-tooltip'),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: BrandColors.line),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Color(0x241C2566), blurRadius: 24, offset: Offset(0, 8))],
                              ),
                              child: Text(
                                [
                                  monthYear(m.month, widget.language),
                                  '${l10n.chartHomework} ${m.due == 0 ? l10n.noValue : l10n.countOf(m.submitted, m.due)}',
                                  '${l10n.chartAttendance} ${m.attendanceRate == null ? l10n.noValue : l10n.percentValue(m.attendanceRate!)}',
                                ].join(l10n.dotSeparator),
                                style: text.style(12.5, FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthlyPainter extends CustomPainter {
  _MonthlyPainter({
    required this.layout,
    required this.months,
    required this.labels,
    required this.selected,
    required this.textStyle,
    required this.valueStyle,
  });

  final _ChartLayout layout;
  final List<MonthProgress> months;
  final List<String> labels;
  final int? selected;
  final TextStyle textStyle;
  final TextStyle valueStyle;

  void _text(Canvas canvas, String value, Offset at, TextStyle style, {TextAlign align = TextAlign.center}) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => at.dx - painter.width / 2,
      TextAlign.right => at.dx - painter.width,
      _ => at.dx,
    };
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    final startX = l.x(0);
    final endX = l.x(1);
    for (final v in [0, 50, 100]) {
      final y = l.y(v / 100);
      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        Paint()
          ..color = v == 0 ? _axis : _grid
          ..strokeWidth = 1,
      );
      _text(canvas, '$v %', Offset(l.rtl ? startX + 6 : startX - 6, y), textStyle, align: l.rtl ? TextAlign.left : TextAlign.right);
    }
    final n = months.length;
    if (n == 0) return;
    final slot = l.plotWidth / n;
    final bar = math.min(16.0, math.max(4.0, (slot - 10) / 2));
    final step = _labelStep(labels, slot, textStyle);
    // The one value written: the lowest under 80 %.
    (int, int, int)? lowest;
    for (var i = 0; i < n; i++) {
      final m = months[i];
      final center = l.x((i + 0.5) / n);
      if (selected == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center, l.y(0.5)), width: slot - 4, height: l.plotHeight + 8),
            const Radius.circular(8),
          ),
          Paint()..color = const Color(0xFFF1F2F8),
        );
      }
      final values = [(m.homeworkRate, _homework), (m.attendanceRate, _attendance)];
      for (var k = 0; k < 2; k++) {
        final (value, color) = values[k];
        if (value == null) continue;
        // The first bar on the reading start side, a 2 px gap between the pair.
        final first = (k == 0) != l.rtl;
        final left = first ? center - bar - 1 : center + 1;
        final top = l.y(value / 100);
        final rect = Rect.fromLTRB(left, top, left + bar, l.y(0));
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          Paint()..color = color,
        );
        if (value < 80 && (lowest == null || value < lowest.$3)) lowest = (i, k, value);
      }
      if (i % step == 0) _text(canvas, labels[i], Offset(center, l.height - 10), textStyle);
    }
    final low = lowest;
    if (low != null) {
      final center = l.x((low.$1 + 0.5) / n);
      final first = (low.$2 == 0) != l.rtl;
      _text(canvas, '${low.$3} %', Offset(first ? center - bar / 2 - 1 : center + bar / 2 + 1, l.y(low.$3 / 100) - 9), valueStyle);
    }
  }

  @override
  bool shouldRepaint(_MonthlyPainter old) => old.selected != selected || old.months != months || old.layout.width != layout.width;
}

/// "Voir en tableau": the same numbers as the charts, to read one by one.
class GradesTablePanel extends StatefulWidget {
  const GradesTablePanel({super.key, required this.results});

  final MyResults results;

  static Future<void> open(BuildContext context, MyResults results) =>
      showSidePanel<void>(context, builder: (_) => GradesTablePanel(results: results));

  @override
  State<GradesTablePanel> createState() => _GradesTablePanelState();
}

class _GradesTablePanelState extends State<GradesTablePanel> {
  bool _months = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = _languageOf(context);
    final quiet = text.style(12.5, FontWeight.w500, color: BrandColors.slate);
    final subjectOf = {
      for (final s in widget.results.subjects)
        for (final g in s.grades) g: s.subject.name.of(language),
    };
    final grades = widget.results.grades.where((g) => g.counted).toList();
    Widget row(String title, String subtitle, String value) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF0F1F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.style(14, FontWeight.w700)),
                Text(subtitle, style: quiet),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(value, textDirection: TextDirection.ltr, style: text.style(15, FontWeight.w800)),
        ],
      ),
    );
    return SidePanel(
      icon: LucideIcons.table,
      title: l10n.gradesTableTitle,
      subtitle: l10n.tableSameNumbers,
      actions: [PrimaryButton(label: l10n.close, height: 44, onPressed: () => Navigator.of(context).pop())],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PillTabs<bool>(
              items: [TabItem(false, l10n.tableGrades), TabItem(true, l10n.tableMonths)],
              value: _months,
              onChanged: (v) => setState(() => _months = v),
            ),
          ),
          const SizedBox(height: 12),
          if (!_months)
            for (final g in grades)
              row(
                g.title,
                [subjectOf[g] ?? '', dayInSentence(TunisTime.day(g.date), language)].join(l10n.dotSeparator),
                '${scoreText(g.score!)}/${g.maxScore}',
              )
          else
            for (final m in widget.results.months.reversed)
              row(
                monthYear(m.month, language),
                '${l10n.chartHomework} ${m.due == 0 ? l10n.noValue : l10n.countOf(m.submitted, m.due)}',
                m.attendanceRate == null ? l10n.noValue : l10n.percentValue(m.attendanceRate!),
              ),
        ],
      ),
    );
  }
}
