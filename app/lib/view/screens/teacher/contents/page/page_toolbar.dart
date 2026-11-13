import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/app_text.dart';
import '../../../../../core/theme/brand_colors.dart';
import '../../../../../l10n/app_localizations.dart';

/// What the toolbar asks of the page for the inserts; the text formats it applies itself. A quiz question
/// has no answer lines, and a "Texte à trous" turns the selected word into a gap ([blank]).
class PageInserts {
  const PageInserts({required this.formula, required this.table, required this.picture, this.lines, this.blank});

  final VoidCallback formula;
  final VoidCallback table;
  final VoidCallback picture;
  final VoidCallback? lines;
  final VoidCallback? blank;
}

/// The ribbon of the Word-like page (design `r3/EditeurDocument.png`): on top of the page on a computer,
/// above the keyboard on a phone, scrolling sideways when it does not fit.
class PageToolbar extends StatelessWidget {
  const PageToolbar({super.key, required this.controller, required this.inserts, this.phone = false, this.compact = false});

  final QuillController controller;
  final PageInserts inserts;
  final bool phone;

  /// A quiz question's ribbon (design `r3/QuizEditeur.png`): the text formats, lists and inserts only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Taps on the ribbon count as taps in the editor: a phone keeps its keyboard and the selection stays.
    return TextFieldTapRegion(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _Ribbon(controller: controller, inserts: inserts, phone: phone, compact: compact),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.controller, required this.inserts, required this.phone, required this.compact});

  final QuillController controller;
  final PageInserts inserts;
  final bool phone;
  final bool compact;

  Map<String, Attribute> get _attributes => controller.getSelectionStyle().attributes;

  bool _has(Attribute attribute) => _attributes[attribute.key]?.value == attribute.value;

  void _toggle(Attribute attribute) => controller.formatSelection(_has(attribute) ? Attribute.clone(attribute, null) : attribute);

  bool get _rtl => _has(Attribute.rtl);

  /// Start, center or end of the line, whichever way the line is written.
  void _align(String? where) {
    final physical = switch (where) {
      'end' => _rtl ? Attribute.leftAlignment : Attribute.rightAlignment,
      'center' => Attribute.centerAlignment,
      _ => Attribute.clone(Attribute.align, null),
    };
    controller.formatSelection(physical);
  }

  String? get _alignment {
    final value = _attributes[Attribute.align.key]?.value;
    if (value == 'center') return 'center';
    if (value == (_rtl ? 'left' : 'right')) return 'end';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final header = _attributes[Attribute.header.key]?.value as int?;
    final size = _attributes[Attribute.size.key]?.value?.toString() ?? '16';
    final tools = <Widget>[
      if (!compact) ...[
      _Tool(LucideIcons.undo2, l10n.toolUndo, onPressed: controller.hasUndo ? controller.undo : null),
      _Tool(LucideIcons.redo2, l10n.toolRedo, onPressed: controller.hasRedo ? controller.redo : null),
      const _Gap(),
      _MenuTool<int?>(
        key: const Key('tool-style'),
        tooltip: l10n.toolStyle,
        label: switch (header) {
          1 => l10n.styleTitle1,
          2 => l10n.styleTitle2,
          3 => l10n.styleTitle3,
          _ => l10n.styleNormal,
        },
        width: 92,
        options: [
          (null, l10n.styleNormal),
          (1, l10n.styleTitle1),
          (2, l10n.styleTitle2),
          (3, l10n.styleTitle3),
        ],
        onSelected: (level) => controller.formatSelection(switch (level) {
          1 => Attribute.h1,
          2 => Attribute.h2,
          3 => Attribute.h3,
          _ => Attribute.clone(Attribute.header, null),
        }),
      ),
      _MenuTool<String>(
        key: const Key('tool-size'),
        tooltip: l10n.toolSize,
        label: size,
        width: 56,
        options: [for (final s in const ['12', '14', '16', '18', '20', '24', '28']) (s, s)],
        onSelected: (value) => controller.formatSelection(
          value == '16' ? Attribute.clone(Attribute.size, null) : Attribute.fromKeyValue(Attribute.size.key, value),
        ),
      ),
      const _Gap(),
      ],
      _Tool(LucideIcons.bold, l10n.toolBold, active: _has(Attribute.bold), onPressed: () => _toggle(Attribute.bold)),
      _Tool(LucideIcons.italic, l10n.toolItalic, active: _has(Attribute.italic), onPressed: () => _toggle(Attribute.italic)),
      _Tool(LucideIcons.underline, l10n.toolUnderline, active: _has(Attribute.underline), onPressed: () => _toggle(Attribute.underline)),
      _ColorTool(
        icon: LucideIcons.baseline,
        tooltip: l10n.toolColor,
        noColor: l10n.toolNoColor,
        colors: const [BrandColors.ink, BrandColors.indigo, Color(0xFF0B7C75), Color(0xFFE03131), Color(0xFFE8590C), Color(0xFF2F9E44), Color(0xFF7048E8)],
        current: _attributes[Attribute.color.key]?.value as String?,
        onSelected: (hex) => controller.formatSelection(hex == null ? Attribute.clone(Attribute.color, null) : ColorAttribute(hex)),
      ),
      _ColorTool(
        icon: LucideIcons.highlighter,
        tooltip: l10n.toolHighlight,
        noColor: l10n.toolNoColor,
        colors: const [Color(0xFFFFF4DC), Color(0xFFFFE08A), Color(0xFFE7F6EA), Color(0xFFE3F6F4), Color(0xFFF1ECFD), Color(0xFFFDECEC)],
        current: _attributes[Attribute.background.key]?.value as String?,
        onSelected: (hex) => controller.formatSelection(hex == null ? Attribute.clone(Attribute.background, null) : BackgroundAttribute(hex)),
      ),
      const _Gap(),
      if (!compact) ...[
        _Tool(LucideIcons.textAlignStart, l10n.toolAlignStart, active: _alignment == null, onPressed: () => _align(null)),
        _Tool(LucideIcons.textAlignCenter, l10n.toolAlignCenter, active: _alignment == 'center', onPressed: () => _align('center')),
        _Tool(LucideIcons.textAlignEnd, l10n.toolAlignEnd, active: _alignment == 'end', onPressed: () => _align('end')),
      ],
      _Tool(LucideIcons.pilcrowLeft, l10n.toolRtl, active: _rtl, onPressed: () => _toggle(Attribute.rtl)),
      const _Gap(),
      _Tool(LucideIcons.list, l10n.toolBullets, active: _has(Attribute.ul), onPressed: () => _toggle(Attribute.ul)),
      _Tool(LucideIcons.listOrdered, l10n.toolNumbers, active: _has(Attribute.ol), onPressed: () => _toggle(Attribute.ol)),
      const _Gap(),
      _Tool(LucideIcons.table, l10n.toolTable, key: const Key('tool-table'), onPressed: inserts.table),
      _Tool(LucideIcons.imagePlus, l10n.toolPicture, key: const Key('tool-picture'), onPressed: inserts.picture),
      if (inserts.lines != null) _Tool(LucideIcons.alignJustify, l10n.toolLines, key: const Key('tool-lines'), onPressed: inserts.lines),
      if (inserts.blank != null) _Tool(LucideIcons.brackets, l10n.toolBlank, key: const Key('tool-blank'), onPressed: inserts.blank),
      const SizedBox(width: 6),
      _FormulaButton(label: l10n.toolFormula, compact: phone, onPressed: inserts.formula),
    ];
    // Its own surface: the ripples of the tools need one, wherever the ribbon sits.
    return Material(
      color: Colors.white,
      shape: phone
          ? const Border(top: BorderSide(color: BrandColors.line))
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.row), side: const BorderSide(color: BrandColors.line)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: tools),
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 6), color: BrandColors.line);
}

class _Tool extends StatelessWidget {
  const _Tool(this.icon, this.tooltip, {super.key, required this.onPressed, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      selected: active,
      label: tooltip,
      child: Material(
        color: active ? BrandColors.indigoSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.badge),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.badge),
          onTap: onPressed,
          canRequestFocus: false,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(
              icon,
              size: 18,
              color: onPressed == null ? const Color(0xFFB8BCD3) : (active ? BrandColors.indigo : BrandColors.ink),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MenuTool<T> extends StatelessWidget {
  const _MenuTool({
    super.key,
    required this.tooltip,
    required this.label,
    required this.options,
    required this.onSelected,
    required this.width,
  });

  final String tooltip;
  final String label;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return MenuAnchor(
      menuChildren: [
        for (final (value, name) in options)
          MenuItemButton(
            onPressed: () => onSelected(value),
            child: Text(name, style: text.style(14, FontWeight.w600)),
          ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.badge),
          canRequestFocus: false,
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          child: Container(
            constraints: BoxConstraints(minWidth: width),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.style(13, FontWeight.w700))),
                const SizedBox(width: 2),
                const Icon(LucideIcons.chevronDown, size: 14, color: BrandColors.slate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _hex(Color color) => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _ColorTool extends StatelessWidget {
  const _ColorTool({
    required this.icon,
    required this.tooltip,
    required this.noColor,
    required this.colors,
    required this.current,
    required this.onSelected,
  });

  final IconData icon;
  final String tooltip;
  final String noColor;
  final List<Color> colors;
  final String? current;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final color in colors)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(_hex(color)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: current == _hex(color) ? BrandColors.indigo : BrandColors.line, width: current == _hex(color) ? 2 : 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        MenuItemButton(onPressed: () => onSelected(null), child: Text(noColor, style: text.style(13, FontWeight.w600))),
      ],
      builder: (context, menu, _) => _Tool(icon, tooltip, active: current != null, onPressed: () => menu.isOpen ? menu.close() : menu.open()),
    );
  }
}

class _FormulaButton extends StatelessWidget {
  const _FormulaButton({required this.label, required this.compact, required this.onPressed});

  final String label;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final fx = Text('ƒx', style: text.style(15, FontWeight.w800, color: Colors.white).copyWith(fontStyle: FontStyle.italic));
    return Tooltip(
      message: label,
      child: Material(
        key: const Key('tool-formula'),
        color: BrandColors.indigo,
        borderRadius: BorderRadius.circular(AppRadii.badge),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.badge),
          canRequestFocus: false,
          onTap: onPressed,
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                fx,
                if (!compact) ...[const SizedBox(width: 6), Text(label, style: text.style(13, FontWeight.w700, color: Colors.white))],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
