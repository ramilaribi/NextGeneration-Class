import 'package:equatable/equatable.dart';

import 'content.dart';
import 'homework.dart';

/// The five question types of spec 05. Open questions are corrected by the teacher, the others at once.
enum QuestionType { mcq, trueFalse, short, blanks, open }

/// With several attempts, the grade that counts.
enum ScorePolicy { best, last }

/// When pupils see the right answers: after the deadline (default), right after sending, or never.
enum AnswersShown { afterDeadline, afterSubmit, never }

/// The quiz's settings (design `r3/QuizEditeur.png`, "Réglages").
class QuizSettings extends Equatable {
  const QuizSettings({
    this.timeLimitMin,
    this.attemptsAllowed = 1,
    this.scorePolicy = ScorePolicy.best,
    this.answersShown = AnswersShown.afterDeadline,
    this.shuffle = false,
  });

  /// Minutes; null: no timer ("Sans limite").
  final int? timeLimitMin;
  final int attemptsAllowed;
  final ScorePolicy scorePolicy;
  final AnswersShown answersShown;
  final bool shuffle;

  QuizSettings copyWith({
    int? Function()? timeLimitMin,
    int? attemptsAllowed,
    ScorePolicy? scorePolicy,
    AnswersShown? answersShown,
    bool? shuffle,
  }) => QuizSettings(
    timeLimitMin: timeLimitMin != null ? timeLimitMin() : this.timeLimitMin,
    attemptsAllowed: attemptsAllowed ?? this.attemptsAllowed,
    scorePolicy: scorePolicy ?? this.scorePolicy,
    answersShown: answersShown ?? this.answersShown,
    shuffle: shuffle ?? this.shuffle,
  );

  @override
  List<Object?> get props => [timeLimitMin, attemptsAllowed, scorePolicy, answersShown, shuffle];
}

/// A choice of a multiple-choice question: text with formulas between two $ ("$2/4$").
class QuizChoice extends Equatable {
  const QuizChoice({required this.id, this.text = ''});

  final String id;
  final String text;

  QuizChoice withText(String value) => QuizChoice(id: id, text: value);

  @override
  List<Object?> get props => [id, text];
}

/// A gap of a "Texte à trous" question, as its text keeps it.
class QuizBlank extends Equatable {
  const QuizBlank({required this.id, this.answers = const []});

  final String id;

  /// Empty for pupils while they take the quiz.
  final List<String> answers;

  @override
  List<Object?> get props => [id, answers];
}

/// The embed of a gap in a question's text: {"insert": {"blank": {"id": "b1", "answers": ["numérateur"]}}}.
const blankEmbed = 'blank';

/// One question. Its [text] is the page editor's document (Delta operations: formulas, tables, pictures,
/// and gaps for "Texte à trous"). What makes it right depends on its [type]; pupils never receive it
/// before the answers are shown.
class QuizQuestion extends Equatable {
  const QuizQuestion({
    required this.id,
    required this.type,
    this.points = 1,
    this.text = const [
      {'insert': '\n'},
    ],
    this.explanation = '',
    this.choices = const [],
    this.correct,
    this.answer,
    this.accepted = const [],
  });

  final String id;
  final QuestionType type;
  final int points;
  final List<Map<String, dynamic>> text;

  /// Shown with the answers; text with formulas between two $.
  final String explanation;

  /// Multiple choice.
  final List<QuizChoice> choices;
  final String? correct;

  /// True or false.
  final bool? answer;

  /// Short answer: every answer accepted (case, accents, spaces, a final full stop and 2,5 / 2.5 ignored).
  final List<String> accepted;

  /// The gaps of a "Texte à trous", in reading order.
  List<QuizBlank> get blanks => [
    for (final op in text)
      if (op['insert'] case {blankEmbed: final Map<String, dynamic> blank})
        QuizBlank(id: '${blank['id']}', answers: [for (final a in blank['answers'] as List? ?? const []) '$a']),
  ];

  /// The text without its embeds, for a short label.
  String get plainText => [
    for (final op in text)
      if (op['insert'] is String) op['insert'] as String,
  ].join().trim();

  bool get hasContent => plainText.isNotEmpty || text.any((op) => op['insert'] is Map);

  /// Answerable and corrected: what a published quiz needs (the server checks it too).
  bool get isComplete {
    if (!hasContent) return false;
    return switch (type) {
      QuestionType.mcq =>
        choices.length >= 2 && choices.every((c) => c.text.trim().isNotEmpty) && choices.any((c) => c.id == correct),
      QuestionType.trueFalse => answer != null,
      QuestionType.short => accepted.any((a) => a.trim().isNotEmpty),
      QuestionType.blanks => blanks.isNotEmpty && blanks.every((b) => b.answers.any((a) => a.trim().isNotEmpty)),
      QuestionType.open => true,
    };
  }

  QuizQuestion copyWith({
    QuestionType? type,
    int? points,
    List<Map<String, dynamic>>? text,
    String? explanation,
    List<QuizChoice>? choices,
    String? Function()? correct,
    bool? Function()? answer,
    List<String>? accepted,
  }) => QuizQuestion(
    id: id,
    type: type ?? this.type,
    points: points ?? this.points,
    text: text ?? this.text,
    explanation: explanation ?? this.explanation,
    choices: choices ?? this.choices,
    correct: correct != null ? correct() : this.correct,
    answer: answer != null ? answer() : this.answer,
    accepted: accepted ?? this.accepted,
  );

  @override
  List<Object?> get props => [id, type, points, text, explanation, choices, correct, answer, accepted];
}

/// A quiz in the builder: its library row, settings and questions.
class Quiz extends Equatable {
  const Quiz({
    required this.document,
    this.settings = const QuizSettings(),
    this.mcqOnly = false,
    this.locked = false,
    this.questions = const [],
    this.pictureUrls = const {},
  });

  final ContentDocument document;
  final QuizSettings settings;

  /// Made from "Créer › QCM": multiple choice only, with the fast entry.
  final bool mcqOnly;

  /// A pupil started it: the questions no longer change ("Dupliquer" for a new version).
  final bool locked;
  final List<QuizQuestion> questions;
  final Map<String, String> pictureUrls;

  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);

  int get openCount => questions.where((q) => q.type == QuestionType.open).length;

  /// The questions corrected by the server ("corrigées seules").
  int get autoCount => questions.length - openCount;

  Quiz copyWith({
    ContentDocument? document,
    QuizSettings? settings,
    bool? locked,
    List<QuizQuestion>? questions,
    Map<String, String>? pictureUrls,
  }) => Quiz(
    document: document ?? this.document,
    settings: settings ?? this.settings,
    mcqOnly: mcqOnly,
    locked: locked ?? this.locked,
    questions: questions ?? this.questions,
    pictureUrls: pictureUrls ?? this.pictureUrls,
  );

  @override
  List<Object?> get props => [document, settings, mcqOnly, locked, questions, pictureUrls];
}

/// An answer, as the server keeps it: {"choice": "c1"}, {"value": true}, {"text": "2,5"}, {"blanks": {"b1": "…"}}.
typedef QuizAnswer = Map<String, dynamic>;

/// An attempt sent, in a list.
class AttemptSummary extends Equatable {
  const AttemptSummary({
    required this.id,
    required this.number,
    required this.startedAt,
    this.submittedAt,
    this.late = false,
    this.autoScore,
    this.score,
    this.pending = false,
  });

  final String id;
  final int number;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final bool late;
  final double? autoScore;

  /// Out of the quiz's total, once every question has points.
  final double? score;

  /// Open questions wait for the teacher.
  final bool pending;

  @override
  List<Object?> get props => [id, number, startedAt, submittedAt, late, autoScore, score, pending];
}

/// The attempt being taken: questions in this pupil's order, without their answers.
class AttemptPlay extends Equatable {
  const AttemptPlay({
    required this.id,
    required this.number,
    required this.startedAt,
    this.endsAt,
    this.questions = const [],
    this.answers = const {},
    this.pictureUrls = const {},
  });

  final String id;
  final int number;
  final DateTime startedAt;

  /// When the timer reaches zero; null without a timer.
  final DateTime? endsAt;
  final List<QuizQuestion> questions;
  final Map<String, QuizAnswer> answers;
  final Map<String, String> pictureUrls;

  @override
  List<Object?> get props => [id, number, startedAt, endsAt, questions, answers, pictureUrls];
}

/// A quiz given as homework, for the pupil or the parent.
class MyQuiz extends Equatable {
  const MyQuiz({
    required this.assignmentId,
    required this.title,
    required this.deadlineAt,
    this.timeLimitMin,
    this.attemptsAllowed = 1,
    this.scorePolicy = ScorePolicy.best,
    this.answersShown = AnswersShown.afterDeadline,
    this.questionCount = 0,
    this.totalPoints = 0,
    this.attempts = const [],
    this.current,
    this.canStart = false,
    this.kept,
  });

  final String assignmentId;
  final String title;
  final DateTime deadlineAt;
  final int? timeLimitMin;
  final int attemptsAllowed;
  final ScorePolicy scorePolicy;
  final AnswersShown answersShown;
  final int questionCount;
  final int totalPoints;
  final List<AttemptSummary> attempts;

  /// The attempt not sent yet: "Reprendre".
  final AttemptPlay? current;
  final bool canStart;

  /// The grade that counts.
  final double? kept;

  int get attemptsLeft => (attemptsAllowed - attempts.length - (current == null ? 0 : 1)).clamp(0, attemptsAllowed);

  @override
  List<Object?> get props => [
    assignmentId,
    title,
    deadlineAt,
    timeLimitMin,
    attemptsAllowed,
    scorePolicy,
    answersShown,
    questionCount,
    totalPoints,
    attempts,
    current,
    canStart,
    kept,
  ];
}

/// One question after sending: what was given, its points (null: an open question not corrected yet),
/// and right or not (null for an open question).
class ReviewItem extends Equatable {
  const ReviewItem({required this.number, required this.question, this.answer, this.points, required this.maxPoints, this.right});

  final int number;

  /// With its answers only when they are shown.
  final QuizQuestion question;
  final QuizAnswer? answer;
  final double? points;
  final int maxPoints;
  final bool? right;

  bool get waiting => points == null;

  @override
  List<Object?> get props => [number, question, answer, points, maxPoints, right];
}

/// An attempt sent: its grade and each question.
class AttemptReview extends Equatable {
  const AttemptReview({
    required this.id,
    required this.number,
    this.submittedAt,
    this.late = false,
    this.score,
    this.autoScore,
    required this.maxScore,
    this.pending = false,
    this.answersShown = false,
    this.items = const [],
    this.pictureUrls = const {},
  });

  final String id;
  final int number;
  final DateTime? submittedAt;
  final bool late;
  final double? score;
  final double? autoScore;
  final int maxScore;
  final bool pending;

  /// The right answers are in [items].
  final bool answersShown;
  final List<ReviewItem> items;
  final Map<String, String> pictureUrls;

  @override
  List<Object?> get props => [id, number, submittedAt, late, score, autoScore, maxScore, pending, answersShown, items, pictureUrls];
}

/// One pupil's quiz homework for the teacher: the attempts and the one shown with every answer.
class QuizCorrection extends Equatable {
  const QuizCorrection({
    required this.assignmentId,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.status,
    required this.maxScore,
    this.attempts = const [],
    this.attempt,
    this.comment,
  });

  final String assignmentId;
  final String studentId;
  final String firstName;
  final String lastName;
  final HomeworkStatus? status;
  final int maxScore;
  final List<AttemptSummary> attempts;
  final AttemptReview? attempt;
  final String? comment;

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [assignmentId, studentId, firstName, lastName, status, maxScore, attempts, attempt, comment];
}
