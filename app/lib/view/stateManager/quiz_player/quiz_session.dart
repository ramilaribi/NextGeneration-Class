import '../../../domain/model/quiz.dart';
import '../../../domain/repositories/quiz_repository.dart';

/// Where a quiz being taken goes: a homework (saved on the server), or the teacher's "Aperçu élève"
/// (nothing saved, graded on demand).
abstract interface class QuizSession {
  /// The attempt to take: the open one, or a new one.
  Future<AttemptPlay> open();

  /// Answers by question id, merged into what was saved.
  Future<void> save(String attemptId, Map<String, QuizAnswer> answers);

  /// Sends the attempt; [answers] is what the player has (the preview grades them).
  Future<AttemptReview> submit(String attemptId, Map<String, QuizAnswer> answers);

  /// The teacher trying her own quiz: nothing is saved.
  bool get preview;
}

/// A quiz given as homework, for the pupil, or a parent for the child ([studentId]).
class HomeworkQuizSession implements QuizSession {
  HomeworkQuizSession(this._quizzes, this.assignmentId, {this.studentId});

  final QuizRepository _quizzes;
  final String assignmentId;
  final String? studentId;

  @override
  bool get preview => false;

  @override
  Future<AttemptPlay> open() => _quizzes.start(assignmentId, studentId: studentId);

  @override
  Future<void> save(String attemptId, Map<String, QuizAnswer> answers) =>
      _quizzes.saveAnswers(assignmentId, attemptId, answers, studentId: studentId);

  @override
  Future<AttemptReview> submit(String attemptId, Map<String, QuizAnswer> answers) =>
      _quizzes.submit(assignmentId, attemptId, studentId: studentId);
}

/// "Aperçu élève": the quiz as a pupil takes it, the timer included; the answers are graded by the server
/// with every right answer, and nothing is kept.
class PreviewQuizSession implements QuizSession {
  PreviewQuizSession(this._quizzes, this.quiz, this._now);

  final QuizRepository _quizzes;
  final Quiz quiz;
  final DateTime Function() _now;

  @override
  bool get preview => true;

  @override
  Future<AttemptPlay> open() async {
    final now = _now();
    final minutes = quiz.settings.timeLimitMin;
    final questions = [...quiz.questions];
    if (quiz.settings.shuffle) questions.shuffle();
    return AttemptPlay(
      id: 'preview',
      number: 1,
      startedAt: now,
      endsAt: minutes == null ? null : now.add(Duration(minutes: minutes)),
      questions: questions,
      pictureUrls: quiz.pictureUrls,
    );
  }

  @override
  Future<void> save(String attemptId, Map<String, QuizAnswer> answers) async {}

  @override
  Future<AttemptReview> submit(String attemptId, Map<String, QuizAnswer> answers) async {
    final items = await _quizzes.preview(quiz.document.id, answers);
    final pending = items.any((i) => i.waiting);
    final auto = items.fold<double>(0, (sum, i) => sum + (i.points ?? 0));
    return AttemptReview(
      id: 'preview',
      number: 1,
      submittedAt: _now(),
      score: pending ? null : auto,
      autoScore: auto,
      maxScore: quiz.totalPoints,
      pending: pending,
      answersShown: true,
      items: items,
      pictureUrls: quiz.pictureUrls,
    );
  }
}
