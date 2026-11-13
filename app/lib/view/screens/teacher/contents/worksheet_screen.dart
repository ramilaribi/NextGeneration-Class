import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_language.dart';
import '../../../../core/l10n/formatting.dart';
import '../../../../core/l10n/tunis_time.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/content.dart';
import '../../../../domain/model/worksheet.dart';
import '../../../../domain/services/worksheet_layout.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stateManager/auth/auth_cubit.dart';
import '../../../stateManager/common/load_status.dart';
import '../../../stateManager/language/language_cubit.dart';
import '../../../stateManager/library/library_cubit.dart';
import '../../../stateManager/reference/reference_cubit.dart';
import '../../../stateManager/worksheet/worksheet_cubit.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/content_widgets.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/page_frame.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/text_field.dart';
import '../../../widgets/worksheet_preview.dart';

/// "Imprimer une fiche" (release 3 step 4, designs `r3/Fiche.png`, `r3/FicheVersions.png`): the settings at the
/// start, the A4 sheet at the end, updated as she chooses; on a phone the sheet takes the screen and the
/// settings open in a panel.
class WorksheetScreen extends StatelessWidget {
  const WorksheetScreen({super.key, required this.id, required this.kind});

  final String id;

  /// [FileKind.page] or [FileKind.quiz].
  final FileKind kind;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => WorksheetCubit(sl.get(), sl.get(), sl.get(), sl.get(), sl.get(), id: id, kind: kind)..load(),
      ),
      // The chapter's title in the header, and the pages and quizzes to choose from.
      BlocProvider(create: (_) => sl.get<LibraryCubit>()..load()),
    ],
    child: const WorksheetView(),
  );
}

void _leave(BuildContext context) => context.canPop() ? Navigator.of(context).maybePop() : context.go(Routes.teacherContents);

/// The words and header of the sheet, in the teacher's language.
SheetLabels _labels(BuildContext context, ContentDocument document) {
  final l10n = AppLocalizations.of(context);
  final language = context.watch<LanguageCubit>().state;
  final reference = context.watch<ReferenceCubit>().state.reference;
  final chapters = context.watch<LibraryCubit>().state.library.chapters;
  final user = context.watch<AuthCubit>().user;
  final subject = reference?.subjects.where((s) => s.id == document.subjectId).firstOrNull;
  final level = reference?.levels.where((l) => l.id == document.levelId).firstOrNull;
  final chapter = chapters.where((c) => c.id == document.chapterId).firstOrNull;
  return SheetLabels(
    words: SheetWords(
      answerTrue: l10n.answerTrue,
      answerFalse: l10n.answerFalse,
      answer: l10n.worksheetAnswer,
      or: l10n.worksheetOr,
      explanation: l10n.worksheetExplanation,
      toCorrect: l10n.worksheetToCorrect,
      corrige: l10n.tagCorrige,
      points: l10n.worksheetPoints,
      rtl: language == AppLanguage.ar,
    ),
    place: [?subject?.name.of(language), ?level?.name.of(language), ?chapter?.title].join(l10n.dotSeparator),
    date: fullDate(sl.get<Now>()(), language),
    teacherName: user == null ? '' : '${user.firstName} ${user.lastName}',
    nameLabel: l10n.sheetNameLine,
    markLabel: l10n.worksheetMarkLabel,
    corrigeTitle: (title) => '$title${l10n.dotSeparator}${l10n.tagCorrige}',
  );
}

class WorksheetView extends StatelessWidget {
  const WorksheetView({super.key});

  static Future<void> _make(BuildContext context, Worksheet sheet, WorksheetAction action) async {
    final l10n = AppLocalizations.of(context);
    final arabic = context.read<LanguageCubit>().state == AppLanguage.ar;
    final outcome = await context.read<WorksheetCubit>().make(sheet, action, arabic: arabic);
    if (!context.mounted) return;
    switch (outcome) {
      case WorksheetOutcome.saved:
        showNotice(context, l10n.worksheetSaved);
      case WorksheetOutcome.failed:
        showNotice(context, l10n.worksheetFailed);
      case WorksheetOutcome.done:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final phone = isPhone(context);
    final state = context.watch<WorksheetCubit>().state;
    final document = state.document;
    if (document == null) {
      return PageScroll(
        children: [
          const _BackLink(),
          const SizedBox(height: 12),
          if (state.status == LoadStatus.failure && state.failure != null)
            FailureBanner(state.failure!, onRetry: context.read<WorksheetCubit>().load)
          else
            const LinearProgressIndicator(minHeight: 3),
        ],
      );
    }

    final options = state.options;
    final sheet = worksheetOf(page: state.page, quiz: state.quiz, options: options, labels: _labels(context, document));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final version = options.teacher ? l10n.worksheetTeacherVersion : l10n.worksheetPupilVersion;
    final printButton = PrimaryButton(
      key: const Key('worksheet-print'),
      label: l10n.worksheetPrint,
      icon: LucideIcons.printer,
      height: 44,
      loading: state.busy == WorksheetAction.print,
      onPressed: () => _make(context, sheet, WorksheetAction.print),
    );
    final downloadButton = SecondaryButton(
      key: const Key('worksheet-download'),
      label: phone ? l10n.worksheetShare : l10n.worksheetDownload,
      icon: phone ? LucideIcons.share2 : LucideIcons.download,
      onPressed: state.busy == null ? () => _make(context, sheet, WorksheetAction.download) : null,
    );
    final preview = KeyedSubtree(
      key: const Key('worksheet-preview'),
      child: WorksheetPreview(sheet: sheet, rtl: rtl),
    );

    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 12, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: BrandColors.line)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.navContents,
                  onPressed: () => _leave(context),
                  icon: const Icon(LucideIcons.arrowLeftDir, size: 22, color: BrandColors.ink),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.worksheetShort}${l10n.dotSeparator}$version',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.style(17, FontWeight.w800),
                      ),
                      Text(
                        document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.style(13, FontWeight.w500, color: BrandColors.slate),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('worksheet-settings'),
                  tooltip: l10n.worksheetSettings,
                  onPressed: () => _SettingsPanel.open(context),
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 21, color: BrandColors.indigo),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFE6E8F0),
              child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: preview),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: BrandColors.line)),
            ),
            child: Row(
              children: [
                Expanded(child: downloadButton),
                const SizedBox(width: 10),
                Expanded(child: printButton),
              ],
            ),
          ),
        ],
      );
    }

    final title = Row(
      children: [
        const IconBadge(icon: LucideIcons.printer, accent: Accent.red),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.worksheetTitle(document.title), style: text.pageTitle(phone: false)),
              const SizedBox(height: 2),
              Text('A4${l10n.dotSeparator}$version', style: text.style(14, FontWeight.w500, color: BrandColors.slate)),
            ],
          ),
        ),
      ],
    );
    final buttons = Wrap(spacing: 10, runSpacing: 10, children: [downloadButton, printButton]);
    // The buttons beside the title on a computer, under it on a tablet.
    final header = LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                buttons,
              ],
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 14), buttons]),
    );

    return PageScroll(
      children: [
        const _BackLink(),
        const SizedBox(height: 8),
        header,
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final settings = SectionCard(title: l10n.worksheetSettings, child: const WorksheetSettings());
            final sheetArea = Container(
              padding: EdgeInsets.all(wide ? 32 : 20),
              decoration: BoxDecoration(color: const Color(0xFFE6E8F0), borderRadius: BorderRadius.circular(AppRadii.card)),
              child: Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: preview),
              ),
            );
            if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [settings, const SizedBox(height: 20), sheetArea]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 380, child: settings),
                const SizedBox(width: 24),
                Expanded(child: sheetArea),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      onPressed: () => _leave(context),
      icon: const Icon(LucideIcons.arrowLeftDir, size: 18, color: BrandColors.indigo),
      label: Text(AppLocalizations.of(context).navContents, style: AppText.of(context).style(14, FontWeight.w700, color: BrandColors.indigo)),
    ),
  );
}

/// The settings in a panel, on a phone.
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  static Future<void> open(BuildContext context) {
    final cubit = context.read<WorksheetCubit>();
    final library = context.read<LibraryCubit>();
    return showSidePanel<void>(
      context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: library),
        ],
        child: const _SettingsPanel(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SidePanel(
      icon: LucideIcons.slidersHorizontal,
      title: l10n.worksheetSettings,
      actions: [PrimaryButton(label: l10n.close, height: 44, onPressed: () => Navigator.of(context).pop())],
      body: const WorksheetSettings(),
    );
  }
}

/// "À partir de", the version, the title, the header and "L'enregistrer dans Contenus".
class WorksheetSettings extends StatelessWidget {
  const WorksheetSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final language = context.watch<LanguageCubit>().state;
    final state = context.watch<WorksheetCubit>().state;
    final cubit = context.read<WorksheetCubit>();
    final document = state.document!;
    final options = state.options;
    final user = context.watch<AuthCubit>().user;
    final quiet = text.style(12.5, FontWeight.w500, color: BrandColors.slate, height: 1.4);
    final label = text.style(14, FontWeight.w700);
    void set(WorksheetOptions value) => cubit.setOptions(value);

    final quiz = state.quiz;
    final facts = quiz == null
        ? tagLabel(l10n, document.tag)
        : '${l10n.questionsCount(quiz.questions.length)}${l10n.dotSeparator}${l10n.pointsCount(quiz.totalPoints)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.worksheetFrom, style: label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
          decoration: BoxDecoration(
            border: Border.all(color: BrandColors.line),
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Row(
            children: [
              IconBadge(icon: quiz == null ? LucideIcons.fileText : LucideIcons.listChecks, size: IconBadgeSize.small),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(document.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.style(14.5, FontWeight.w700)),
                    Text(facts, style: quiet),
                  ],
                ),
              ),
              TextButton(
                key: const Key('worksheet-change'),
                onPressed: () => _chooseSource(context),
                child: Text(l10n.worksheetChange, style: text.style(13.5, FontWeight.w700, color: BrandColors.indigo)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(l10n.worksheetFromHint, style: quiet),
        const SizedBox(height: 18),
        Text(l10n.worksheetVersion, style: label),
        const SizedBox(height: 8),
        SegmentedChoice<bool>(
          key: const Key('worksheet-version'),
          value: options.teacher,
          onChanged: (teacher) => set(options.copyWith(teacher: teacher)),
          options: [SelectOption(false, l10n.worksheetPupil), SelectOption(true, l10n.worksheetTeacher)],
        ),
        const SizedBox(height: 6),
        Text(l10n.worksheetTeacherHint, style: quiet),
        const SizedBox(height: 18),
        FormInput(
          key: const Key('worksheet-title'),
          label: l10n.titleLabel,
          hint: l10n.worksheetTitleHint,
          initialValue: options.title,
          onChanged: (title) => set(options.copyWith(title: title)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in [l10n.worksheetRevision(document.title), l10n.worksheetTest(document.title)])
              _Suggestion(
                label: suggestion,
                onTap: () => set(options.copyWith(title: suggestion)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(l10n.worksheetHeader, style: label),
        const SizedBox(height: 4),
        _Check(
          key: const Key('worksheet-place'),
          label: l10n.worksheetShowPlace,
          value: options.showPlace,
          onChanged: (v) => set(options.copyWith(showPlace: v)),
        ),
        _Check(
          key: const Key('worksheet-date'),
          label: l10n.worksheetShowDate(fullDate(sl.get<Now>()(), language)),
          value: options.showDate,
          onChanged: (v) => set(options.copyWith(showDate: v)),
        ),
        _Check(
          key: const Key('worksheet-teacher'),
          label: l10n.worksheetShowTeacher(user == null ? '' : '${user.firstName} ${user.lastName}'),
          value: options.showTeacher,
          onChanged: (v) => set(options.copyWith(showTeacher: v)),
        ),
        _Check(
          key: const Key('worksheet-name-line'),
          label: quiz == null ? l10n.worksheetShowNameLine : l10n.worksheetShowNameMark,
          value: options.showNameLine,
          onChanged: (v) => set(options.copyWith(showNameLine: v)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: BrandColors.chalk, borderRadius: BorderRadius.circular(AppRadii.tile)),
          child: Row(
            children: [
              BrandSwitch(
                key: const Key('worksheet-save'),
                value: options.saveToLibrary,
                label: l10n.worksheetSave,
                onChanged: (v) => set(options.copyWith(saveToLibrary: v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.worksheetSave, style: text.style(14, FontWeight.w700)),
                    Text(l10n.worksheetSaveHint, style: quiet),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Another page or quiz of the library: the screen opens on it.
  static Future<void> _chooseSource(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final current = context.read<WorksheetCubit>().state.document?.id;
    final documents = context
        .read<LibraryCubit>()
        .state
        .library
        .documents
        .where((d) => (d.kind == FileKind.page || d.kind == FileKind.quiz) && d.status != ContentStatus.archived)
        .toList();
    final chosen = await showAppDialog<ContentDocument>(
      context,
      builder: (dialogContext) => AppDialog(
        icon: LucideIcons.printer,
        title: l10n.worksheetChooseSource,
        content: documents.isEmpty
            ? Text(l10n.worksheetNoSource, style: text.style(14, FontWeight.w500, color: BrandColors.slate))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in documents)
                    ListTile(
                      key: Key('worksheet-source-${d.id}'),
                      selected: d.id == current,
                      leading: Icon(d.kind == FileKind.quiz ? LucideIcons.listChecks : LucideIcons.fileText, color: BrandColors.indigo),
                      title: Text(d.title, style: text.style(14.5, FontWeight.w700)),
                      onTap: () => Navigator.of(dialogContext).pop(d),
                    ),
                ],
              ),
        actions: [GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(dialogContext).pop())],
      ),
    );
    if (chosen == null || chosen.id == current || !context.mounted) return;
    context.go(Routes.teacherWorksheet(chosen.kind, chosen.id));
  }
}

/// "Contrôle : …": a title to start from.
class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 220),
    child: Material(
      color: Accent.indigo.soft,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.of(context).style(12.5, FontWeight.w700, color: BrandColors.indigo),
          ),
        ),
      ),
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    borderRadius: BorderRadius.circular(AppRadii.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(value: value, activeColor: BrandColors.indigo, onChanged: (v) => onChanged(v ?? false)),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: AppText.of(context).style(14, FontWeight.w600))),
        ],
      ),
    ),
  );
}
