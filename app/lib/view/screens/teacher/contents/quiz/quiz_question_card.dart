import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/network/api_failure.dart';
import '../../../../../core/platform/photo_source.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/theme/brand_colors.dart';
import '../../../../../domain/model/content.dart';
import '../../../../../domain/model/quiz.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../stateManager/quiz_editor/quiz_editor_cubit.dart';
import '../../../../widgets/buttons.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/panels.dart';
import '../../../../widgets/quiz_widgets.dart';
import '../../../../widgets/text_field.dart';
import '../../../../widgets/written_page.dart';
import '../page/page_dialogs.dart';
import '../page/page_toolbar.dart';

/// The points a question may have.
const _pointChoices = [1, 2, 3, 4, 5, 6, 8, 10, 15, 20];

/// One question of the builder (design `r3/QuizEditeur.png`): its number, type and points; the selected
/// one shows its ribbon, its text to write and what makes it right; the others read as pupils will.
class QuizQuestionCard extends StatelessWidget {
  const QuizQuestionCard({
    super.key,
    required this.question,
    required this.number,
    required this.count,
    required this.selected,
    required this.locked,
    required this.incomplete,
  });

  final QuizQuestion question;
  final int number;
  final int count;
  final bool selected;
  final bool locked;
  final bool incomplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final cubit = context.read<QuizEditorCubit>();
    final pictureUrls = context.select((QuizEditorCubit c) => c.state.quiz?.pictureUrls ?? const <String, String>{});
    final editing = selected && !locked;
    final border = incomplete ? Accent.red.strong : (selected ? BrandColors.indigo : BrandColors.line);
    final header = Row(
      children: [
        if (!locked) const Icon(LucideIcons.gripVertical, size: 16, color: BrandColors.slate),
        if (!locked) const SizedBox(width: 6),
        QuestionNumber(number),
        const SizedBox(width: 10),
        QuestionTypeSquare(question.type),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            questionTypeLabel(l10n, question.type),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.style(15, FontWeight.w700),
          ),
        ),
        if (locked)
          PointsPill(pointsLabel(l10n, question.points))
        else
          MenuAnchor(
            menuChildren: [
              for (final p in _pointChoices)
                MenuItemButton(
                  onPressed: () => cubit.updateQuestion(question.copyWith(points: p)),
                  trailingIcon: p == question.points ? const Icon(LucideIcons.check, size: 16) : null,
                  child: Text(pointsLabel(l10n, p)),
                ),
            ],
            builder: (context, menu, _) => Tooltip(
              message: l10n.questionPoints,
              child: InkWell(
                key: Key('points-${question.id}'),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                onTap: () => menu.isOpen ? menu.close() : menu.open(),
                child: PointsPill(pointsLabel(l10n, question.points)),
              ),
            ),
          ),
        if (!locked)
          MenuAnchor(
            menuChildren: [
              if (number > 1)
                MenuItemButton(
                  leadingIcon: const Icon(LucideIcons.arrowUp, size: 16),
                  onPressed: () => cubit.moveQuestion(question.id, -1),
                  child: Text(l10n.moveUp),
                ),
              if (number < count)
                MenuItemButton(
                  leadingIcon: const Icon(LucideIcons.arrowDown, size: 16),
                  onPressed: () => cubit.moveQuestion(question.id, 1),
                  child: Text(l10n.moveDown),
                ),
              MenuItemButton(
                leadingIcon: const Icon(LucideIcons.copy, size: 16),
                onPressed: () => cubit.duplicateQuestion(question.id),
                child: Text(l10n.duplicate),
              ),
              MenuItemButton(
                leadingIcon: Icon(LucideIcons.trash2, size: 16, color: Accent.red.onSoft),
                onPressed: () => cubit.removeQuestion(question.id),
                child: Text(l10n.deleteQuestion, style: TextStyle(color: Accent.red.onSoft)),
              ),
            ],
            builder: (context, menu, _) => IconButton(
              key: Key('question-menu-${question.id}'),
              tooltip: l10n.questionActions,
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(LucideIcons.ellipsis, size: 20, color: BrandColors.slate),
            ),
          ),
      ],
    );
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: border, width: selected || incomplete ? 1.6 : 1),
        boxShadow: selected ? const [BoxShadow(color: Color(0x142B3990), blurRadius: 18, offset: Offset(0, 6))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 10),
          if (editing)
            _QuestionEditor(key: ValueKey('editor-${question.id}'), question: question)
          else
            _QuestionSummary(question: question, pictureUrls: pictureUrls),
          if (incomplete) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.circleAlert, size: 16, color: Accent.red.onSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l10n.questionIncomplete, style: text.style(13, FontWeight.w600, color: Accent.red.onSoft)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    if (selected) return card;
    return Semantics(
      button: true,
      label: '${l10n.questionNumber(number)} ${questionTypeLabel(l10n, question.type)}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => cubit.select(question.id), child: card),
      ),
    );
  }
}

/// A question as pupils will read it, with what makes it right.
class _QuestionSummary extends StatelessWidget {
  const _QuestionSummary({required this.question, required this.pictureUrls});

  final QuizQuestion question;
  final Map<String, String> pictureUrls;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final quiet = text.style(13, FontWeight.w500, color: BrandColors.slate);
    final hasText = question.hasContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasText)
          QuestionText(question: question, pictureUrls: pictureUrls, size: 16)
        else
          Text(l10n.questionTextEmpty, style: quiet),
        const SizedBox(height: 8),
        switch (question.type) {
          QuestionType.mcq => Column(
            children: [
              for (final c in question.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ChoiceBox(
                    mark: c.id == question.correct ? ChoiceMark.right : ChoiceMark.none,
                    highlight: c.id == question.correct ? Accent.green : null,
                    child: c.text.trim().isEmpty ? Text(l10n.choiceEmpty, style: quiet) : FormulaText(c.text),
                  ),
                ),
            ],
          ),
          QuestionType.trueFalse => Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                _TrueFalseChip(label: l10n.answerTrue, selected: question.answer == true),
                _TrueFalseChip(label: l10n.answerFalse, selected: question.answer == false),
              ],
            ),
          ),
          QuestionType.short => Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(l10n.acceptedAnswers, style: quiet),
              if (question.accepted.isEmpty) Text(l10n.noAcceptedAnswer, style: quiet.copyWith(color: Accent.red.onSoft)),
              AnswerPills(answers: question.accepted),
            ],
          ),
          QuestionType.blanks => Text(l10n.blanksHint, style: quiet),
          QuestionType.open => Row(
            children: [
              const Icon(LucideIcons.messageCircle, size: 15, color: BrandColors.slate),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.openHint, style: quiet)),
            ],
          ),
        },
      ],
    );
  }
}

class _TrueFalseChip extends StatelessWidget {
  const _TrueFalseChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? Accent.green.soft : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: selected ? Accent.green.strong : BrandColors.line),
      ),
      child: Text(label, style: AppText.of(context).style(14, FontWeight.w700, color: selected ? Accent.green.onSoft : BrandColors.slate)),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(borderRadius: BorderRadius.circular(AppRadii.pill), onTap: onTap, child: chip),
    );
  }
}

/// The selected question: the ribbon, its text in the page editor, then what makes it right.
class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({super.key, required this.question});

  final QuizQuestion question;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final QuillController _controller = QuillController(
    document: pageDocument(widget.question.text),
    selection: TextSelection.collapsed(offset: pageDocument(widget.question.text).length - 1),
  );
  final _focus = FocusNode();
  final _scroll = ScrollController();
  StreamSubscription<DocChange>? _changes;

  QuizEditorCubit get _cubit => context.read<QuizEditorCubit>();

  /// The question as the cubit has it now (choices and answers change while the text is written).
  QuizQuestion get _current => _cubit.state.quiz!.questions.firstWhere((q) => q.id == widget.question.id, orElse: () => widget.question);

  @override
  void initState() {
    super.initState();
    _changes = _controller.document.changes.listen((_) => _textChanged());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.question.hasContent) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _textChanged() {
    final json = [for (final op in _controller.document.toDelta().toJson()) Map<String, dynamic>.from(op as Map)];
    _cubit.updateQuestion(_current.copyWith(text: json));
  }

  void _update(QuizQuestion question) => _cubit.updateQuestion(question);

  // ── Inserts, as in the page editor ──

  void _replaceEmbed(int offset, Object data) =>
      _controller.replaceText(offset, 1, data, TextSelection.collapsed(offset: offset + 1), ignoreFocus: true);

  void _insertBlock(Embeddable embed) {
    final at = _controller.selection.baseOffset.clamp(0, _controller.document.length - 1);
    _controller.replaceText(at, 0, '\n', null, ignoreFocus: true);
    _controller.replaceText(at + 1, 0, embed, null, ignoreFocus: true);
    _controller.replaceText(at + 2, 0, '\n', TextSelection.collapsed(offset: at + 3), ignoreFocus: true);
  }

  Future<void> _insertFormula() async {
    final selection = _controller.selection;
    final source = await showFormulaDialog(context);
    if (source == null || !mounted) return;
    final start = selection.start.clamp(0, _controller.document.length - 1);
    final length = (selection.end - selection.start).clamp(0, _controller.document.length - 1 - start);
    _controller.replaceText(start, length, Embeddable(PageEmbeds.formula, source), TextSelection.collapsed(offset: start + 1));
    _focus.requestFocus();
  }

  Future<void> _insertTable() async {
    final edit = await showTableDialog(context, TableData.blank);
    final table = edit?.value;
    if (table == null || !mounted) return;
    _insertBlock(Embeddable(PageEmbeds.table, table.toJson()));
  }

  Future<void> _insertPicture() async {
    final l10n = AppLocalizations.of(context);
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
      _insertBlock(Embeddable(PageEmbeds.picture, PictureData(id: id).toJson()));
    } on Object catch (error) {
      if (mounted) showNotice(context, failureText(l10n, ApiFailure.from(error)));
    }
  }

  /// "Trou": the selected word becomes a gap whose answer it is.
  void _makeBlank() {
    final l10n = AppLocalizations.of(context);
    final selection = _controller.selection;
    final start = selection.start;
    final length = selection.end - selection.start;
    final word = length <= 0 ? '' : _controller.document.getPlainText(start, length).trim();
    if (word.isEmpty || word.contains('\n') || word.contains('￼')) {
      showNotice(context, l10n.blankSelectFirst);
      return;
    }
    _controller.replaceText(
      start,
      length,
      Embeddable(blankEmbed, {
        'id': _cubit.newId('b'),
        'answers': [word],
      }),
      TextSelection.collapsed(offset: start + 1),
    );
    _focus.requestFocus();
  }

  Future<void> _editBlank(EmbedContext embed) async {
    final data = embed.node.value.data;
    final map = data is Map ? data : const {};
    final answers = [for (final a in map['answers'] as List? ?? const []) '$a'];
    final offset = embed.node.documentOffset;
    final result = await showAppDialog<List<String>>(context, builder: (_) => _BlankDialog(answers: answers));
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      // "Retirer le trou": its first answer goes back into the text.
      _controller.replaceText(offset, 1, answers.firstOrNull ?? '', TextSelection.collapsed(offset: offset), ignoreFocus: true);
    } else {
      _replaceEmbed(offset, Embeddable(blankEmbed, {'id': '${map['id']}', 'answers': result}));
    }
  }

  Future<void> _onEmbedTap(EmbedContext embed) async {
    final offset = embed.node.documentOffset;
    final data = embed.node.value.data;
    switch (embed.node.value.type) {
      case PageEmbeds.formula:
        final source = await showFormulaDialog(context, initial: '${data ?? ''}', editing: true);
        if (source != null && mounted) _replaceEmbed(offset, Embeddable(PageEmbeds.formula, source));
      case PageEmbeds.table:
        final edit = await showTableDialog(context, TableData.from(data), existing: true);
        if (edit == null || !mounted) return;
        _replaceEmbed(offset, edit.remove ? '' : Embeddable(PageEmbeds.table, edit.value!.toJson()));
      case PageEmbeds.picture:
        final picture = PictureData.from(data);
        final edit = await showPictureDialog(context, picture, _cubit.state.quiz?.pictureUrls[picture.id]);
        if (edit == null || !mounted) return;
        _replaceEmbed(offset, edit.remove ? '' : Embeddable(PageEmbeds.picture, PictureData(id: picture.id, size: edit.value!).toJson()));
      case blankEmbed:
        await _editBlank(embed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final question = context.select(
      (QuizEditorCubit c) => c.state.quiz?.questions.where((q) => q.id == widget.question.id).firstOrNull ?? widget.question,
    );
    final pictureUrls = context.select((QuizEditorCubit c) => c.state.quiz?.pictureUrls ?? const <String, String>{});
    final base = questionTextStyle(context, size: 16);
    final inserts = PageInserts(
      formula: _insertFormula,
      table: _insertTable,
      picture: _insertPicture,
      blank: question.type == QuestionType.blanks ? _makeBlank : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageToolbar(controller: _controller, inserts: inserts, compact: true),
        const SizedBox(height: 10),
        Directionality(
          // The question keeps its own directions: an Arabic line says so.
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: base,
            child: QuillEditor(
              controller: _controller,
              focusNode: _focus,
              scrollController: _scroll,
              config: QuillEditorConfig(
                scrollable: false,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minHeight: 44,
                placeholder: question.type == QuestionType.blanks ? l10n.blanksPlaceholder : l10n.questionPlaceholder,
                customStyles: pageStyles(base),
                embedBuilders: [
                  ...pageEmbedBuilders(pictureUrls: pictureUrls, onTap: _onEmbedTap),
                  blankBuilder((context, blank, style) => teacherBlank(context, blank, style)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        switch (question.type) {
          QuestionType.mcq => _ChoicesEditor(question: question, onChanged: _update),
          QuestionType.trueFalse => Row(
            children: [
              Expanded(child: Text(l10n.trueFalseHint, style: AppText.of(context).small)),
              _TrueFalseChip(
                label: l10n.answerTrue,
                selected: question.answer == true,
                onTap: () => _update(question.copyWith(answer: () => true)),
              ),
              const SizedBox(width: 8),
              _TrueFalseChip(
                label: l10n.answerFalse,
                selected: question.answer == false,
                onTap: () => _update(question.copyWith(answer: () => false)),
              ),
            ],
          ),
          QuestionType.short => _AcceptedEditor(question: question, onChanged: _update),
          QuestionType.blanks => _BlanksNote(question: question),
          QuestionType.open => Row(
            children: [
              const Icon(LucideIcons.messageCircle, size: 15, color: BrandColors.slate),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.openHint, style: AppText.of(context).small)),
            ],
          ),
        },
        if (question.type != QuestionType.open) ...[
          const SizedBox(height: 14),
          FormInput(
            key: ValueKey('explanation-${question.id}'),
            label: l10n.explanationLabel,
            labelSuffix: l10n.optional,
            hint: l10n.explanationHint,
            initialValue: question.explanation,
            dense: true,
            onChanged: (value) => _update(_current.copyWith(explanation: value)),
          ),
        ],
      ],
    );
  }
}

/// The choices of a multiple choice: a click on the round marks the right one.
class _ChoicesEditor extends StatelessWidget {
  const _ChoicesEditor({required this.question, required this.onChanged});

  final QuizQuestion question;
  final ValueChanged<QuizQuestion> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final cubit = context.read<QuizEditorCubit>();
    final choices = question.choices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  selected: choices[i].id == question.correct,
                  label: l10n.markRightChoice,
                  child: InkWell(
                    key: Key('right-${choices[i].id}'),
                    customBorder: const CircleBorder(),
                    onTap: () => onChanged(question.copyWith(correct: () => choices[i].id)),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ChoiceRound(choices[i].id == question.correct ? ChoiceMark.right : ChoiceMark.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FormInput(
                    key: ValueKey('choice-${choices[i].id}'),
                    hint: l10n.choiceHint(i + 1),
                    initialValue: choices[i].text,
                    dense: true,
                    fillColor: choices[i].id == question.correct ? Accent.green.soft : BrandColors.chalk,
                    onChanged: (value) {
                      final now = cubit.state.quiz!.questions.firstWhere((q) => q.id == question.id);
                      onChanged(now.copyWith(choices: [for (final c in now.choices) c.id == choices[i].id ? c.withText(value) : c]));
                    },
                  ),
                ),
                if (choices.length > 2)
                  IconButton(
                    tooltip: l10n.removeChoice,
                    onPressed: () => onChanged(
                      question.copyWith(
                        choices: [for (final c in choices) if (c.id != choices[i].id) c],
                        correct: question.correct == choices[i].id ? () => null : null,
                      ),
                    ),
                    icon: const Icon(LucideIcons.x, size: 18, color: BrandColors.slate),
                  ),
              ],
            ),
          ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            if (choices.length < 6)
              TextButton.icon(
                key: Key('add-choice-${question.id}'),
                onPressed: () => onChanged(question.copyWith(choices: [...choices, QuizChoice(id: cubit.newId('c'))])),
                icon: const Icon(LucideIcons.plus, size: 16, color: BrandColors.indigo),
                label: Text(l10n.addChoice, style: text.style(14, FontWeight.w700, color: BrandColors.indigo)),
              ),
            Text(l10n.choiceRightHint, style: text.small),
          ],
        ),
      ],
    );
  }
}

/// The answers accepted for a short answer, and the field to add one.
class _AcceptedEditor extends StatefulWidget {
  const _AcceptedEditor({required this.question, required this.onChanged});

  final QuizQuestion question;
  final ValueChanged<QuizQuestion> onChanged;

  @override
  State<_AcceptedEditor> createState() => _AcceptedEditorState();
}

class _AcceptedEditorState extends State<_AcceptedEditor> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _add() {
    final value = _field.text.trim();
    if (value.isEmpty) return;
    final question = widget.question;
    if (!question.accepted.contains(value)) widget.onChanged(question.copyWith(accepted: [...question.accepted, value]));
    _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final question = widget.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Text(l10n.acceptedAnswers, style: text.small),
            for (final a in question.accepted)
              InputChip(
                label: FormulaText(a, style: text.style(13, FontWeight.w700, color: Accent.green.onSoft)),
                backgroundColor: Accent.green.soft,
                side: BorderSide.none,
                deleteIcon: Icon(LucideIcons.x, size: 14, color: Accent.green.onSoft),
                deleteButtonTooltipMessage: l10n.removeAnswer,
                onDeleted: () => widget.onChanged(question.copyWith(accepted: [for (final x in question.accepted) if (x != a) x])),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('accepted-${question.id}'),
                controller: _field,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.acceptedHint,
                  filled: true,
                  fillColor: BrandColors.chalk,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: BrandColors.line)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: const BorderSide(color: BrandColors.line),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TonalButton(label: l10n.addAnswer, icon: LucideIcons.plus, onPressed: _add),
          ],
        ),
        const SizedBox(height: 6),
        Text(l10n.matchingRulesHint, style: text.small),
      ],
    );
  }
}

class _BlanksNote extends StatelessWidget {
  const _BlanksNote({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final count = question.blanks.length;
    return Text(
      count == 0 ? l10n.blanksHint : '${l10n.blanksCount(count)}${l10n.dotSeparator}${l10n.blanksHint}',
      style: text.small.copyWith(color: count == 0 ? Accent.red.onSoft : null),
    );
  }
}

/// A gap's accepted answers, one per line; "Retirer le trou" gives the word back to the text (an empty list).
class _BlankDialog extends StatefulWidget {
  const _BlankDialog({required this.answers});

  final List<String> answers;

  @override
  State<_BlankDialog> createState() => _BlankDialogState();
}

class _BlankDialogState extends State<_BlankDialog> {
  late String _value = widget.answers.join('\n');

  List<String> get _answers => [for (final line in _value.split('\n')) if (line.trim().isNotEmpty) line.trim()];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      icon: LucideIcons.brackets,
      accent: Accent.violet,
      title: l10n.blankDialogTitle,
      subtitle: l10n.blankDialogSubtitle,
      content: FormInput(
        hint: l10n.blankDialogHint,
        initialValue: _value,
        maxLines: 4,
        autofocus: true,
        onChanged: (value) => setState(() => _value = value),
      ),
      actions: [
        GhostButton(label: l10n.blankRemove, onPressed: () => Navigator.of(context).pop(const <String>[])),
        PrimaryButton(
          label: l10n.save,
          height: 44,
          onPressed: _answers.isEmpty ? null : () => Navigator.of(context).pop(_answers),
        ),
      ],
    );
  }
}
