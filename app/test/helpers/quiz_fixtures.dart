import 'package:ngclass/core/di/injection.dart';
import 'package:ngclass/core/network/api_failure.dart';
import 'package:ngclass/domain/model/content.dart';
import 'package:ngclass/domain/model/quiz.dart';
import 'package:ngclass/domain/repositories/quiz_repository.dart';

import 'content_fixtures.dart';
import 'page_fixtures.dart';

/// "Quiz : les fractions", a draft of 4ème année · Maths.
ContentDocument quizDocument({ContentStatus status = ContentStatus.draft}) =>
    doc('quiz1', 'Quiz : les fractions', kind: FileKind.quiz, status: status, shared: const []);

List<Map<String, dynamic>> line(String text) => [
  {'insert': '$text\n'},
];

/// The design's five questions: 10 points, 4 corrected alone.
List<QuizQuestion> sampleQuestions() => [
  QuizQuestion(
    id: 'q1',
    type: QuestionType.mcq,
    points: 2,
    text: [
      {'insert': 'Quelle fraction est égale à '},
      {
        'insert': {'formula': '1/2'},
      },
      {'insert': ' ?\n'},
    ],
    choices: const [QuizChoice(id: 'a', text: '2/4'), QuizChoice(id: 'b', text: '2/3'), QuizChoice(id: 'c', text: '3/4')],
    correct: 'a',
  ),
  QuizQuestion(id: 'q2', type: QuestionType.trueFalse, points: 1, text: line('3/5 > 4/7'), answer: true, explanation: r'$3/5 = 21/35$'),
  QuizQuestion(id: 'q3', type: QuestionType.short, points: 2, text: line('Calcule 3/4 + 1/4.'), accepted: const ['1', '4/4', '1,0']),
  QuizQuestion(
    id: 'q4',
    type: QuestionType.blanks,
    points: 2,
    text: const [
      {'insert': 'Dans la fraction 3/4, 3 est le '},
      {
        'insert': {
          'blank': {
            'id': 'b1',
            'answers': ['numérateur'],
          },
        },
      },
      {'insert': ' et 4 le '},
      {
        'insert': {
          'blank': {
            'id': 'b2',
            'answers': ['dénominateur'],
          },
        },
      },
      {'insert': '.\n'},
    ],
  ),
  QuizQuestion(id: 'q5', type: QuestionType.open, points: 3, text: line('Explique comment tu compares deux fractions.')),
];

Quiz sampleQuiz({ContentStatus status = ContentStatus.draft, bool locked = false, List<QuizQuestion>? questions, bool mcqOnly = false}) => Quiz(
  document: quizDocument(status: status),
  settings: const QuizSettings(timeLimitMin: 15),
  locked: locked,
  mcqOnly: mcqOnly,
  questions: questions ?? sampleQuestions(),
);

/// The questions as a pupil receives them: no right answer.
List<QuizQuestion> forPupil(List<QuizQuestion> questions) => [
  for (final q in questions)
    QuizQuestion(
      id: q.id,
      type: q.type,
      points: q.points,
      text: [
        for (final op in q.text)
          if (op['insert'] case {'blank': final Map<String, dynamic> b})
            {
              'insert': {
                'blank': {'id': b['id']},
              },
            }
          else
            op,
      ],
      choices: q.choices,
    ),
];

/// Keeps quizzes and attempts in memory; grades multiple choice and true / false like the server.
class FakeQuizRepository implements QuizRepository {
  FakeQuizRepository({Quiz? quiz, this.timeLimitMin}) : quizzes = {'quiz1': quiz ?? sampleQuiz()};

  final Map<String, Quiz> quizzes;
  final int? timeLimitMin;
  final List<(DocumentDraft, bool)> created = [];
  final List<(String, QuizSettings, List<QuizQuestion>)> saves = [];
  final List<Map<String, QuizAnswer>> savedAnswers = [];
  final List<(String, Map<String, double?>, String)> corrections = [];
  ApiFailure? saveFailure;

  /// The next answers save answers this (the time is up).
  ApiFailure? answersFailure;

  final List<AttemptSummary> attempts = [];
  AttemptPlay? current;
  bool started = false;

  @override
  Future<Quiz> create(DocumentDraft draft, {bool mcqOnly = false}) async {
    created.add((draft, mcqOnly));
    final quiz = Quiz(
      document: doc('quiz-new', draft.title.trim(), kind: FileKind.quiz, status: ContentStatus.draft, shared: const []),
      mcqOnly: mcqOnly,
    );
    quizzes['quiz-new'] = quiz;
    return quiz;
  }

  @override
  Future<Quiz> quiz(String id) async => quizzes[id] ?? (throw const ApiFailure(code: 'content_not_found', statusCode: 404));

  @override
  Future<Quiz> save(String id, QuizSettings settings, List<QuizQuestion> questions) async {
    if (saveFailure != null) throw saveFailure!;
    saves.add((id, settings, questions));
    final saved = quizzes[id]!.copyWith(settings: settings, questions: questions);
    quizzes[id] = saved;
    return saved;
  }

  @override
  Future<Quiz> duplicate(String id) async {
    final copy = Quiz(document: doc('quiz-copy', '${quizzes[id]!.document.title} (copie)', kind: FileKind.quiz), questions: quizzes[id]!.questions);
    quizzes['quiz-copy'] = copy;
    return copy;
  }

  static double? _grade(QuizQuestion q, QuizAnswer? a) => switch (q.type) {
    QuestionType.mcq => a?['choice'] == q.correct ? q.points.toDouble() : 0,
    QuestionType.trueFalse => a?['value'] == q.answer ? q.points.toDouble() : 0,
    QuestionType.short => q.accepted.contains('${a?['text'] ?? ''}'.trim()) ? q.points.toDouble() : 0,
    QuestionType.blanks => 0,
    QuestionType.open => null,
  };

  List<ReviewItem> _items(List<QuizQuestion> questions, Map<String, QuizAnswer> answers) => [
    for (var i = 0; i < questions.length; i++)
      ReviewItem(
        number: i + 1,
        question: questions[i],
        answer: answers[questions[i].id],
        points: _grade(questions[i], answers[questions[i].id]),
        maxPoints: questions[i].points,
        right: _grade(questions[i], answers[questions[i].id]) == null
            ? null
            : _grade(questions[i], answers[questions[i].id]) == questions[i].points,
      ),
  ];

  @override
  Future<List<ReviewItem>> preview(String id, Map<String, QuizAnswer> answers) async => _items(quizzes[id]!.questions, answers);

  Quiz get _given => quizzes['quiz1']!;

  @override
  Future<MyQuiz> myQuiz(String assignmentId, {String? studentId}) async => MyQuiz(
    assignmentId: assignmentId,
    title: _given.document.title,
    deadlineAt: DateTime.utc(2026, 10, 20, 17),
    timeLimitMin: timeLimitMin,
    attemptsAllowed: 2,
    questionCount: _given.questions.length,
    totalPoints: _given.totalPoints,
    attempts: attempts,
    current: current,
    canStart: current == null && attempts.length < 2,
    kept: attempts.where((a) => a.score != null).map((a) => a.score!).fold<double?>(null, (m, s) => m == null || s > m ? s : m),
  );

  @override
  Future<AttemptPlay> start(String assignmentId, {String? studentId}) async {
    started = true;
    return current ??= AttemptPlay(
      id: 'att${attempts.length + 1}',
      number: attempts.length + 1,
      startedAt: DateTime.utc(2026, 10, 12, 9),
      endsAt: timeLimitMin == null ? null : DateTime.utc(2026, 10, 12, 9).add(Duration(minutes: timeLimitMin!)),
      questions: forPupil(_given.questions),
    );
  }

  @override
  Future<void> saveAnswers(String assignmentId, String attemptId, Map<String, QuizAnswer> answers, {String? studentId}) async {
    if (answersFailure != null) {
      final failure = answersFailure!;
      answersFailure = null;
      throw failure;
    }
    savedAnswers.add(answers);
  }

  Map<String, QuizAnswer> get _allAnswers => {for (final batch in savedAnswers) ...batch};

  @override
  Future<AttemptReview> submit(String assignmentId, String attemptId, {String? studentId}) async {
    final items = _items(_given.questions, _allAnswers);
    final pending = items.any((i) => i.waiting);
    final auto = items.fold<double>(0, (s, i) => s + (i.points ?? 0));
    final summary = AttemptSummary(
      id: attemptId,
      number: attempts.length + 1,
      startedAt: DateTime.utc(2026, 10, 12, 9),
      submittedAt: DateTime.utc(2026, 10, 12, 9, 10),
      autoScore: auto,
      score: pending ? null : auto,
      pending: pending,
    );
    attempts.add(summary);
    current = null;
    return AttemptReview(id: attemptId, number: summary.number, submittedAt: summary.submittedAt, score: summary.score, autoScore: auto,
        maxScore: _given.totalPoints, pending: pending, items: _items(forPupil(_given.questions), _allAnswers));
  }

  @override
  Future<AttemptReview> attempt(String assignmentId, String attemptId, {String? studentId}) async =>
      AttemptReview(id: attemptId, number: 1, maxScore: _given.totalPoints, items: _items(_given.questions, _allAnswers), answersShown: true);

  @override
  Future<QuizCorrection> correction(String assignmentId, String studentId, {String? attemptId}) async {
    final answers = {
      'q1': {'choice': 'a'},
      'q2': {'value': false},
      'q5': {'text': 'On met au même dénominateur.'},
    };
    final items = _items(_given.questions, answers);
    return QuizCorrection(
      assignmentId: assignmentId,
      studentId: studentId,
      firstName: 'Adam',
      lastName: 'Gharbi',
      maxScore: _given.totalPoints,
      attempts: [AttemptSummary(id: 'att1', number: 1, startedAt: DateTime.utc(2026, 10, 12, 9), autoScore: 2, pending: true)],
      attempt: AttemptReview(id: 'att1', number: 1, autoScore: 2, maxScore: _given.totalPoints, pending: true, answersShown: true, items: items),
    );
  }

  @override
  Future<QuizCorrection> correct(String assignmentId, String studentId, String attemptId, Map<String, double?> scores, String comment) async {
    corrections.add((attemptId, scores, comment));
    return correction(assignmentId, studentId);
  }
}

/// The content and page services, the quiz repository, and the quiz in the library.
({FakeContentRepository content, FakeQuizRepository quizzes}) registerQuizServices({FakeQuizRepository? quizzes}) {
  final services = registerPageServices();
  final repo = quizzes ?? FakeQuizRepository();
  services.content.library_ = services.content.library_.copyWith(
    documents: [...services.content.library_.documents, for (final q in repo.quizzes.values) q.document],
  );
  sl.registerSingleton<QuizRepository>(repo);
  return (content: services.content, quizzes: repo);
}
