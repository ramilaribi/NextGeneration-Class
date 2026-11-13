import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/math/formula.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/brand_colors.dart';
import '../../l10n/app_localizations.dart';

/// The embeds of a page written in the app (release 3), as its Delta keeps them.
abstract final class PageEmbeds {
  /// Inline: what the teacher typed, "3/4 + 1/2" ([formulaTex] reads it).
  static const formula = 'formula';

  /// {"rows": [["Fraction", "$3/5$"], ["", ""]]}: the first row is the header.
  static const table = 'table';

  /// {"id": "(file id)", "size": "small", "medium" or "full"}.
  static const picture = 'picture';

  /// {"count": 2}: dotted lines for the pupil's answer.
  static const lines = 'lines';
}

enum PictureSize {
  small(200),
  medium(340),
  full(double.infinity);

  const PictureSize(this.maxWidth);

  final double maxWidth;
}

class PictureData {
  const PictureData({required this.id, this.size = PictureSize.medium});

  factory PictureData.from(Object? data) {
    final map = data is Map ? data : const {};
    return PictureData(
      id: '${map['id'] ?? ''}',
      size: PictureSize.values.where((s) => s.name == map['size']).firstOrNull ?? PictureSize.medium,
    );
  }

  final String id;
  final PictureSize size;

  Map<String, dynamic> toJson() => {'id': id, 'size': size.name};
}

class TableData {
  const TableData(this.rows);

  /// A new table: a header and two empty rows, three columns.
  static const blank = TableData([
    ['', '', ''],
    ['', '', ''],
    ['', '', ''],
  ]);

  factory TableData.from(Object? data) {
    final rows = data is Map ? data['rows'] : null;
    if (rows is! List || rows.isEmpty) return blank;
    final read = [
      for (final row in rows) [for (final cell in row is List ? row : const []) '${cell ?? ''}'],
    ];
    final columns = read.fold<int>(1, (most, row) => row.length > most ? row.length : most);
    return TableData([for (final row in read) List.generate(columns, (i) => i < row.length ? row[i] : '')]);
  }

  final List<List<String>> rows;

  int get columns => rows.isEmpty ? 0 : rows.first.length;

  Map<String, dynamic> toJson() => {'rows': rows};
}

int linesCountOf(Object? data) {
  final count = data is Map ? data['count'] : null;
  return count is num ? count.toInt().clamp(1, 12) : 2;
}

/// The page's text: the brand font for Latin, its Arabic sister for Arabic, the same for every reader.
TextStyle pageTextStyle(BuildContext context) {
  final text = AppText.of(context);
  final style = text.inScript(const TextStyle(fontSize: 16, height: 1.55, color: BrandColors.ink), arabic: false);
  final arabic = Theme.of(context).extension<AppFonts>() == null ? null : GoogleFonts.ibmPlexSansArabic().fontFamily;
  return arabic == null ? style : style.copyWith(fontFamilyFallback: [arabic]);
}

/// Titles in the brand's indigo, a calm line height for primary pupils.
DefaultStyles pageStyles(TextStyle base) {
  DefaultTextBlockStyle block(TextStyle style, double top, double bottom) =>
      DefaultTextBlockStyle(style, HorizontalSpacing.zero, VerticalSpacing(top, bottom), VerticalSpacing.zero, null);
  return DefaultStyles(
    h1: block(base.copyWith(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25, color: BrandColors.indigo), 14, 4),
    h2: block(base.copyWith(fontSize: 19, fontWeight: FontWeight.w800, height: 1.3, color: BrandColors.indigo), 12, 2),
    h3: block(base.copyWith(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4), 8, 0),
    paragraph: block(base, 2, 2),
    placeHolder: block(base.copyWith(color: BrandColors.slate), 2, 2),
  );
}

/// A formula as written: drawn, or as typed when it cannot be read yet.
class FormulaView extends StatelessWidget {
  const FormulaView({super.key, required this.source, required this.style});

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tex = tryFormulaTex(source);
    final fallback = Text(source, style: style, textDirection: TextDirection.ltr);
    if (tex == null || tex.isEmpty) return fallback;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Math.tex(tex, textStyle: style, mathStyle: MathStyle.text, onErrorFallback: (_) => fallback),
    );
  }
}

/// Text with formulas between two $: "Plus grande que $1/2$ ?".
class TextWithFormulas extends StatelessWidget {
  const TextWithFormulas(this.text, {super.key, required this.style, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final parts = text.split(r'$');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            if (i.isOdd && i < parts.length - 1)
              WidgetSpan(alignment: PlaceholderAlignment.middle, child: FormulaView(source: parts[i], style: style))
            else if (parts[i].isNotEmpty)
              TextSpan(text: i.isOdd ? '\$${parts[i]}' : parts[i]),
        ],
      ),
      style: style,
      textAlign: textAlign,
    );
  }
}

/// A table of the page: the first row is the header; wider than the page, it scrolls sideways.
class PageTableView extends StatelessWidget {
  const PageTableView({super.key, required this.data, required this.style});

  final TableData data;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    const border = BorderSide(color: Color(0xFFB8BCD3));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: const TableBorder(
          top: border,
          bottom: border,
          left: border,
          right: border,
          horizontalInside: border,
          verticalInside: border,
        ),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var r = 0; r < data.rows.length; r++)
            TableRow(
              decoration: r == 0 ? const BoxDecoration(color: Color(0xFFF1F3FA)) : null,
              children: [
                for (final cell in data.rows[r])
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 64, minHeight: 40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: TextWithFormulas(
                        cell,
                        textAlign: TextAlign.center,
                        style: r == 0 ? style.copyWith(fontWeight: FontWeight.w700, fontSize: 15) : style.copyWith(fontSize: 15),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Dotted lines to write the answer on.
class AnswerLinesView extends StatelessWidget {
  const AnswerLinesView({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: [for (var i = 0; i < count; i++) const SizedBox(height: 30, width: double.infinity, child: CustomPaint(painter: _DottedLine()))],
  );
}

class _DottedLine extends CustomPainter {
  const _DottedLine();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFADB1C6)
      ..strokeWidth = 1;
    final y = size.height - 2;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(x + 2, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLine oldDelegate) => false;
}

/// A picture of the page, or a quiet box when its link is missing or broken.
class PagePictureView extends StatelessWidget {
  const PagePictureView({super.key, required this.url, required this.size});

  final String? url;
  final PictureSize size;

  @override
  Widget build(BuildContext context) {
    final missing = Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.imageOff, size: 18, color: BrandColors.slate),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context).pictureMissing, style: AppText.of(context).small),
        ],
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.maxWidth),
        child: url == null
            ? missing
            : ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.badge),
                child: Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, _, _) => missing),
              ),
      ),
    );
  }
}

/// What a tap on an embed does in the editor (null while reading).
typedef PageEmbedTap = void Function(EmbedContext embed);

/// The editor's builders for the four embeds. [pictureUrls] by picture id.
List<EmbedBuilder> pageEmbedBuilders({required Map<String, String> pictureUrls, PageEmbedTap? onTap}) => [
  _PageEmbedBuilder(PageEmbeds.formula, inline: true, onTap: onTap, (context, embed) {
    // Room above and below: two lines of fractions never touch.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      child: FormulaView(source: '${embed.node.value.data ?? ''}', style: embed.textStyle),
    );
  }),
  _PageEmbedBuilder(PageEmbeds.table, onTap: onTap, (context, embed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PageTableView(data: TableData.from(embed.node.value.data), style: pageTextStyle(context)),
    );
  }),
  _PageEmbedBuilder(PageEmbeds.picture, onTap: onTap, (context, embed) {
    final picture = PictureData.from(embed.node.value.data);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PagePictureView(url: pictureUrls[picture.id], size: picture.size),
    );
  }),
  _PageEmbedBuilder(PageEmbeds.lines, onTap: onTap, (context, embed) => AnswerLinesView(count: linesCountOf(embed.node.value.data))),
];

class _PageEmbedBuilder extends EmbedBuilder {
  const _PageEmbedBuilder(this.key, this._build, {this.inline = false, this.onTap});

  @override
  final String key;
  final bool inline;
  final PageEmbedTap? onTap;
  final Widget Function(BuildContext context, EmbedContext embed) _build;

  @override
  bool get expanded => !inline;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final child = _build(context, embedContext);
    final tap = onTap;
    if (tap == null || embedContext.readOnly) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => tap(embedContext), child: child),
    );
  }
}

/// Reads Delta operations into a document; anything unreadable gives an empty page rather than a crash.
Document pageDocument(List<Map<String, dynamic>> body) {
  try {
    final document = Document.fromJson(body);
    return document;
  } on Object {
    return Document();
  }
}

/// A page written in the app as pupils and parents read it, and the teacher's "Aperçu élève". It grows
/// with its text: put it in a scroll view.
class WrittenPageView extends StatefulWidget {
  const WrittenPageView({super.key, required this.body, this.pictureUrls = const {}, this.extraBuilders = const [], this.style});

  final List<Map<String, dynamic>> body;
  final Map<String, String> pictureUrls;

  /// Embeds of their own (a quiz question's gaps).
  final List<EmbedBuilder> extraBuilders;

  /// The text's style; the page's otherwise.
  final TextStyle? style;

  @override
  State<WrittenPageView> createState() => _WrittenPageViewState();
}

class _WrittenPageViewState extends State<WrittenPageView> {
  late QuillController _controller = _controllerFor(widget.body);
  final _focus = FocusNode(canRequestFocus: false);
  final _scroll = ScrollController();

  static QuillController _controllerFor(List<Map<String, dynamic>> body) =>
      QuillController(document: pageDocument(body), selection: const TextSelection.collapsed(offset: 0), readOnly: true);

  @override
  void didUpdateWidget(WrittenPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.body, widget.body)) {
      _controller.dispose();
      _controller = _controllerFor(widget.body);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? pageTextStyle(context);
    // The page keeps its own directions (an Arabic line says so), whatever the reader's language.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: base,
        child: QuillEditor(
          controller: _controller,
          focusNode: _focus,
          scrollController: _scroll,
          config: QuillEditorConfig(
            scrollable: false,
            showCursor: false,
            enableInteractiveSelection: false,
            padding: EdgeInsets.zero,
            customStyles: pageStyles(base),
            embedBuilders: [...pageEmbedBuilders(pictureUrls: widget.pictureUrls), ...widget.extraBuilders],
          ),
        ),
      ),
    );
  }
}
