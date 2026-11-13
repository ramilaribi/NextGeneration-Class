import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/model/quiz.dart';
import '../common/load_status.dart';
import 'quiz_session.dart';

class QuizPlayerState extends Equatable {
  const QuizPlayerState({
    this.status = LoadStatus.loading,
    this.attempt,
    this.answers = const {},
    this.index = 0,
    this.unsaved = const {},
    this.lastSaved,
    this.submitting = false,
    this.review,
    this.failure,
    this.saveFailed = false,
  });

  final LoadStatus status;
  final AttemptPlay? attempt;

  /// What the pupil has answered, by question id.
  final Map<String, QuizAnswer> answers;

  /// The question shown on a phone.
  final int index;

  /// Answers not saved yet (waiting or failed), by question id.
  final Set<String> unsaved;

  /// The question whose answer was saved last: "Réponse enregistrée" under it.
  final String? lastSaved;
  final bool submitting;

  /// Once sent: the grade and each question.
  final AttemptReview? review;
  final ApiFailure? failure;

  /// The last save did not reach the server (no network): it is sent again with the next answer.
  final bool saveFailed;

  List<QuizQuestion> get questions => attempt?.questions ?? const [];

  QuizQuestion? get current => index < questions.length ? questions[index] : null;

  int get answeredCount => questions.where((q) => isAnswered(q)).length;

  bool isAnswered(QuizQuestion q) {
    final a = answers[q.id];
    if (a == null) return false;
    return switch (q.type) {
      QuestionType.mcq => a['choice'] is String,
      QuestionType.trueFalse => a['value'] is bool,
      QuestionType.short || QuestionType.open => '${a['text'] ?? ''}'.trim().isNotEmpty,
      QuestionType.blanks => (a['blanks'] as Map? ?? const {}).values.any((v) => '$v'.trim().isNotEmpty),
    };
  }

  QuizPlayerState copyWith({
    LoadStatus? status,
    AttemptPlay? attempt,
    Map<String, QuizAnswer>? answers,
    int? index,
    Set<String>? unsaved,
    String? Function()? lastSaved,
    bool? submitting,
    AttemptReview? review,
    ApiFailure? Function()? failure,
    bool? saveFailed,
  }) => QuizPlayerState(
    status: status ?? this.status,
    attempt: attempt ?? this.attempt,
    answers: answers ?? this.answers,
    index: index ?? this.index,
    unsaved: unsaved ?? this.unsaved,
    lastSaved: lastSaved != null ? lastSaved() : this.lastSaved,
    submitting: submitting ?? this.submitting,
    review: review ?? this.review,
    failure: failure != null ? failure() : this.failure,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  List<Object?> get props => [status, attempt, answers, index, unsaved, lastSaved, submitting, review, failure?.code, saveFailed];
}

/// A quiz being taken (design `r3/SeriesQuizPhone.png`): each answer is saved at once (typed answers a
/// moment after the last key), the timer sends it at zero, and the grade comes back right away.
class QuizPlayerCubit extends Cubit<QuizPlayerState> {
  QuizPlayerCubit(this._session, {this.typingPause = const Duration(milliseconds: 700)}) : super(const QuizPlayerState());

  final QuizSession _session;

  /// How long after the last key a typed answer is sent.
  final Duration typingPause;

  Timer? _typing;
  Future<void>? _saving;

  bool get preview => _session.preview;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final attempt = await _session.open();
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.ready, attempt: attempt, answers: attempt.answers));
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  void goTo(int index) {
    if (index < 0 || index >= state.questions.length) return;
    emit(state.copyWith(index: index));
  }

  /// A choice or true / false: saved at once.
  void choose(String questionId, QuizAnswer answer) {
    _set(questionId, answer);
    unawaited(_saveNow());
  }

  /// A typed answer (short, open, a gap): saved when the pupil stops typing.
  void type(String questionId, QuizAnswer answer) {
    _set(questionId, answer);
    _typing?.cancel();
    _typing = Timer(typingPause, () => unawaited(_saveNow()));
  }

  void _set(String questionId, QuizAnswer answer) {
    if (state.review != null) return;
    emit(state.copyWith(answers: {...state.answers, questionId: answer}, unsaved: {...state.unsaved, questionId}));
  }

  Future<void> _saveNow() async {
    if (_saving != null) await _saving;
    final attempt = state.attempt;
    final ids = state.unsaved;
    if (attempt == null || ids.isEmpty || isClosed || state.review != null) return;
    final batch = {for (final id in ids) id: state.answers[id] ?? <String, dynamic>{}};
    final saving = _send(attempt.id, batch);
    _saving = saving;
    await saving.whenComplete(() => _saving = null);
  }

  Future<void> _send(String attemptId, Map<String, QuizAnswer> batch) async {
    try {
      await _session.save(attemptId, batch);
      if (isClosed) return;
      // Only what was sent unchanged since leaves the unsaved set.
      final still = {
        for (final id in state.unsaved)
          if (!batch.containsKey(id) || state.answers[id] != batch[id]) id,
      };
      emit(state.copyWith(unsaved: still, lastSaved: () => batch.keys.last, saveFailed: false));
    } on Object catch (error) {
      if (isClosed) return;
      final failure = ApiFailure.from(error);
      // The time was up: the server sent the quiz with what it had.
      if (failure.code == 'quiz_time_over' || failure.code == 'quiz_already_sent') {
        await _finish();
        return;
      }
      emit(state.copyWith(saveFailed: true));
    }
  }

  /// "Envoyer", or the timer at zero: what is left is saved, then the quiz is sent and graded.
  Future<ApiFailure?> submit() async {
    final attempt = state.attempt;
    if (attempt == null || state.submitting || state.review != null) return null;
    _typing?.cancel();
    emit(state.copyWith(submitting: true));
    await _saveNow();
    if (isClosed) return null;
    if (state.review != null) return null;
    return _finish();
  }

  Future<ApiFailure?> _finish() async {
    final attempt = state.attempt;
    if (attempt == null) return null;
    emit(state.copyWith(submitting: true));
    try {
      final review = await _session.submit(attempt.id, state.answers);
      if (!isClosed) emit(state.copyWith(review: review, submitting: false, unsaved: const {}));
      return null;
    } on Object catch (error) {
      final failure = ApiFailure.from(error);
      if (!isClosed) emit(state.copyWith(submitting: false, failure: () => failure));
      return failure;
    }
  }

  @override
  Future<void> close() {
    _typing?.cancel();
    // Leaving sends what was typed last; the attempt stays open to come back to.
    final attempt = state.attempt;
    if (attempt != null && state.unsaved.isNotEmpty && state.review == null) {
      final batch = {for (final id in state.unsaved) id: state.answers[id] ?? <String, dynamic>{}};
      unawaited(_session.save(attempt.id, batch).then((_) {}, onError: (Object _) {}));
    }
    return super.close();
  }
}
