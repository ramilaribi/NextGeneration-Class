import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/model/quiz.dart';
import '../../../domain/repositories/quiz_repository.dart';
import '../common/load_status.dart';

class MyQuizState extends Equatable {
  const MyQuizState({this.status = LoadStatus.loading, this.quiz, this.failure});

  final LoadStatus status;
  final MyQuiz? quiz;
  final ApiFailure? failure;

  @override
  List<Object?> get props => [status, quiz, failure?.code];
}

/// A quiz homework for the pupil or the parent: what it is, the attempts and their grades, start or go on.
class MyQuizCubit extends Cubit<MyQuizState> {
  MyQuizCubit(this._quizzes, this.assignmentId, {this.studentId}) : super(const MyQuizState());

  final QuizRepository _quizzes;
  final String assignmentId;
  final String? studentId;

  Future<void> load() async {
    emit(MyQuizState(status: LoadStatus.loading, quiz: state.quiz));
    try {
      final quiz = await _quizzes.myQuiz(assignmentId, studentId: studentId);
      if (!isClosed) emit(MyQuizState(status: LoadStatus.ready, quiz: quiz));
    } on Object catch (error) {
      if (!isClosed) emit(MyQuizState(status: LoadStatus.failure, quiz: state.quiz, failure: ApiFailure.from(error)));
    }
  }

  /// An attempt sent, with its questions.
  Future<AttemptReview> attempt(String attemptId) => _quizzes.attempt(assignmentId, attemptId, studentId: studentId);
}
