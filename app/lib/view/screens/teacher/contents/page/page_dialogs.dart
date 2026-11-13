import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/math/formula.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/theme/brand_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../widgets/buttons.dart';
import '../../../../widgets/controls.dart';
import '../../../../widgets/panels.dart';
import '../../../../widgets/text_field.dart';
import '../../../../widgets/written_page.dart';

/// What a window about an embed decided: a new value, or [remove] the embed.
class EmbedEdit<T> {
  const EmbedEdit.value(T this.value) : remove = false;

  const EmbedEdit.remove() : value = null, remove = true;

  final T? value;
  final bool remove;
}

/// A template of the formula window: how its button looks, what it types, where the cursor goes.
class _Template {
  const _Template(this.tex, this.tooltip, this.snippet, this.cursor);

  final String tex;
  final String Function(AppLocalizations l10n) tooltip;
  final String snippet;
  final int cursor;
}

final _templates = [
  _Template(r'\frac{a}{b}', (l) => l.formulaFraction, '()/()', 1),
  _Template('x^{n}', (l) => l.formulaPower, '^()', 2),
  _Template('x_{1}', (l) => l.formulaIndex, '_()', 2),
  _Template(r'\sqrt{x}', (l) => l.formulaRoot, 'sqrt()', 5),
  _Template(r'\times', (l) => l.formulaTimes, ' * ', 3),
  _Template(r'\div', (l) => l.formulaDivide, ' : ', 3),
  _Template(r'\leq', (l) => l.formulaLessEq, ' <= ', 4),
  _Template(r'\geq', (l) => l.formulaGreaterEq, ' >= ', 4),
  _Template(r'\neq', (l) => l.formulaNotEqual, ' != ', 4),
  _Template(r'\pi', (l) => l.formulaPi, 'pi', 2),
  _Template(r'x^{\circ}', (l) => l.formulaDegree, '°', 1),
  _Template(r'\overrightarrow{AB}', (l) => l.formulaVector, 'vec()', 4),
  _Template(r'\widehat{ABC}', (l) => l.formulaAngle, 'angle()', 6),
];

/// "ƒx Formule" (design `r3/EditeurDocument.png`): the teacher types 3/4 + 1/2 or clicks a template, the
/// preview shows the real formula, Enter or "Insérer" puts it in the text. Null when closed.
Future<String?> showFormulaDialog(BuildContext context, {String initial = '', bool editing = false}) =>
    showAppDialog<String>(context, builder: (_) => _FormulaDialog(initial: initial, editing: editing));

class _FormulaDialog extends StatefulWidget {
  const _FormulaDialog({required this.initial, required this.editing});

  final String initial;
  final bool editing;

  @override
  State<_FormulaDialog> createState() => _FormulaDialogState();
}

class _FormulaDialogState extends State<_FormulaDialog> {
  late final _field = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// A template at the cursor, in place of the selection; a fraction takes the selection on top.
  void _insert(_Template template) {
    final value = _field.value;
    final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: value.text.length);
    final chosen = selection.textInside(value.text);
    final fraction = template.snippet == '()/()' && chosen.isNotEmpty;
    final snippet = fraction ? '($chosen)/()' : template.snippet;
    final cursor = fraction ? snippet.length - 1 : template.cursor;
    final text = value.text.replaceRange(selection.start, selection.end, snippet);
    _field.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: selection.start + cursor));
    _focus.requestFocus();
  }

  void _submit() {
    final source = _field.text.trim();
    if (source.isEmpty || tryFormulaTex(source) == null) return;
    Navigator.of(context).pop(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final source = _field.text.trim();
    final tex = source.isEmpty ? '' : tryFormulaTex(source);
    final style = text.style(20, FontWeight.w500);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: AppDialog(
        icon: LucideIcons.sigma,
        title: l10n.formulaTitle,
        subtitle: l10n.formulaEscape,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('formula-source'),
              controller: _field,
              focusNode: _focus,
              autofocus: true,
              textDirection: TextDirection.ltr,
              style: text.style(16, FontWeight.w500).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              onSubmitted: (_) => _submit(),
              decoration: appInputDecoration(context, hint: l10n.formulaHint, helper: l10n.formulaHelp),
            ),
            const SizedBox(height: 12),
            _Templates(
              children: [
                for (final template in _templates)
                  Tooltip(
                    message: template.tooltip(l10n),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.badge),
                        side: const BorderSide(color: BrandColors.line),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.badge),
                        onTap: () => _insert(template),
                        // Shrink-wrapped: a small square button, never a bar as wide as the window.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Center(
                              widthFactor: 1,
                              heightFactor: 1,
                              child: Math.tex(template.tex, textStyle: text.style(14, FontWeight.w500)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('formula-preview'),
              constraints: const BoxConstraints(minHeight: 64),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.md)),
              child: switch (tex) {
                '' => Text(l10n.formulaPreviewEmpty, style: text.small, textAlign: TextAlign.center),
                null => Text(l10n.formulaInvalid, style: text.style(13, FontWeight.w600, color: Accent.red.onSoft), textAlign: TextAlign.center),
                final tex => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Math.tex(tex, textStyle: style, onErrorFallback: (_) => Text(source, style: style)),
                  ),
                ),
              },
            ),
          ],
        ),
        actions: [
          GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(context).maybePop()),
          PrimaryButton(
            label: widget.editing ? l10n.validate : l10n.insert,
            height: 44,
            onPressed: tex == null || tex.isEmpty ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// The templates: wrapped on a computer, one row that scrolls sideways on a phone (the window stays short).
class _Templates extends StatelessWidget {
  const _Templates({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 420) return Wrap(spacing: 6, runSpacing: 6, children: children);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(width: 6), child]]),
      );
    },
  );
}

/// "Tableau": the table filled in a grid (an editor's embed cannot take the keyboard itself). The first
/// row is the header; a formula goes between two $.
Future<EmbedEdit<TableData>?> showTableDialog(BuildContext context, TableData data, {bool existing = false}) =>
    showAppDialog<EmbedEdit<TableData>>(context, builder: (_) => _TableDialog(data: data, existing: existing));

class _TableDialog extends StatefulWidget {
  const _TableDialog({required this.data, required this.existing});

  final TableData data;
  final bool existing;

  @override
  State<_TableDialog> createState() => _TableDialogState();
}

class _TableDialogState extends State<_TableDialog> {
  static const _maxRows = 30;
  static const _maxColumns = 10;

  late final List<List<TextEditingController>> _cells = [
    for (final row in widget.data.rows) [for (final cell in row) TextEditingController(text: cell)],
  ];

  int get _columns => _cells.first.length;

  @override
  void dispose() {
    for (final row in _cells) {
      for (final cell in row) {
        cell.dispose();
      }
    }
    super.dispose();
  }

  void _addRow() => setState(() => _cells.add([for (var i = 0; i < _columns; i++) TextEditingController()]));

  void _addColumn() => setState(() {
    for (final row in _cells) {
      row.add(TextEditingController());
    }
  });

  void _removeRow() => setState(() {
    for (final cell in _cells.removeLast()) {
      cell.dispose();
    }
  });

  void _removeColumn() => setState(() {
    for (final row in _cells) {
      row.removeLast().dispose();
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    return AppDialog(
      icon: LucideIcons.table,
      title: l10n.tableTitle,
      subtitle: l10n.tableSubtitle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var r = 0; r < _cells.length; r++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          for (var c = 0; c < _columns; c++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: SizedBox(
                                width: 128,
                                child: TextField(
                                  key: Key('table-cell-$r-$c'),
                                  controller: _cells[r][c],
                                  autofocus: r == 0 && c == 0,
                                  style: text.style(14, r == 0 ? FontWeight.w700 : FontWeight.w500),
                                  decoration: appInputDecoration(
                                    context,
                                    hint: l10n.tableCellHint,
                                    dense: true,
                                    fillColor: r == 0 ? const Color(0xFFF1F3FA) : BrandColors.chalk,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TonalButton(label: l10n.tableAddRow, icon: LucideIcons.plus, onPressed: _cells.length < _maxRows ? _addRow : null),
              TonalButton(label: l10n.tableAddColumn, icon: LucideIcons.plus, onPressed: _columns < _maxColumns ? _addColumn : null),
              GhostButton(label: l10n.tableRemoveRow, icon: LucideIcons.minus, height: 38, onPressed: _cells.length > 1 ? _removeRow : null),
              GhostButton(label: l10n.tableRemoveColumn, icon: LucideIcons.minus, height: 38, onPressed: _columns > 1 ? _removeColumn : null),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.existing) DangerButton(label: l10n.tableDelete, onPressed: () => Navigator.of(context).pop(const EmbedEdit<TableData>.remove())),
        GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(context).maybePop()),
        PrimaryButton(
          label: widget.existing ? l10n.validate : l10n.insert,
          height: 44,
          onPressed: () => Navigator.of(context).pop(
            EmbedEdit.value(TableData([for (final row in _cells) [for (final cell in row) cell.text.trim()]])),
          ),
        ),
      ],
    );
  }
}

/// "Lignes pour répondre": how many dotted lines.
Future<EmbedEdit<int>?> showLinesDialog(BuildContext context, int count) =>
    showAppDialog<EmbedEdit<int>>(context, builder: (_) => _LinesDialog(count: count));

class _LinesDialog extends StatefulWidget {
  const _LinesDialog({required this.count});

  final int count;

  @override
  State<_LinesDialog> createState() => _LinesDialogState();
}

class _LinesDialogState extends State<_LinesDialog> {
  late int _count = widget.count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    return AppDialog(
      icon: LucideIcons.alignJustify,
      title: l10n.linesTitle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconSquareButton(icon: LucideIcons.minus, tooltip: l10n.tableRemoveRow, onPressed: _count > 1 ? () => setState(() => _count--) : null),
              SizedBox(
                width: 120,
                child: Text(l10n.linesCount(_count), textAlign: TextAlign.center, style: text.rowTitle),
              ),
              IconSquareButton(icon: LucideIcons.plus, tooltip: l10n.tableAddRow, onPressed: _count < 12 ? () => setState(() => _count++) : null),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200), child: ClipRect(child: AnswerLinesView(count: _count.clamp(1, 6)))),
        ],
      ),
      actions: [
        DangerButton(label: l10n.linesDelete, onPressed: () => Navigator.of(context).pop(const EmbedEdit<int>.remove())),
        GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(context).maybePop()),
        PrimaryButton(label: l10n.validate, height: 44, onPressed: () => Navigator.of(context).pop(EmbedEdit.value(_count))),
      ],
    );
  }
}

/// A picture of the page: its size, or out of the page.
Future<EmbedEdit<PictureSize>?> showPictureDialog(BuildContext context, PictureData picture, String? url) =>
    showAppDialog<EmbedEdit<PictureSize>>(context, builder: (_) => _PictureDialog(picture: picture, url: url));

class _PictureDialog extends StatefulWidget {
  const _PictureDialog({required this.picture, required this.url});

  final PictureData picture;
  final String? url;

  @override
  State<_PictureDialog> createState() => _PictureDialogState();
}

class _PictureDialogState extends State<_PictureDialog> {
  late PictureSize _size = widget.picture.size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      icon: LucideIcons.image,
      title: l10n.pictureTitle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedChoice<PictureSize>(
            value: _size,
            onChanged: (size) => setState(() => _size = size),
            options: [
              SelectOption(PictureSize.small, l10n.pictureSizeSmall),
              SelectOption(PictureSize.medium, l10n.pictureSizeMedium),
              SelectOption(PictureSize.full, l10n.pictureSizeFull),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: PagePictureView(url: widget.url, size: _size),
          ),
        ],
      ),
      actions: [
        DangerButton(label: l10n.pictureDelete, onPressed: () => Navigator.of(context).pop(const EmbedEdit<PictureSize>.remove())),
        GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(context).maybePop()),
        PrimaryButton(label: l10n.validate, height: 44, onPressed: () => Navigator.of(context).pop(EmbedEdit.value(_size))),
      ],
    );
  }
}
