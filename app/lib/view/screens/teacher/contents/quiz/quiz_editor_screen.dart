import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/l10n/formatting.dart';
import '../../../../../core/l10n/tunis_time.dart';
import '../../../../../core/network/api_failure.dart';
import '../../../../../core/router/routes.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/theme/brand_colors.dart';
import '../../../../../domain/model/content.dart';
import '../../../../../domain/model/quiz.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../stateManager/common/load_status.dart';
import '../../../../stateManager/library/library_cubit.dart';
import '../../../../stateManager/quiz_editor/quiz_editor_cubit.dart';
import '../../../../widgets/buttons.dart';
import '../../../../widgets/cards.dart';
import '../../../../widgets/content_widgets.dart';
import '../../../../widgets/feedback.dart';
import '../../../../widgets/page_frame.dart';
import '../../../../widgets/panels.dart';
import '../../../../widgets/quiz_widgets.dart';
import '../../../shared/quiz/quiz_player_screen.dart';
import '../../homework/assign_panel.dart';
import '../document_form_panel.dart';
import 'quick_qcm_panel.dart';
import 'quiz_question_card.dart';
import 'quiz_settings_card.dart';

/// The quiz builder (release 3, designs `r3/QuizEditeur.png` and `r3/QuizSaisieRapide.png`): settings,
/// the questions of five types, "Saisie rapide QCM", "Aperçu élève", then "Publier" and "Donner en devoir".
class QuizEditorScreen extends StatelessWidget {
  const QuizEditorScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => QuizEditorCubit(sl.get(), sl.get(), sl.get(), sl.get<Now>(), quizId)..load()),
      // The chapter's title in the settings, and "Modifier les détails".
      BlocProvider(create: (_) => sl.get<LibraryCubit>()..load()),
    ],
    child: const _QuizEditorView(),
  );
}

class _QuizEditorView extends StatelessWidget {
  const _QuizEditorView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<QuizEditorCubit>().state;
    if (state.quiz == null) {
      return PageScroll(
        children: [
          const _BackLink(),
          if (state.status == LoadStatus.failure && state.failure != null)
            FailureBanner(state.failure!, onRetry: context.read<QuizEditorCubit>().load)
          else
            const LinearProgressIndicator(minHeight: 3),
        ],
      );
    }
    return const _Editor();
  }
}

void _leave(BuildContext context) => context.canPop() ? Navigator.of(context).maybePop() : context.go(Routes.teacherContents);

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

class _Editor extends StatelessWidget {
  const _Editor();

  QuizEditorCubit _cubit(BuildContext context) => context.read<QuizEditorCubit>();

  Future<void> _quickEntry(BuildContext context) async {
    final cubit = _cubit(context);
    final questions = await QuickQcmPanel.open(context, firstNumber: cubit.state.quiz!.questions.length + 1, newId: cubit.newId);
    if (questions != null && questions.isNotEmpty && !cubit.isClosed) cubit.addQuestions(questions);
  }

  Future<void> _preview(BuildContext context) async {
    final cubit = _cubit(context);
    final l10n = AppLocalizations.of(context);
    if (cubit.state.quiz!.questions.isEmpty) {
      showNotice(context, l10n.quizEmptyError);
      return;
    }
    await cubit.flush();
    if (!context.mounted) return;
    await QuizPlayerScreen.preview(context, cubit.state.quiz!);
  }

  Future<void> _editDetails(BuildContext context) async {
    final cubit = _cubit(context);
    final document = cubit.state.document;
    if (document == null) return;
    final saved = await DocumentFormPanel.edit(context, document);
    if (saved != null && !cubit.isClosed) cubit.documentChanged(saved);
  }

  Future<void> _duplicate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    try {
      final id = await _cubit(context).duplicate();
      if (!context.mounted) return;
      showNotice(context, l10n.quizDuplicated);
      router.pushReplacement(Routes.teacherQuiz(id));
    } on Object catch (error) {
      if (context.mounted) showNotice(context, failureText(l10n, ApiFailure.from(error)));
    }
  }

  /// "Publier" (every question checked first), then "Donner en devoir".
  Future<void> _publish(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = _cubit(context);
    if (!(cubit.state.document?.published ?? false)) {
      final failure = await cubit.publish();
      if (!context.mounted) return;
      if (failure != null) {
        showNotice(context, switch (failure.code) {
          'quiz_empty' => l10n.quizEmptyError,
          'quiz_question_incomplete' => l10n.quizIncompleteError,
          _ => failureText(l10n, failure),
        });
        return;
      }
      showNotice(context, l10n.quizPublished);
    }
    final document = cubit.state.document;
    if (document == null || !context.mounted) return;
    final given = await AssignPanel.open(context, contentItemId: document.id);
    if (given != null && context.mounted) showNotice(context, l10n.homeworkGiven);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = isPhone(context);
    final state = context.watch<QuizEditorCubit>().state;
    final quiz = state.quiz!;
    final actions = _Actions(
      onQuick: () => _quickEntry(context),
      onPreview: () => _preview(context),
      onPublish: () => _publish(context),
      onEditDetails: () => _editDetails(context),
      onDuplicate: () => _duplicate(context),
    );
    final settings = QuizSettingsCard(onEditPlace: () => _editDetails(context));
    final questions = _Questions(quiz: quiz, state: state);

    final Widget body;
    if (phone) {
      body = Column(
        children: [
          _PhoneHeader(document: quiz.document, actions: actions),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
              children: [
                if (quiz.locked) ...[_LockedNote(onDuplicate: actions.onDuplicate), const SizedBox(height: 12)],
                settings,
                const SizedBox(height: 16),
                questions,
              ],
            ),
          ),
        ],
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BackLink(),
                const SizedBox(height: 8),
                _WideHeader(document: quiz.document, actions: actions),
                const SizedBox(height: 22),
                if (quiz.locked) ...[_LockedNote(onDuplicate: actions.onDuplicate), const SizedBox(height: 16)],
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 860) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [settings, const SizedBox(height: 18), questions]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 360, child: settings),
                        const SizedBox(width: 24),
                        Expanded(child: questions),
                      ],
                    );
                  },
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
          text: l10n.unsavedQuizText,
          confirmLabel: l10n.leaveWithoutSaving,
        );
        if (leave) navigator.pop();
      },
      child: body,
    );
  }
}

class _Actions {
  const _Actions({required this.onQuick, required this.onPreview, required this.onPublish, required this.onEditDetails, required this.onDuplicate});

  final VoidCallback onQuick;
  final VoidCallback onPreview;
  final VoidCallback onPublish;
  final VoidCallback onEditDetails;
  final VoidCallback onDuplicate;
}

/// "Brouillon · enregistré à l'instant".
class _Facts extends StatelessWidget {
  const _Facts({required this.document});

  final ContentDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<QuizEditorCubit>().state;
    final quiet = text.style(13, FontWeight.w500, color: BrandColors.slate);
    final savedAt = state.savedAt;
    final saved = switch (state.save) {
      PageSave.pending || PageSave.saving => l10n.pageSaving,
      PageSave.failed => state.saveFailure?.code == 'quiz_locked' ? l10n.quizLockedShort : l10n.pageNotSaved,
      PageSave.saved => savedAt == null || sl.get<Now>()().difference(savedAt).inSeconds < 60 ? l10n.pageSavedNow : l10n.pageSavedAt(hm(savedAt)),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DocumentStatusChip(document.status),
        Text(saved, key: const Key('quiz-facts'), style: state.save == PageSave.failed ? quiet.copyWith(color: Accent.red.onSoft) : quiet),
        if (state.save == PageSave.failed)
          TextButton(
            onPressed: context.read<QuizEditorCubit>().retry,
            child: Text(l10n.retry, style: text.style(13, FontWeight.w700, color: BrandColors.indigo)),
          ),
      ],
    );
  }
}

class _WideHeader extends StatelessWidget {
  const _WideHeader({required this.document, required this.actions});

  final ContentDocument document;
  final _Actions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<QuizEditorCubit>().state;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(icon: LucideIcons.listChecks, accent: Accent.violet),
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
            _MoreMenu(actions: actions),
            if (!(state.quiz?.locked ?? false))
              SecondaryButton(key: const Key('quiz-quick'), label: l10n.quickQcmTitle, icon: LucideIcons.zap, onPressed: actions.onQuick),
            SecondaryButton(key: const Key('quiz-preview'), label: l10n.studentPreview, icon: LucideIcons.eye, onPressed: actions.onPreview),
            PrimaryButton(
              key: const Key('quiz-publish'),
              label: document.published ? l10n.giveAsHomework : l10n.publish,
              icon: document.published ? LucideIcons.clipboardList : LucideIcons.check,
              height: 44,
              loading: state.publishing,
              onPressed: actions.onPublish,
            ),
          ],
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.actions, this.phone = false});

  final _Actions actions;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locked = context.select((QuizEditorCubit c) => c.state.quiz?.locked ?? false);
    return MenuAnchor(
      menuChildren: [
        if (phone && !locked)
          MenuItemButton(leadingIcon: const Icon(LucideIcons.zap, size: 18), onPressed: actions.onQuick, child: Text(l10n.quickQcmTitle)),
        if (phone)
          MenuItemButton(leadingIcon: const Icon(LucideIcons.eye, size: 18), onPressed: actions.onPreview, child: Text(l10n.studentPreview)),
        MenuItemButton(leadingIcon: const Icon(LucideIcons.pencil, size: 18), onPressed: actions.onEditDetails, child: Text(l10n.actionEditDetails)),
        MenuItemButton(leadingIcon: const Icon(LucideIcons.copy, size: 18), onPressed: actions.onDuplicate, child: Text(l10n.duplicateQuiz)),
      ],
      builder: (context, menu, _) => phone
          ? IconButton(
              tooltip: l10n.documentActions,
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(LucideIcons.ellipsisVertical, size: 20, color: BrandColors.ink),
            )
          : IconSquareButton(
              icon: LucideIcons.ellipsis,
              tooltip: l10n.documentActions,
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
    );
  }
}

class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader({required this.document, required this.actions});

  final ContentDocument document;
  final _Actions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<QuizEditorCubit>().state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                _Facts(document: document),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const Key('quiz-publish'),
            label: document.published ? l10n.giveShort : l10n.publish,
            height: 40,
            loading: state.publishing,
            onPressed: actions.onPublish,
          ),
          _MoreMenu(actions: actions, phone: true),
        ],
      ),
    );
  }
}

class _LockedNote extends StatelessWidget {
  const _LockedNote({required this.onDuplicate});

  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Accent.amber.soft, borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.lock, size: 16, color: Accent.amber.onSoft),
              const SizedBox(width: 8),
              Flexible(child: Text(l10n.quizLockedNote, style: AppText.of(context).style(13.5, FontWeight.w600, color: Accent.amber.onSoft))),
            ],
          ),
          TonalButton(label: l10n.duplicateQuiz, icon: LucideIcons.copy, onPressed: onDuplicate),
        ],
      ),
    );
  }
}

/// The question cards, then the bar that adds one of each type (a QCM offers multiple choice only).
class _Questions extends StatelessWidget {
  const _Questions({required this.quiz, required this.state});

  final Quiz quiz;
  final QuizEditorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final cubit = context.read<QuizEditorCubit>();
    final types = quiz.mcqOnly ? const [QuestionType.mcq] : QuestionType.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quiz.questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: BrandColors.line),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.listChecks, size: 30, color: BrandColors.slate),
                const SizedBox(height: 10),
                Text(l10n.quizNoQuestion, textAlign: TextAlign.center, style: text.style(16, FontWeight.w700)),
                const SizedBox(height: 4),
                Text(quiz.mcqOnly ? l10n.qcmNoQuestionHint : l10n.quizNoQuestionHint, textAlign: TextAlign.center, style: text.small),
              ],
            ),
          ),
        for (var i = 0; i < quiz.questions.length; i++) ...[
          QuizQuestionCard(
            key: ValueKey(quiz.questions[i].id),
            question: quiz.questions[i],
            number: i + 1,
            count: quiz.questions.length,
            selected: state.selectedId == quiz.questions[i].id,
            locked: quiz.locked,
            incomplete: state.incompleteId == quiz.questions[i].id,
          ),
          const SizedBox(height: 12),
        ],
        if (!quiz.locked)
          DottedBox(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in types)
                  _AddButton(type: type, onPressed: () => cubit.addQuestion(type)),
              ],
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.type, required this.onPressed});

  final QuestionType type;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        key: Key('add-${type.name}'),
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: BrandColors.line)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuestionTypeSquare(type, size: 24),
              const SizedBox(width: 8),
              Text(questionTypeLabel(l10n, type), style: AppText.of(context).style(14, FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed box around the add bar (design: "+ a type").
class DottedBox extends StatelessWidget {
  const DottedBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorder(),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9CDE0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadii.tile)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
