import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/tunis_time.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../domain/model/quiz.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stateManager/common/load_status.dart';
import '../../../stateManager/quiz_player/quiz_player_cubit.dart';
import '../../../stateManager/quiz_player/quiz_session.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/feedback.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/quiz_widgets.dart';
import 'quiz_question_view.dart';
import 'quiz_review_view.dart';

/// Below this width, one question per screen (design `r3/SeriesQuizPhone.png`); above, all on one page.
const _oneByOne = 720.0;

/// Taking a quiz (release 3): the pupil (or a parent for the child) answers, every answer is saved at once,
/// the timer sends it at zero, and the grade shows right away. Also the teacher's "Aperçu élève".
class QuizPlayerScreen extends StatelessWidget {
  const QuizPlayerScreen({super.key, required this.session, required this.title, this.name});

  final QuizSession session;
  final String title;

  /// The pupil's first name for "Bien joué, Adam !".
  final String? name;

  /// A quiz homework, full screen; true once something was sent (the homework page reloads).
  static Future<bool> open(BuildContext context, {required String assignmentId, required String title, String? studentId, String? name}) async {
    final sent = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QuizPlayerScreen(
          session: HomeworkQuizSession(sl.get(), assignmentId, studentId: studentId),
          title: title,
          name: name,
        ),
      ),
    );
    return sent ?? false;
  }

  /// "Aperçu élève": the teacher takes her quiz as a pupil would; nothing is saved.
  static Future<void> preview(BuildContext context, Quiz quiz) => Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuizPlayerScreen(session: PreviewQuizSession(sl.get(), quiz, sl.get<Now>()), title: quiz.document.title),
    ),
  );

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => QuizPlayerCubit(session)..load(),
    child: _PlayerView(title: title, name: name),
  );
}

class _PlayerView extends StatefulWidget {
  const _PlayerView({required this.title, required this.name});

  final String title;
  final String? name;

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView> {
  Timer? _clock;
  Duration? _left;

  QuizPlayerCubit get _cubit => context.read<QuizPlayerCubit>();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// The timer: at zero, the quiz is sent with what was answered (the server checks it too).
  void _tick() {
    final state = _cubit.state;
    final ends = state.attempt?.endsAt;
    if (ends == null || state.review != null) return;
    final left = ends.difference(sl.get<Now>()());
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left <= Duration.zero && !state.submitting) unawaited(_send(confirm: false));
  }

  Future<void> _send({bool confirm = true}) async {
    final l10n = AppLocalizations.of(context);
    final state = _cubit.state;
    final missing = state.questions.length - state.answeredCount;
    if (confirm) {
      final ok = await showAppDialog<bool>(
        context,
        builder: (dialogContext) => AppDialog(
          icon: LucideIcons.send,
          title: l10n.sendQuizTitle,
          subtitle: missing == 0 ? l10n.sendQuizAll : l10n.sendQuizMissing(missing),
          actions: [
            GhostButton(label: l10n.cancel, onPressed: () => Navigator.of(dialogContext).pop(false)),
            PrimaryButton(label: l10n.sendQuiz, icon: LucideIcons.send, height: 44, onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final failure = await _cubit.submit();
    if (failure != null && mounted) showNotice(context, failureText(l10n, failure));
  }

  Future<void> _close() async {
    final l10n = AppLocalizations.of(context);
    final state = _cubit.state;
    final navigator = Navigator.of(context);
    if (state.review != null || state.attempt == null) {
      navigator.pop(state.review != null);
      return;
    }
    final leave = await confirmAction(
      context,
      title: l10n.leaveQuizTitle,
      text: _cubit.preview ? l10n.leavePreviewText : l10n.leaveQuizText,
      confirmLabel: l10n.leaveQuiz,
      icon: LucideIcons.logOut,
      danger: false,
    );
    if (leave) navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final state = context.watch<QuizPlayerCubit>().state;
    final width = MediaQuery.sizeOf(context).width;
    final oneByOne = width < _oneByOne;
    final review = state.review;
    final preview = _cubit.preview;
    // The timer shows from the first frame, then every second.
    final ends = state.attempt?.endsAt;
    if (_left == null && ends != null) {
      final left = ends.difference(sl.get<Now>()());
      _left = left.isNegative ? Duration.zero : left;
    }

    final header = Container(
      padding: EdgeInsetsDirectional.fromSTEB(oneByOne ? 12 : 24, 12, oneByOne ? 12 : 24, 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: BrandColors.line))),
      child: Row(
        children: [
          IconSquareButton(icon: review == null ? LucideIcons.x : LucideIcons.arrowLeftDir, tooltip: l10n.close, onPressed: _close),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.style(oneByOne ? 16 : 18, FontWeight.w800)),
                if (review == null && state.questions.isNotEmpty)
                  Text(
                    oneByOne ? l10n.questionOf(state.index + 1, state.questions.length) : l10n.questionsCount(state.questions.length),
                    style: text.style(13, FontWeight.w500, color: BrandColors.slate),
                  ),
              ],
            ),
          ),
          if (preview) ...[const SizedBox(width: 8), _Pill(label: l10n.studentPreview, accent: Accent.violet)],
          if (review == null && _left != null) ...[const SizedBox(width: 8), _TimerPill(left: _left!)],
        ],
      ),
    );

    final Widget body;
    if (state.status == LoadStatus.failure && state.attempt == null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(24), child: FailureBanner(state.failure!, onRetry: _cubit.load)));
    } else if (state.attempt == null) {
      body = const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(minHeight: 3));
    } else if (review != null) {
      body = SingleChildScrollView(
        padding: EdgeInsets.all(oneByOne ? 16 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AttemptScoreCard(review: review, name: widget.name),
                if (!review.answersShown) ...[const SizedBox(height: 12), InfoNoteText(l10n.answersLaterNote)],
                const SizedBox(height: 12),
                AttemptItemsView(review: review),
              ],
            ),
          ),
        ),
      );
    } else if (oneByOne) {
      final q = state.current!;
      body = Column(
        children: [
          _Progress(state: state),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.upper('${questionTypeLabel(l10n, q.type)}${l10n.dotSeparator}${pointsLabel(l10n, q.points)}'),
                    style: text.overline(size: 12, color: BrandColors.slate),
                  ),
                  const SizedBox(height: 10),
                  QuizQuestionView(
                    key: ValueKey(q.id),
                    question: q,
                    answer: state.answers[q.id],
                    pictureUrls: state.attempt!.pictureUrls,
                    enabled: !state.submitting,
                    onChoose: (a) => _cubit.choose(q.id, a),
                    onType: (a) => _cubit.type(q.id, a),
                  ),
                  const SizedBox(height: 14),
                  _SavedLine(state: state, questionId: q.id),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < state.questions.length; i++) ...[
                  _WideQuestion(number: i + 1, question: state.questions[i], state: state),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final Widget? footer;
    if (state.attempt == null) {
      footer = null;
    } else if (review != null) {
      footer = _Footer(child: PrimaryButton(label: l10n.close, height: 52, onPressed: () => Navigator.of(context).pop(true)));
    } else if (oneByOne) {
      final last = state.index == state.questions.length - 1;
      footer = _Footer(
        child: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: l10n.prevQuestion,
                height: 52,
                onPressed: state.index == 0 ? null : () => _cubit.goTo(state.index - 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: last
                  ? PrimaryButton(key: const Key('quiz-send'), label: l10n.sendQuiz, icon: LucideIcons.send, height: 52, loading: state.submitting, onPressed: _send)
                  : PrimaryButton(key: const Key('quiz-next'), label: l10n.nextQuestion, height: 52, onPressed: () => _cubit.goTo(state.index + 1)),
            ),
          ],
        ),
      );
    } else {
      footer = _Footer(
        child: Row(
          children: [
            Expanded(child: _SavedLine(state: state)),
            PrimaryButton(key: const Key('quiz-send'), label: l10n.sendQuiz, icon: LucideIcons.send, height: 48, loading: state.submitting, onPressed: _send),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: BrandColors.chalk,
        body: SafeArea(
          child: Column(
            children: [
              header,
              Expanded(child: body),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: BrandColors.line))),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child)),
  );
}

/// One segment per question: answered, the one shown, or still to do.
class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final QuizPlayerState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuizPlayerCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < state.questions.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => cubit.goTo(i),
                child: Container(
                  height: 6,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == state.index
                        ? const Color(0xFF8E9BD8)
                        : (state.isAnswered(state.questions[i]) ? BrandColors.indigo : const Color(0xFFDCE0F0)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Réponse enregistrée" under the question just answered; "pas enregistrée" without network.
class _SavedLine extends StatelessWidget {
  const _SavedLine({required this.state, this.questionId});

  final QuizPlayerState state;
  final String? questionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    if (state.saveFailed) {
      return Row(
        children: [
          Icon(LucideIcons.cloudOff, size: 15, color: Accent.red.onSoft),
          const SizedBox(width: 6),
          Flexible(child: Text(l10n.answerNotSaved, style: text.style(13, FontWeight.w600, color: Accent.red.onSoft))),
        ],
      );
    }
    final id = questionId;
    final saved = id == null ? state.lastSaved != null && state.unsaved.isEmpty : !state.unsaved.contains(id) && state.answers.containsKey(id);
    if (!saved) return const SizedBox(height: 18);
    return Row(
      children: [
        Icon(LucideIcons.check, size: 15, color: Accent.green.onSoft),
        const SizedBox(width: 6),
        Text(l10n.answerSaved, style: text.style(13, FontWeight.w600, color: Accent.green.onSoft)),
      ],
    );
  }
}

class _WideQuestion extends StatelessWidget {
  const _WideQuestion({required this.number, required this.question, required this.state});

  final int number;
  final QuizQuestion question;
  final QuizPlayerState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = AppText.of(context);
    final cubit = context.read<QuizPlayerCubit>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: state.isAnswered(question) ? const Color(0xFFC9CFEF) : BrandColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              QuestionNumber(number),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.upper('${questionTypeLabel(l10n, question.type)}${l10n.dotSeparator}${pointsLabel(l10n, question.points)}'),
                  style: text.overline(size: 11.5, color: BrandColors.slate),
                ),
              ),
              if (state.isAnswered(question) && !state.unsaved.contains(question.id))
                Icon(LucideIcons.check, size: 16, color: Accent.green.onSoft),
            ],
          ),
          const SizedBox(height: 12),
          QuizQuestionView(
            key: ValueKey(question.id),
            question: question,
            answer: state.answers[question.id],
            pictureUrls: state.attempt!.pictureUrls,
            enabled: !state.submitting,
            onChoose: (a) => cubit.choose(question.id, a),
            onType: (a) => cubit.type(question.id, a),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.accent});

  final String label;
  final Accent accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(AppRadii.pill)),
    child: Text(label, style: AppText.of(context).style(12.5, FontWeight.w700, color: accent.onSoft)),
  );
}

/// "11:42" in amber; red in the last minute.
class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = left.inMinutes;
    final seconds = left.inSeconds % 60;
    final label = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final accent = left.inSeconds <= 60 ? Accent.red : Accent.amber;
    return Semantics(
      label: l10n.timeLeft(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(AppRadii.pill)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.timer, size: 15, color: accent.onSoft),
              const SizedBox(width: 6),
              Text(label, key: const Key('quiz-timer'), style: AppText.of(context).style(14, FontWeight.w800, color: accent.onSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short note in the grey-blue box.
class InfoNoteText extends StatelessWidget {
  const InfoNoteText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: BrandColors.indigoSoft, borderRadius: BorderRadius.circular(AppRadii.md)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.info, size: 16, color: BrandColors.indigo),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.of(context).style(13.5, FontWeight.w500, color: BrandColors.indigo, height: 1.4))),
      ],
    ),
  );
}
