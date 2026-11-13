import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/tunis_time.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/model/content.dart';
import '../../../domain/model/quiz.dart';
import '../../../domain/repositories/content_repository.dart';
import '../../../domain/repositories/page_repository.dart';
import '../../../domain/repositories/quiz_repository.dart';
import '../common/load_status.dart';
import '../page_editor/page_editor_cubit.dart' show PageSave;

export '../page_editor/page_editor_cubit.dart' show PageSave;

class QuizEditorState extends Equatable {
  const QuizEditorState({
    this.status = LoadStatus.loading,
    this.quiz,
    this.selectedId,
    this.save = PageSave.saved,
    this.savedAt,
    this.publishing = false,
    this.incompleteId,
    this.failure,
    this.saveFailure,
  });

  final LoadStatus status;

  /// As the teacher has it now (saved or about to be).
  final Quiz? quiz;

  /// The question being edited: only it shows its ribbon and its editor.
  final String? selectedId;
  final PageSave save;
  final DateTime? savedAt;
  final bool publishing;

  /// The question "Publier" stopped at: it is not finished.
  final String? incompleteId;

  /// The quiz could not be opened.
  final ApiFailure? failure;

  /// The last save was refused (a locked quiz, for one).
  final ApiFailure? saveFailure;

  bool get unsaved => save != PageSave.saved;

  ContentDocument? get document => quiz?.document;

  QuizEditorState copyWith({
    LoadStatus? status,
    Quiz? quiz,
    String? Function()? selectedId,
    PageSave? save,
    DateTime? savedAt,
    bool? publishing,
    String? Function()? incompleteId,
    ApiFailure? Function()? failure,
    ApiFailure? Function()? saveFailure,
  }) => QuizEditorState(
    status: status ?? this.status,
    quiz: quiz ?? this.quiz,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
    save: save ?? this.save,
    savedAt: savedAt ?? this.savedAt,
    publishing: publishing ?? this.publishing,
    incompleteId: incompleteId != null ? incompleteId() : this.incompleteId,
    failure: failure != null ? failure() : this.failure,
    saveFailure: saveFailure != null ? saveFailure() : this.saveFailure,
  );

  @override
  List<Object?> get props => [status, quiz, selectedId, save, savedAt, publishing, incompleteId, failure?.code, saveFailure?.code];
}

/// The quiz builder (release 3, design `r3/QuizEditeur.png`): every change is saved on its own a moment
/// later, settings and questions whole, like the Word-like page. "Publier" checks each question first.
class QuizEditorCubit extends Cubit<QuizEditorState> {
  QuizEditorCubit(this._quizzes, this._contents, this._pages, this._now, this.id, {this.pause = const Duration(milliseconds: 1200)})
    : super(const QuizEditorState());

  final QuizRepository _quizzes;
  final ContentRepository _contents;
  final PageRepository _pages;
  final Now _now;
  final String id;
  final Duration pause;

  Timer? _timer;
  bool _again = false;
  Future<void>? _sending;
  final _random = Random();

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final quiz = await _quizzes.quiz(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          quiz: quiz,
          selectedId: () => quiz.questions.isEmpty ? null : quiz.questions.first.id,
          savedAt: quiz.document.updatedAt,
        ),
      );
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  /// A new id for a question, a choice or a gap: unique within the quiz.
  String newId(String prefix) => '$prefix${_now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

  // ── Settings ──

  void setSettings(QuizSettings settings) => _change(state.quiz!.copyWith(settings: settings));

  // ── Questions ──

  void select(String? questionId) => emit(state.copyWith(selectedId: () => questionId));

  /// A new question of [type] at the end, selected; a multiple choice starts with two empty choices.
  void addQuestion(QuestionType type) {
    final question = QuizQuestion(
      id: newId('q'),
      type: type,
      choices: type == QuestionType.mcq ? [QuizChoice(id: newId('c')), QuizChoice(id: newId('c'))] : const [],
      points: type == QuestionType.open ? 2 : 1,
    );
    _change(state.quiz!.copyWith(questions: [...state.quiz!.questions, question]), select: question.id);
  }

  /// "Saisie rapide QCM": the questions typed, at the end.
  void addQuestions(List<QuizQuestion> questions) {
    if (questions.isEmpty) return;
    _change(state.quiz!.copyWith(questions: [...state.quiz!.questions, ...questions]), select: questions.first.id);
  }

  void updateQuestion(QuizQuestion question) {
    final list = [for (final q in state.quiz!.questions) q.id == question.id ? question : q];
    final fixed = state.incompleteId == question.id && question.isComplete;
    _change(state.quiz!.copyWith(questions: list), clearIncomplete: fixed);
  }

  void removeQuestion(String questionId) {
    final list = state.quiz!.questions;
    final index = list.indexWhere((q) => q.id == questionId);
    if (index < 0) return;
    final rest = [...list]..removeAt(index);
    final next = rest.isEmpty ? null : rest[index.clamp(0, rest.length - 1)].id;
    _change(state.quiz!.copyWith(questions: rest), select: next, clearIncomplete: state.incompleteId == questionId);
  }

  /// One place up (-1) or down (+1).
  void moveQuestion(String questionId, int by) {
    final list = [...state.quiz!.questions];
    final index = list.indexWhere((q) => q.id == questionId);
    final to = index + by;
    if (index < 0 || to < 0 || to >= list.length) return;
    list.insert(to, list.removeAt(index));
    _change(state.quiz!.copyWith(questions: list));
  }

  /// A copy right after it, with new ids for its choices and gaps.
  void duplicateQuestion(String questionId) {
    final list = [...state.quiz!.questions];
    final index = list.indexWhere((q) => q.id == questionId);
    if (index < 0) return;
    final source = list[index];
    final choiceIds = {for (final c in source.choices) c.id: newId('c')};
    final copy = QuizQuestion(
      id: newId('q'),
      type: source.type,
      points: source.points,
      text: [
        for (final op in source.text)
          if (op['insert'] case {blankEmbed: final Map<String, dynamic> blank})
            {
              ...op,
              'insert': {
                blankEmbed: {...blank, 'id': newId('b')},
              },
            }
          else
            op,
      ],
      explanation: source.explanation,
      choices: [for (final c in source.choices) QuizChoice(id: choiceIds[c.id]!, text: c.text)],
      correct: source.correct == null ? null : choiceIds[source.correct],
      answer: source.answer,
      accepted: source.accepted,
    );
    list.insert(index + 1, copy);
    _change(state.quiz!.copyWith(questions: list), select: copy.id);
  }

  void _change(Quiz quiz, {String? select, bool clearIncomplete = false}) {
    emit(
      state.copyWith(
        quiz: quiz,
        selectedId: select == null ? null : () => select,
        incompleteId: clearIncomplete ? () => null : null,
        saveFailure: () => null,
      ),
    );
    if (state.save == PageSave.saving) {
      _again = true;
      emit(state.copyWith(save: PageSave.saving));
      return;
    }
    emit(state.copyWith(save: PageSave.pending));
    _timer?.cancel();
    _timer = Timer(pause, () => unawaited(_send()));
  }

  // ── Saving ──

  /// Sends what is waiting now (before publishing, previewing, leaving). True when everything is saved.
  Future<bool> flush() async {
    _timer?.cancel();
    if (_sending != null) await _sending;
    if (state.save == PageSave.pending || state.save == PageSave.failed) await _send();
    return state.save == PageSave.saved;
  }

  Future<void> retry() => _send();

  Future<void> _send() {
    final quiz = state.quiz;
    if (quiz == null || isClosed) return Future.value();
    final sending = _sendNow(quiz);
    _sending = sending;
    return sending.whenComplete(() => _sending = null);
  }

  Future<void> _sendNow(Quiz quiz) async {
    _again = false;
    emit(state.copyWith(save: PageSave.saving));
    try {
      final saved = await _quizzes.save(id, quiz.settings, quiz.questions);
      if (isClosed) return;
      // The questions stay as the teacher has them (she may have typed meanwhile); the row and links follow.
      emit(
        state.copyWith(
          quiz: state.quiz!.copyWith(document: saved.document, locked: saved.locked, pictureUrls: {...state.quiz!.pictureUrls, ...saved.pictureUrls}),
          save: _again ? PageSave.pending : PageSave.saved,
          savedAt: _now(),
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(state.copyWith(save: PageSave.failed, saveFailure: () => ApiFailure.from(error)));
      return;
    }
    if (_again) {
      _timer?.cancel();
      _timer = Timer(pause, () => unawaited(_send()));
    }
  }

  /// The picture's id once sent, for a question's text.
  Future<String?> addPicture(PickedFile picture) async {
    final uploaded = await _pages.uploadPicture(picture);
    if (isClosed) return null;
    emit(state.copyWith(quiz: state.quiz!.copyWith(pictureUrls: {...state.quiz!.pictureUrls, uploaded.id: uploaded.url})));
    return uploaded.id;
  }

  /// The first question not finished, selected and marked; null when every one is.
  String? checkComplete() {
    final quiz = state.quiz!;
    final incomplete = quiz.questions.where((q) => !q.isComplete).firstOrNull;
    emit(state.copyWith(incompleteId: () => incomplete?.id, selectedId: incomplete == null ? null : () => incomplete.id));
    return incomplete?.id;
  }

  /// "Publier": every question finished, everything saved, then the quiz leaves the drafts. Null when published.
  Future<ApiFailure?> publish() async {
    final quiz = state.quiz;
    if (quiz == null || state.publishing) return null;
    if (quiz.questions.isEmpty) return const ApiFailure(code: 'quiz_empty');
    if (checkComplete() != null) return const ApiFailure(code: 'quiz_question_incomplete');
    emit(state.copyWith(publishing: true));
    try {
      if (!await flush()) {
        if (!isClosed) emit(state.copyWith(publishing: false));
        return state.saveFailure ?? const ApiFailure(code: ApiFailure.network);
      }
      final document = quiz.document;
      final published = await _contents.update(
        id,
        DocumentDraft(
          title: document.title,
          subjectId: document.subjectId,
          levelId: document.levelId,
          chapterId: document.chapterId,
          tag: document.tag,
        ),
      );
      if (!isClosed) emit(state.copyWith(quiz: state.quiz!.copyWith(document: published), publishing: false));
      return null;
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(publishing: false));
      return ApiFailure.from(error);
    }
  }

  /// "Dupliquer": a new draft; its id to open it.
  Future<String> duplicate() async {
    await flush();
    final copy = await _quizzes.duplicate(id);
    return copy.document.id;
  }

  /// After "Modifier les détails": the row as the server has it now.
  void documentChanged(ContentDocument document) => emit(state.copyWith(quiz: state.quiz!.copyWith(document: document)));

  @override
  Future<void> close() {
    _timer?.cancel();
    final quiz = state.quiz;
    if (state.save == PageSave.pending && quiz != null) {
      unawaited(_quizzes.save(id, quiz.settings, quiz.questions).then((_) {}, onError: (Object _) {}));
    }
    return super.close();
  }
}
