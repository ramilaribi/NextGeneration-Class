import '../../domain/model/quiz.dart';
import 'content_dto.dart';
import 'homework_dto.dart';
import 'school_dto.dart';

QuestionType questionType(Object? value) => switch (value) {
  'TRUE_FALSE' => QuestionType.trueFalse,
  'SHORT' => QuestionType.short,
  'BLANKS' => QuestionType.blanks,
  'OPEN' => QuestionType.open,
  _ => QuestionType.mcq,
};

String questionTypeParam(QuestionType type) => switch (type) {
  QuestionType.mcq => 'MCQ',
  QuestionType.trueFalse => 'TRUE_FALSE',
  QuestionType.short => 'SHORT',
  QuestionType.blanks => 'BLANKS',
  QuestionType.open => 'OPEN',
};

ScorePolicy scorePolicy(Object? value) => value == 'LAST' ? ScorePolicy.last : ScorePolicy.best;

AnswersShown answersShown(Object? value) => switch (value) {
  'AFTER_SUBMIT' => AnswersShown.afterSubmit,
  'NEVER' => AnswersShown.never,
  _ => AnswersShown.afterDeadline,
};

String answersShownParam(AnswersShown value) => switch (value) {
  AnswersShown.afterDeadline => 'AFTER_DEADLINE',
  AnswersShown.afterSubmit => 'AFTER_SUBMIT',
  AnswersShown.never => 'NEVER',
};

double? _decimal(Object? value) => value is num ? value.toDouble() : (value is String ? double.tryParse(value) : null);

QuizSettings quizSettingsOf(Json json) => QuizSettings(
  timeLimitMin: (json['timeLimitMin'] as num?)?.toInt(),
  attemptsAllowed: (json['attemptsAllowed'] as num? ?? 1).toInt(),
  scorePolicy: scorePolicy(json['scorePolicy']),
  answersShown: answersShown(json['answersShown']),
  shuffle: json['shuffle'] as bool? ?? false,
);

Json quizSettingsJson(QuizSettings settings) => {
  'timeLimitMin': settings.timeLimitMin,
  'attemptsAllowed': settings.attemptsAllowed,
  'scorePolicy': settings.scorePolicy == ScorePolicy.last ? 'LAST' : 'BEST',
  'answersShown': answersShownParam(settings.answersShown),
  'shuffle': settings.shuffle,
};

QuizQuestion questionOf(Json json) => QuizQuestion(
  id: '${json['id']}',
  type: questionType(json['type']),
  points: (json['points'] as num? ?? 1).toInt(),
  text: json['text'] is List ? deltaOf(json['text']) : const [{'insert': '\n'}],
  explanation: json['explanation'] as String? ?? '',
  choices: [
    for (final c in json['choices'] as List<dynamic>? ?? const [])
      QuizChoice(id: '${(c as Map)['id']}', text: c['text'] as String? ?? ''),
  ],
  correct: json['correct'] as String?,
  answer: json['answer'] as bool?,
  accepted: [for (final a in json['accepted'] as List<dynamic>? ?? const []) '$a'],
);

/// Only what the question's type uses: changing a type leaves nothing behind.
Json questionJson(QuizQuestion q) => {
  'id': q.id,
  'type': questionTypeParam(q.type),
  'points': q.points,
  'text': q.text,
  if (q.explanation.trim().isNotEmpty) 'explanation': q.explanation.trim(),
  if (q.type == QuestionType.mcq) ...{
    'choices': [
      for (final c in q.choices) {'id': c.id, 'text': c.text},
    ],
    'correct': ?q.correct,
  },
  if (q.type == QuestionType.trueFalse) 'answer': ?q.answer,
  if (q.type == QuestionType.short) 'accepted': [for (final a in q.accepted) if (a.trim().isNotEmpty) a.trim()],
};

Quiz quizOf(Json json, String apiBase) => Quiz(
  document: documentOf(json['item'] as Json),
  settings: quizSettingsOf(json['settings'] as Json? ?? const {}),
  mcqOnly: json['mcqOnly'] as bool? ?? false,
  locked: json['locked'] as bool? ?? false,
  questions: [for (final q in json['questions'] as List<dynamic>? ?? const []) questionOf(Map<String, dynamic>.from(q as Map))],
  pictureUrls: pictureUrlsOf(json['pictureUrls'], apiBase),
);

Map<String, QuizAnswer> answersOf(Object? value) => {
  for (final e in (value as Map<String, dynamic>? ?? const {}).entries)
    if (e.value is Map) e.key: Map<String, dynamic>.from(e.value as Map),
};

AttemptSummary attemptSummaryOf(Json json) => AttemptSummary(
  id: json['id'] as String,
  number: (json['number'] as num? ?? 1).toInt(),
  startedAt: instant(json['startedAt'])!,
  submittedAt: instant(json['submittedAt']),
  late: json['late'] as bool? ?? false,
  autoScore: _decimal(json['autoScore']),
  score: _decimal(json['score']),
  pending: json['pending'] as bool? ?? false,
);

AttemptPlay attemptPlayOf(Json json, String apiBase) => AttemptPlay(
  id: json['id'] as String,
  number: (json['number'] as num? ?? 1).toInt(),
  startedAt: instant(json['startedAt'])!,
  endsAt: instant(json['endsAt']),
  questions: [for (final q in json['questions'] as List<dynamic>? ?? const []) questionOf(Map<String, dynamic>.from(q as Map))],
  answers: answersOf(json['answers']),
  pictureUrls: pictureUrlsOf(json['pictureUrls'], apiBase),
);

MyQuiz myQuizOf(Json json, String apiBase) => MyQuiz(
  assignmentId: json['assignmentId'] as String,
  title: json['title'] as String? ?? '',
  deadlineAt: instant(json['deadlineAt'])!,
  timeLimitMin: (json['timeLimitMin'] as num?)?.toInt(),
  attemptsAllowed: (json['attemptsAllowed'] as num? ?? 1).toInt(),
  scorePolicy: scorePolicy(json['scorePolicy']),
  answersShown: answersShown(json['answersShown']),
  questionCount: (json['questionCount'] as num? ?? 0).toInt(),
  totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
  attempts: [for (final a in json['attempts'] as List<dynamic>? ?? const []) attemptSummaryOf(a as Json)],
  current: json['current'] == null ? null : attemptPlayOf(json['current'] as Json, apiBase),
  canStart: json['canStart'] as bool? ?? false,
  kept: _decimal(json['kept']),
);

ReviewItem reviewItemOf(Json json) => ReviewItem(
  number: (json['number'] as num? ?? 1).toInt(),
  question: questionOf(Map<String, dynamic>.from(json['question'] as Map)),
  answer: json['answer'] is Map ? Map<String, dynamic>.from(json['answer'] as Map) : null,
  points: _decimal(json['points']),
  maxPoints: (json['maxPoints'] as num? ?? 1).toInt(),
  right: json['right'] as bool?,
);

AttemptReview attemptReviewOf(Json json, String apiBase) => AttemptReview(
  id: json['id'] as String,
  number: (json['number'] as num? ?? 1).toInt(),
  submittedAt: instant(json['submittedAt']),
  late: json['late'] as bool? ?? false,
  score: _decimal(json['score']),
  autoScore: _decimal(json['autoScore']),
  maxScore: (json['maxScore'] as num? ?? 0).toInt(),
  pending: json['pending'] as bool? ?? false,
  answersShown: json['answersShown'] as bool? ?? false,
  items: [for (final i in json['items'] as List<dynamic>? ?? const []) reviewItemOf(i as Json)],
  pictureUrls: pictureUrlsOf(json['pictureUrls'], apiBase),
);

QuizCorrection quizCorrectionOf(Json json, String apiBase) => QuizCorrection(
  assignmentId: json['assignmentId'] as String,
  studentId: json['studentId'] as String,
  firstName: json['firstName'] as String? ?? '',
  lastName: json['lastName'] as String? ?? '',
  status: homeworkStatus(json['status']),
  maxScore: (json['maxScore'] as num? ?? 0).toInt(),
  attempts: [for (final a in json['attempts'] as List<dynamic>? ?? const []) attemptSummaryOf(a as Json)],
  attempt: json['attempt'] == null ? null : attemptReviewOf(json['attempt'] as Json, apiBase),
  comment: json['comment'] as String?,
);
