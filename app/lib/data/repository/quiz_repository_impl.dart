import '../../core/config/app_config.dart';
import '../../domain/model/content.dart';
import '../../domain/model/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../dto/content_dto.dart';
import '../dto/quiz_dto.dart';
import '../dto/school_dto.dart';
import '../remote/quiz_api.dart';
import 'api_guard.dart';

class QuizRepositoryImpl implements QuizRepository {
  QuizRepositoryImpl(this._api, this._config);

  final QuizApi _api;
  final AppConfig _config;

  String get _base => _config.apiBaseUrl;

  @override
  Future<Quiz> create(DocumentDraft draft, {bool mcqOnly = false}) => guard(() async {
    final json = draftJson(draft)
      ..remove('draft')
      ..remove('tag')
      ..remove('groupIds');
    return quizOf(await _api.create({...json, 'mcqOnly': mcqOnly}), _base);
  });

  @override
  Future<Quiz> quiz(String id) => guard(() async => quizOf(await _api.quiz(id), _base));

  @override
  Future<Quiz> save(String id, QuizSettings settings, List<QuizQuestion> questions) => guard(
    () async => quizOf(
      await _api.save(id, {
        'settings': quizSettingsJson(settings),
        'questions': [for (final q in questions) questionJson(q)],
      }),
      _base,
    ),
  );

  @override
  Future<Quiz> duplicate(String id) => guard(() async => quizOf(await _api.duplicate(id), _base));

  @override
  Future<List<ReviewItem>> preview(String id, Map<String, QuizAnswer> answers) =>
      guard(() async => [for (final item in await _api.preview(id, answers)) reviewItemOf(item as Json)]);

  @override
  Future<MyQuiz> myQuiz(String assignmentId, {String? studentId}) =>
      guard(() async => myQuizOf(await _api.myQuiz(assignmentId, studentId: studentId), _base));

  @override
  Future<AttemptPlay> start(String assignmentId, {String? studentId}) =>
      guard(() async => attemptPlayOf(await _api.start(assignmentId, studentId: studentId), _base));

  @override
  Future<void> saveAnswers(String assignmentId, String attemptId, Map<String, QuizAnswer> answers, {String? studentId}) =>
      guard(() => _api.saveAnswers(assignmentId, attemptId, answers, studentId: studentId));

  @override
  Future<AttemptReview> submit(String assignmentId, String attemptId, {String? studentId}) =>
      guard(() async => attemptReviewOf(await _api.submit(assignmentId, attemptId, studentId: studentId), _base));

  @override
  Future<AttemptReview> attempt(String assignmentId, String attemptId, {String? studentId}) =>
      guard(() async => attemptReviewOf(await _api.attempt(assignmentId, attemptId, studentId: studentId), _base));

  @override
  Future<QuizCorrection> correction(String assignmentId, String studentId, {String? attemptId}) =>
      guard(() async => quizCorrectionOf(await _api.correction(assignmentId, studentId, attemptId: attemptId), _base));

  @override
  Future<QuizCorrection> correct(String assignmentId, String studentId, String attemptId, Map<String, double?> scores, String comment) =>
      guard(
        () async => quizCorrectionOf(
          await _api.correct(assignmentId, studentId, attemptId, {'scores': scores, 'comment': comment.trim().isEmpty ? null : comment.trim()}),
          _base,
        ),
      );
}
