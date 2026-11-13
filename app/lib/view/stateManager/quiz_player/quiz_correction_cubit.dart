import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/model/homework.dart';
import '../../../domain/model/quiz.dart';
import '../../../domain/repositories/quiz_repository.dart';
import '../common/load_status.dart';

class QuizCorrectionState extends Equatable {
  const QuizCorrectionState({
    this.status = LoadStatus.loading,
    this.index = 0,
    this.correction,
    this.scores = const {},
    this.comment = '',
    this.errors = const {},
    this.saving = false,
    this.failure,
  });

  final LoadStatus status;
  final int index;
  final QuizCorrection? correction;

  /// The open questions' points as typed, by question id.
  final Map<String, String> scores;
  final String comment;

  /// Open questions whose points cannot be read (not a number, above the question, not in half points).
  final Set<String> errors;
  final bool saving;
  final ApiFailure? failure;

  AttemptReview? get attempt => correction?.attempt;

  QuizCorrectionState copyWith({
    LoadStatus? status,
    int? index,
    QuizCorrection? correction,
    Map<String, String>? scores,
    String? comment,
    Set<String>? errors,
    bool? saving,
    ApiFailure? Function()? failure,
  }) => QuizCorrectionState(
    status: status ?? this.status,
    index: index ?? this.index,
    correction: correction ?? this.correction,
    scores: scores ?? this.scores,
    comment: comment ?? this.comment,
    errors: errors ?? this.errors,
    saving: saving ?? this.saving,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, index, correction, scores, comment, errors, saving, failure?.code];
}

/// A pupil's quiz for the teacher: every answer, the open questions to score in half points, a comment for
/// the family; "Enregistrer et suivant" goes through the copies waiting.
class QuizCorrectionCubit extends Cubit<QuizCorrectionState> {
  QuizCorrectionCubit(this._quizzes, this.assignmentId, this.copies, {int index = 0}) : super(QuizCorrectionState(index: index));

  final QuizRepository _quizzes;
  final String assignmentId;

  /// The pupils to go through (the one opened first).
  final List<RecipientRow> copies;

  String get studentId => copies[state.index].studentId;

  Future<void> load({String? attemptId}) async {
    if (copies.isEmpty) return;
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final correction = await _quizzes.correction(assignmentId, studentId, attemptId: attemptId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          correction: correction,
          scores: _typed(correction.attempt),
          comment: correction.comment ?? '',
          errors: const {},
        ),
      );
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  static Map<String, String> _typed(AttemptReview? review) => {
    for (final item in review?.items ?? const <ReviewItem>[])
      if (item.question.type == QuestionType.open) item.question.id: item.points == null ? '' : _text(item.points!),
  };

  static String _text(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value'.replaceAll('.', ',');

  Future<void> go(int index) async {
    if (index < 0 || index >= copies.length) return;
    emit(state.copyWith(index: index));
    await load();
  }

  Future<void> showAttempt(String attemptId) => load(attemptId: attemptId);

  void setScore(String questionId, String value) =>
      emit(state.copyWith(scores: {...state.scores, questionId: value}, errors: state.errors.difference({questionId})));

  void setComment(String value) => emit(state.copyWith(comment: value));

  /// Saved; true when it went through. An empty field leaves the question waiting.
  Future<bool> save() async {
    final review = state.attempt;
    if (review == null || state.saving) return false;
    final max = {for (final i in review.items) i.question.id: i.maxPoints};
    final scores = <String, double?>{};
    final errors = <String>{};
    for (final e in state.scores.entries) {
      final typed = e.value.trim().replaceAll(',', '.');
      if (typed.isEmpty) {
        scores[e.key] = null;
        continue;
      }
      final value = double.tryParse(typed);
      if (value == null || value < 0 || value > (max[e.key] ?? 0) || (value * 2) != (value * 2).roundToDouble()) {
        errors.add(e.key);
      } else {
        scores[e.key] = value;
      }
    }
    if (errors.isNotEmpty) {
      emit(state.copyWith(errors: errors));
      return false;
    }
    emit(state.copyWith(saving: true, failure: () => null));
    try {
      final saved = await _quizzes.correct(assignmentId, studentId, review.id, scores, state.comment);
      if (isClosed) return false;
      emit(state.copyWith(saving: false, correction: saved, scores: _typed(saved.attempt), comment: saved.comment ?? ''));
      return true;
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(saving: false, failure: () => ApiFailure.from(error)));
      return false;
    }
  }
}
