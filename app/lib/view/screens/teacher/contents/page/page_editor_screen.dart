import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/l10n/formatting.dart';
import '../../../../../core/l10n/tunis_time.dart';
import '../../../../../core/network/api_failure.dart';
import '../../../../../core/platform/photo_source.dart';
import '../../../../../core/router/routes.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/theme/brand_colors.dart';
import '../../../../../domain/model/content.dart';
import '../../../../../domain/model/written_page.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../stateManager/common/load_status.dart';
import '../../../../stateManager/language/language_cubit.dart';
import '../../../../stateManager/library/library_cubit.dart';
import '../../../../stateManager/page_editor/page_editor_cubit.dart';
import '../../../../stateManager/reference/reference_cubit.dart';
import '../../../../stateManager/share/share_cubit.dart';
import '../../../../widgets/buttons.dart';
import '../../../../widgets/cards.dart';
import '../../../../widgets/content_widgets.dart';
import '../../../../widgets/controls.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/page_frame.dart';
import '../../../../widgets/panels.dart';
import '../../../../widgets/written_page.dart';
import '../document_form_panel.dart';
import '../share_dialog.dart';
import 'page_dialogs.dart';
import 'page_toolbar.dart';

/// The Word-like page (release 3, design `r3/EditeurDocument.png`, the teacher phone of
/// `r3/SeriesQuizPhone.png`): the page and its Corrigé, written with the ribbon, saved on its own.
class PageEditorScreen extends StatelessWidget {
  const PageEditorScreen({super.key, required this.pageId});

  final String pageId;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => PageEditorCubit(sl.get(), sl.get(), sl.get<Now>(), pageId)..load()),
      // The chapter's title in the header, and "Modifier les détails".
      BlocProvider(create: (_) => sl.get<LibraryCubit>()..load()),
    ],
    child: const _PageEditorView(),
  );
}

class _PageEditorView extends StatelessWidget {
  const _PageEditorView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PageEditorCubit>().state;
    final page = state.page;
    if (page == null) {
      return PageScroll(
        children: [
          const _BackLink(),
          if (state.status == LoadStatus.failure && state.failure != null)
            FailureBanner(state.failure!, onRetry: context.read<PageEditorCubit>().load)
          else
            const LinearProgressIndicator(minHeight: 3),
        ],
      );
    }
    return _Editor(key: ValueKey(page.document.id), page: page);
  }
}

void _leave(BuildContext context) =>
    context.canPop() ? Navigator.of(context).maybePop() : context.go(Routes.teacherContents);

class _BackLink extends StatelessWidget {
  const _BackLink();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      onPressed: () => _leave(context),
      icon: const Icon(LucideIcons.arrowLeftDir, size: 18, color: BrandColors.indigo),
      label: Text(
        AppLocalizations.of(context).navContents,
        style: AppText.of(context).style(14, FontWeight.w700, color: BrandColors.indigo),
      ),
    ),
  );
}

final _arabicLetter = RegExp(r'[\u0600-\u06FF]');
final _letter = RegExp(r'[A-Za-z\u00C0-\u024F\u0600-\u06FF]');

class _Editor extends StatefulWidget {
  const _Editor({super.key, required this.page});

  final WrittenPage page;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _page = _controllerFor(widget.page.body);
  late final _answer = _controllerFor(widget.page.answerBody);
  final _pageFocus = FocusNode();
  final _answerFocus = FocusNode();
  final _scroll = ScrollController();
  final _sheetKey = GlobalKey();
  final _changes = <StreamSubscription<DocChange>>[];

  /// The Corrigé tab.
  bool _corrige = false;

  /// A4 sheets the page fills now ("3 pages · A4").
  int _sheets = 1;

  static QuillController _controllerFor(List<Map<String, dynamic>> body) =>
      QuillController(document: pageDocument(body), selection: const TextSelection.collapsed(offset: 0));

  QuillController get _active => _corrige ? _answer : _page;

  FocusNode get _activeFocus => _corrige ? _answerFocus : _pageFocus;

  PageEditorCubit get _cubit => context.read<PageEditorCubit>();

  @override
  void initState() {
    super.initState();
    for (final controller in [_page, _answer]) {
      _changes.add(controller.document.changes.listen((change) => _changed(controller, change)));
    }
  }

  @override
  void dispose() {
    for (final subscription in _changes) {
      unawaited(subscription.cancel());
    }
    _page.dispose();
    _answer.dispose();
    _pageFocus.dispose();
    _answerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static List<Map<String, dynamic>> _json(QuillController controller) => [
    for (final op in controller.document.toDelta().toJson()) Map<String, dynamic>.from(op as Map),
  ];

  void _changed(QuillController controller, DocChange change) {
    _cubit.changed(body: _json(_page), answerBody: _json(_answer));
    if (change.source == ChangeSource.local) _writeArabicFromTheRight(controller);
  }

  /// Lines whose direction is settled: the teacher's ¶ is never undone behind her back.
  final _decided = Expando<bool>('direction');

  /// A line whose first letter is Arabic is written from the right, as in Word, typed or pasted; decided once
  /// per line, so the ribbon's ¶ can turn it back.
  void _writeArabicFromTheRight(QuillController controller) {
    final offset = controller.selection.baseOffset;
    if (offset < 0) return;
    final line = controller.document.queryChild(offset).node;
    if (line is! Line || _decided[line] == true) return;
    if (line.style.attributes.containsKey(Attribute.direction.key)) {
      _decided[line] = true;
      return;
    }
    final first = _letter.firstMatch(line.toPlainText())?.group(0);
    if (first == null) return;
    _decided[line] = true;
    if (!_arabicLetter.hasMatch(first)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && line.parent != null) controller.formatText(line.documentOffset, line.length, Attribute.rtl);
    });
  }

  /// A table, a picture or answer lines go on a line of their own, with a line after them to go on writing.
  void _insertBlock(QuillController controller, Embeddable embed) {
    final document = controller.document;
    final index = controller.selection.baseOffset.clamp(0, document.length - 1);
    final query = document.queryChild(index);
    final line = query.node;
    final inLine = query.offset;
    final textLength = line == null ? 0 : line.length - 1;
    var at = index;
    if (textLength > 0 && inLine > 0) {
      controller.replaceText(at, 0, '\n', null, ignoreFocus: true);
      at++;
    }
    controller.replaceText(at, 0, embed, null, ignoreFocus: true);
    if (textLength > 0 && inLine < textLength || at + 2 >= controller.document.length) {
      controller.replaceText(at + 1, 0, '\n', null, ignoreFocus: true);
    }
    controller.updateSelection(TextSelection.collapsed(offset: at + 2), ChangeSource.local);
  }

  void _replaceEmbed(QuillController controller, int offset, Object data) =>
      controller.replaceText(offset, 1, data, TextSelection.collapsed(offset: offset + 1), ignoreFocus: true);

  Future<void> _insertFormula() async {
    final controller = _active;
    final selection = controller.selection;
    final source = await showFormulaDialog(context);
    if (source == null || !mounted) return;
    final start = selection.start.clamp(0, controller.document.length - 1);
    final length = (selection.end - selection.start).clamp(0, controller.document.length - 1 - start);
    controller.replaceText(start, length, Embeddable(PageEmbeds.formula, source), TextSelection.collapsed(offset: start + 1));
    _activeFocus.requestFocus();
  }

  Future<void> _insertTable() async {
    final controller = _active;
    final edit = await showTableDialog(context, TableData.blank);
    final table = edit?.value;
    if (table == null || !mounted) return;
    _insertBlock(controller, Embeddable(PageEmbeds.table, table.toJson()));
  }

  Future<void> _insertLines() async {
    _insertBlock(_active, const Embeddable(PageEmbeds.lines, {'count': 2}));
  }

  Future<void> _insertPicture() async {
    final l10n = AppLocalizations.of(context);
    final controller = _active;
    final photos = sl.get<PhotoSource>();
    Uint8List? bytes;
    try {
      if (photos.hasCamera) {
        final camera = await showAppDialog<bool>(
          context,
          builder: (dialogContext) => AppDialog(
            icon: LucideIcons.image,
            title: l10n.pictureTitle,
            actions: [
              SecondaryButton(label: l10n.pictureChoose, icon: LucideIcons.images, onPressed: () => Navigator.of(dialogContext).pop(false)),
              PrimaryButton(label: l10n.pictureTake, icon: LucideIcons.camera, height: 44, onPressed: () => Navigator.of(dialogContext).pop(true)),
            ],
          ),
        );
        if (camera == null) return;
        bytes = camera ? await photos.takePhoto() : (await photos.pickPhotos()).firstOrNull;
      } else {
        bytes = (await photos.pickPhotos()).firstOrNull;
      }
    } on Object catch (error) {
      if (mounted) showNotice(context, failureText(l10n, ApiFailure.from(error)));
      return;
    }
    if (bytes == null || !mounted) return;
    showNotice(context, l10n.pictureSending);
    try {
      final id = await _cubit.addPicture(PickedFile(name: 'image.jpg', bytes: bytes));
      if (id == null || !mounted) return;
      _insertBlock(controller, Embeddable(PageEmbeds.picture, PictureData(id: id).toJson()));
    } on Object catch (error) {
      if (mounted) showNotice(context, failureText(l10n, ApiFailure.from(error)));
    }
  }

  /// A tap on a formula, a table, a picture or answer lines opens its window.
  Future<void> _onEmbedTap(EmbedContext embed) async {
    final controller = embed.controller;
    final offset = embed.node.documentOffset;
    final data = embed.node.value.data;
    switch (embed.node.value.type) {
      case PageEmbeds.formula:
        final source = await showFormulaDialog(context, initial: '${data ?? ''}', editing: true);
        if (source != null && mounted) _replaceEmbed(controller, offset, Embeddable(PageEmbeds.formula, source));
      case PageEmbeds.table:
        final edit = await showTableDialog(context, TableData.from(data), existing: true);
        if (edit == null || !mounted) return;
        _replaceEmbed(controller, offset, edit.remove ? '' : Embeddable(PageEmbeds.table, edit.value!.toJson()));
      case PageEmbeds.picture:
        final picture = PictureData.from(data);
        final edit = await showPictureDialog(context, picture, _cubit.state.pictureUrls[picture.id]);
        if (edit == null || !mounted) return;
        _replaceEmbed(
          controller,
          offset,
          edit.remove ? '' : Embeddable(PageEmbeds.picture, PictureData(id: picture.id, size: edit.value!).toJson()),
        );
      case PageEmbeds.lines:
        final edit = await showLinesDialog(context, linesCountOf(data));
        if (edit == null || !mounted) return;
        _replaceEmbed(controller, offset, edit.remove ? '' : Embeddable(PageEmbeds.lines, {'count': edit.value}));
    }
  }

  void _preview() {
    final l10n = AppLocalizations.of(context);
    final body = _json(_page);
    final pictures = _cubit.state.pictureUrls;
    showSidePanel<void>(
      context,
      width: 680,
      builder: (panelContext) => SidePanel(
        icon: LucideIcons.eye,
        title: l10n.studentPreview,
        subtitle: l10n.studentPreviewSubtitle,
        actions: [PrimaryButton(label: l10n.close, height: 44, onPressed: () => Navigator.of(panelContext).pop())],
        body: WrittenPageView(body: body, pictureUrls: pictures),
      ),
    );
  }

  Future<void> _editDetails() async {
    final document = _cubit.state.document;
    if (document == null) return;
    final saved = await DocumentFormPanel.edit(context, document);
    if (saved != null && mounted) _cubit.documentChanged(saved);
  }

  /// "Publier", then the groups that see it; once published, "Partager".
  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context);
    final cubit = _cubit;
    if (!(cubit.state.document?.published ?? false)) {
      final failure = await cubit.publish();
      if (!mounted) return;
      if (failure != null) {
        showNotice(context, failureText(l10n, failure));
        return;
      }
      showNotice(context, l10n.pagePublished);
    }
    final document = cubit.state.document;
    if (document == null || !mounted) return;
    final shared = await showShareDialog(context, DocumentTarget(document));
    if (shared is ContentDocument && !cubit.isClosed) cubit.documentChanged(shared);
  }

  /// How many A4 sheets the page fills, once laid out.
  void _measure() {
    final box = _sheetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.width <= 0) return;
    final sheets = (box.size.height / (box.size.width * 1.414)).ceil().clamp(1, 999);
    if (sheets != _sheets) setState(() => _sheets = sheets);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = isPhone(context);
    final state = context.watch<PageEditorCubit>().state;
    final document = state.document ?? widget.page.document;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });

    final inserts = PageInserts(formula: _insertFormula, table: _insertTable, picture: _insertPicture, lines: _insertLines);
    final toolbar = PageToolbar(key: ValueKey(_corrige), controller: _active, inserts: inserts, phone: phone);
    final tabs = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PillTabs<bool>(
          items: [TabItem(false, tagLabel(l10n, document.tag)), TabItem(true, l10n.tagCorrige)],
          value: _corrige,
          onChanged: (corrige) => setState(() => _corrige = corrige),
        ),
        if (_corrige) Text(l10n.pageOnlyYou, style: AppText.of(context).small),
      ],
    );
    final sheet = _Sheet(
      key: _sheetKey,
      document: document,
      corrige: _corrige,
      phone: phone,
      editor: _PageEditor(
        key: ValueKey(_corrige),
        controller: _active,
        focusNode: _activeFocus,
        scrollController: _scroll,
        pictureUrls: state.pictureUrls,
        onEmbedTap: _onEmbedTap,
      ),
    );

    final Widget body;
    if (phone) {
      body = Column(
        children: [
          _PhoneHeader(document: document, onPublish: _publish, onPreview: _preview, onEditDetails: _editDetails),
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Align(alignment: AlignmentDirectional.centerStart, child: tabs)),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFE9EBF3),
              child: SingleChildScrollView(controller: _scroll, padding: const EdgeInsets.all(10), child: sheet),
            ),
          ),
          toolbar,
        ],
      );
    } else {
      body = SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BackLink(),
                const SizedBox(height: 8),
                _WideHeader(document: document, onPublish: _publish, onPreview: _preview, onEditDetails: _editDetails),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: tabs),
                    Text(l10n.pageSheetPages(_sheets), style: AppText.of(context).small),
                  ],
                ),
                const SizedBox(height: 12),
                toolbar,
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFFE9EBF3), borderRadius: BorderRadius.circular(AppRadii.tile)),
                  child: Center(child: sheet),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Leaving after a failed save asks first; anything still waiting is sent on the way out.
    return PopScope(
      canPop: state.save != PageSave.failed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await confirmAction(
          context,
          title: l10n.unsavedGradesTitle,
          text: l10n.unsavedPageText,
          confirmLabel: l10n.leaveWithoutSaving,
        );
        if (leave) navigator.pop();
      },
      child: body,
    );
  }
}

/// "Mathématiques · 4ème année · Les fractions · Série · enregistré à l'instant".
class _Facts extends StatelessWidget {
  const _Facts({required this.document, this.withPlace = true});

  final ContentDocument document;
  final bool withPlace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final reference = context.watch<ReferenceCubit>().state.reference;
    final library = context.watch<LibraryCubit>().state.library;
    final state = context.watch<PageEditorCubit>().state;
    final subject = reference?.subjects.where((s) => s.id == document.subjectId).firstOrNull;
    final level = reference?.levels.where((l) => l.id == document.levelId).firstOrNull;
    final chapter = library.chapters.where((c) => c.id == document.chapterId).firstOrNull;
    final quiet = text.style(13, FontWeight.w500, color: BrandColors.slate);
    final savedAt = state.savedAt;
    final saved = switch (state.save) {
      PageSave.pending || PageSave.saving => l10n.pageSaving,
      PageSave.failed => l10n.pageNotSaved,
      PageSave.saved =>
        savedAt == null || sl.get<Now>()().difference(savedAt).inSeconds < 60 ? l10n.pageSavedNow : l10n.pageSavedAt(hm(savedAt)),
    };
    final parts = [
      if (withPlace) ...[
        if (subject != null) isolated(subject.name.of(language)),
        if (level != null) isolated(level.name.of(language)),
        if (chapter != null) isolated(chapter.title),
        tagLabel(l10n, document.tag),
      ],
      saved,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DocumentStatusChip(document.status),
        Text(
          parts.join(l10n.dotSeparator),
          key: const Key('page-facts'),
          style: state.save == PageSave.failed ? quiet.copyWith(color: Accent.red.onSoft) : quiet,
        ),
        if (state.save == PageSave.failed)
          TextButton(onPressed: context.read<PageEditorCubit>().retry, child: Text(l10n.retry, style: text.style(13, FontWeight.w700, color: BrandColors.indigo))),
      ],
    );
  }
}

IconData _tagIcon(ContentTag tag) => switch (tag) {
  ContentTag.serie => LucideIcons.layers,
  ContentTag.cours => LucideIcons.bookOpen,
  ContentTag.corrige => LucideIcons.circleCheck,
  ContentTag.autre => LucideIcons.filePen,
};

class _WideHeader extends StatelessWidget {
  const _WideHeader({required this.document, required this.onPublish, required this.onPreview, required this.onEditDetails});

  final ContentDocument document;
  final VoidCallback onPublish;
  final VoidCallback onPreview;
  final VoidCallback onEditDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<PageEditorCubit>().state;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(icon: _tagIcon(document.tag), accent: tagAccent(document.tag)),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(document.title, style: text.pageTitle().copyWith(fontSize: 30)),
                    const SizedBox(height: 6),
                    _Facts(document: document),
                  ],
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            IconSquareButton(icon: LucideIcons.pencil, tooltip: l10n.actionEditDetails, onPressed: onEditDetails),
            SecondaryButton(key: const Key('page-preview'), label: l10n.studentPreview, icon: LucideIcons.eye, onPressed: onPreview),
            PrimaryButton(
              key: const Key('page-publish'),
              label: document.published ? l10n.actionShare : l10n.publish,
              icon: document.published ? LucideIcons.share2 : LucideIcons.check,
              height: 44,
              loading: state.publishing,
              onPressed: onPublish,
            ),
          ],
        ),
      ],
    );
  }
}

class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader({required this.document, required this.onPublish, required this.onPreview, required this.onEditDetails});

  final ContentDocument document;
  final VoidCallback onPublish;
  final VoidCallback onPreview;
  final VoidCallback onEditDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<PageEditorCubit>().state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          IconSquareButton(icon: LucideIcons.arrowLeftDir, tooltip: l10n.navContents, onPressed: () => _leave(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.style(16, FontWeight.w800)),
                const SizedBox(height: 2),
                _Facts(document: document, withPlace: false),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const Key('page-publish'),
            label: document.published ? l10n.actionShare : l10n.publish,
            height: 40,
            loading: state.publishing,
            onPressed: onPublish,
          ),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(leadingIcon: const Icon(LucideIcons.eye, size: 18), onPressed: onPreview, child: Text(l10n.studentPreview)),
              MenuItemButton(leadingIcon: const Icon(LucideIcons.pencil, size: 18), onPressed: onEditDetails, child: Text(l10n.actionEditDetails)),
            ],
            builder: (context, menu, _) => IconButton(
              tooltip: l10n.documentActions,
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(LucideIcons.ellipsisVertical, size: 20, color: BrandColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The A4 sheet: the brand, the title and the level on top, "Nom et prénom" for the pupil, then the text.
class _Sheet extends StatelessWidget {
  const _Sheet({super.key, required this.document, required this.corrige, required this.phone, required this.editor});

  final ContentDocument document;
  final bool corrige;
  final bool phone;
  final Widget editor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final level = context.watch<ReferenceCubit>().state.reference?.levels.where((l) => l.id == document.levelId).firstOrNull;
    return Container(
      // A4 at 96 dots per inch.
      constraints: BoxConstraints(maxWidth: 794, minHeight: phone ? 360 : 640),
      padding: phone ? const EdgeInsets.fromLTRB(16, 18, 16, 28) : const EdgeInsets.fromLTRB(52, 44, 52, 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Color(0x241C2566), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandColors.indigo, width: 2))),
            child: Row(
              children: [
                Image.asset('assets/brand/symbol.png', height: 20, excludeFromSemantics: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    corrige ? '${document.title}${l10n.dotSeparator}${l10n.tagCorrige}' : document.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.style(phone ? 15 : 19, FontWeight.w800),
                  ),
                ),
                if (level != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      level.name.of(language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.style(13, FontWeight.w600, color: BrandColors.slate),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!corrige) ...[
            const SizedBox(height: 6),
            Text('${l10n.sheetNameLine} ${'.' * 48}', maxLines: 1, overflow: TextOverflow.clip, style: text.style(13, FontWeight.w500, color: BrandColors.slate)),
          ],
          const SizedBox(height: 16),
          editor,
        ],
      ),
    );
  }
}

/// The editor itself, inside the page's scroll view (it keeps the cursor in sight through [scrollController]).
class _PageEditor extends StatelessWidget {
  const _PageEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.pictureUrls,
    required this.onEmbedTap,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final Map<String, String> pictureUrls;
  final PageEmbedTap onEmbedTap;

  @override
  Widget build(BuildContext context) {
    final base = pageTextStyle(context);
    return Directionality(
      // The page keeps its own directions: an Arabic line says so, whoever reads it.
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: base,
        child: QuillEditor(
          controller: controller,
          focusNode: focusNode,
          scrollController: scrollController,
          config: QuillEditorConfig(
            scrollable: false,
            padding: EdgeInsets.zero,
            minHeight: 200,
            placeholder: AppLocalizations.of(context).pagePlaceholder,
            customStyles: pageStyles(base),
            embedBuilders: pageEmbedBuilders(pictureUrls: pictureUrls, onTap: onEmbedTap),
          ),
        ),
      ),
    );
  }
}
