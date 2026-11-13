import '../model/content.dart';
import '../model/quiz.dart';

/// Quizzes and QCM (release 3, spec 05). Publishing and archiving are the library's ([ContentRepository]);
/// giving one as homework is the homework's; pictures go through [PageRepository.uploadPicture].
abstract interface class QuizRepository {
  // ── The teacher's builder ──

  /// An empty quiz, a draft, placed as [draft] says; [mcqOnly] from "Créer › QCM".
  Future<Quiz> create(DocumentDraft draft, {bool mcqOnly = false});

  Future<Quiz> quiz(String id);

  /// Settings and questions, whole.
  Future<Quiz> save(String id, QuizSettings settings, List<QuizQuestion> questions);

  /// A new draft with the same settings and questions.
  Future<Quiz> duplicate(String id);

  /// "Aperçu élève": the preview's answers graded with every right answer; nothing is saved.
  Future<List<ReviewItem>> preview(String id, Map<String, QuizAnswer> answers);

  // ── The pupil's side ([studentId] for a parent) ──

  Future<MyQuiz> myQuiz(String assignmentId, {String? studentId});

  /// The open attempt, or a new one.
  Future<AttemptPlay> start(String assignmentId, {String? studentId});

  /// Merged into what was saved. Throws `quiz_time_over` once the time is up (the server sent it).
  Future<void> saveAnswers(String assignmentId, String attemptId, Map<String, QuizAnswer> answers, {String? studentId});

  Future<AttemptReview> submit(String assignmentId, String attemptId, {String? studentId});

  Future<AttemptReview> attempt(String assignmentId, String attemptId, {String? studentId});

  // ── The teacher's correction ──

  Future<QuizCorrection> correction(String assignmentId, String studentId, {String? attemptId});

  /// The open questions' points (half points), by question id, and the comment for the family.
  Future<QuizCorrection> correct(String assignmentId, String studentId, String attemptId, Map<String, double?> scores, String comment);
}
