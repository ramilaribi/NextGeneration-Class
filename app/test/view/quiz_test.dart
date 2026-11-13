import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngclass/core/l10n/app_language.dart';
import 'package:ngclass/core/l10n/formatting.dart';
import 'package:ngclass/core/network/api_failure.dart';
import 'package:ngclass/data/dto/quiz_dto.dart';
import 'package:ngclass/domain/model/homework.dart';
import 'package:ngclass/domain/model/quiz.dart';
import 'package:ngclass/view/screens/shared/quiz/my_quiz_area.dart';
import 'package:ngclass/view/screens/shared/quiz/quiz_player_screen.dart';
import 'package:ngclass/view/screens/teacher/contents/quiz/quick_qcm_panel.dart';
import 'package:ngclass/view/screens/teacher/contents/quiz/quiz_editor_screen.dart';
import 'package:ngclass/view/screens/teacher/homework/quiz_correction_body.dart';
import 'package:ngclass/view/stateManager/common/load_status.dart';
import 'package:ngclass/view/stateManager/quiz_editor/quiz_editor_cubit.dart';
import 'package:ngclass/view/stateManager/quiz_player/quiz_correction_cubit.dart';
import 'package:ngclass/view/stateManager/quiz_player/quiz_player_cubit.dart';
import 'package:ngclass/view/stateManager/quiz_player/quiz_session.dart';
import 'package:ngclass/view/widgets/quiz_widgets.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/homework_fixtures.dart';
import '../helpers/page_fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/quiz_fixtures.dart';
import '../helpers/student_fixtures.dart' show now, pupil;

/// Release 3, steps 2 and 3: quizzes and QCM (designs `r3/QuizEditeur.png`, `r3/QuizSaisieRapide.png`,
/// `r3/SeriesQuizPhone.png`).
void main() {
  setUpAll(initializeAppDates);

  late FakeContentRepository content;
  late FakeQuizRepository quizzes;

  setUp(() {
    registerTestServices(now);
    final services = registerQuizServices();
    content = services.content;
    quizzes = services.quizzes;
  });

  group('reading and writing questions', () {
    test('the fast entry reads a question, its choices, and a blank line for the next one', () {
      final typed = readTypedQuestions('Quel est le plus grand nombre ?\n1/3\n1/2\n1/4\n\nCombien de quarts dans une unité ?\n2\n3\n4\n\nPas fini\n2');
      expect(typed, hasLength(2));
      expect(typed.first.text, 'Quel est le plus grand nombre ?');
      expect(typed.first.choices, ['1/3', '1/2', '1/4']);
      expect(typed.last.choices, ['2', '3', '4']);
    });

    test('answers are compared as the server does: case, accents, spaces, the final stop and the decimal comma', () {
      expect(normalizeAnswer('  Le   NUMÉRATEUR. '), 'le numerateur');
      expect(normalizeAnswer(' 2,5. '), '2.5');
      expect(normalizeAnswer('Numerateur'), normalizeAnswer('numérateur'));
    });

    test('3/4 typed becomes a fraction; words and text between dollars stay as they are', () {
      expect(autoFormulas('3/4'), r'$3/4$');
      expect(autoFormulas('6/8 est égale à :'), r'$6/8$ est égale à :');
      expect(autoFormulas('2,5'), '2,5');
      expect(autoFormulas('et/ou'), 'et/ou');
      expect(autoFormulas(r'$x^2$ déjà'), r'$x^2$ déjà');
      final delta = deltaFromLine('6/8 est égale à :');
      expect(delta.first['insert'], {'formula': '6/8'});
      expect(delta.last['insert'], '\n');
    });

    test('a question is complete with its text and its right answer', () {
      for (final q in sampleQuestions()) {
        expect(q.isComplete, isTrue, reason: q.id);
      }
      const empty = QuizQuestion(id: 'x', type: QuestionType.mcq);
      expect(empty.isComplete, isFalse);
      final noRight = sampleQuestions().first.copyWith(correct: () => null);
      expect(noRight.isComplete, isFalse);
      final oneChoice = sampleQuestions().first.copyWith(choices: const [QuizChoice(id: 'a', text: '2/4')]);
      expect(oneChoice.isComplete, isFalse);
      expect(sampleQuestions()[1].copyWith(answer: () => null).isComplete, isFalse);
      expect(sampleQuestions()[2].copyWith(accepted: const []).isComplete, isFalse);
      expect(sampleQuestions()[3].copyWith(text: line('Pas de trou.')).isComplete, isFalse);
      expect(sampleQuestions()[3].blanks.map((b) => b.answers.single), ['numérateur', 'dénominateur']);
    });

    test('a question goes to the server and back unchanged; only what its type uses is sent', () {
      for (final q in sampleQuestions()) {
        expect(questionOf(questionJson(q)), q, reason: q.id);
      }
      final changed = sampleQuestions().first.copyWith(type: QuestionType.trueFalse, answer: () => false);
      final json = questionJson(changed);
      expect(json.containsKey('choices'), isFalse);
      expect(json['answer'], false);
      final quiz = sampleQuiz();
      expect(quiz.totalPoints, 10);
      expect(quiz.autoCount, 4);
    });
  });

  group('QuizEditorCubit', () {
    QuizEditorCubit cubit() => QuizEditorCubit(quizzes, content, FakePageRepository(), () => now, 'quiz1', pause: const Duration(milliseconds: 5));

    test('a new question is selected and the quiz is saved a moment later', () async {
      final editor = cubit();
      await editor.load();
      expect(editor.state.status, LoadStatus.ready);
      expect(editor.state.selectedId, 'q1');
      editor.addQuestion(QuestionType.trueFalse);
      final added = editor.state.quiz!.questions.last;
      expect(editor.state.selectedId, added.id);
      expect(editor.state.save, PageSave.pending);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(editor.state.save, PageSave.saved);
      expect(quizzes.saves.single.$3, hasLength(6));
      await editor.close();
    });

    test('move, duplicate and remove keep the questions in order, with new ids for a copy', () async {
      final editor = cubit();
      await editor.load();
      editor.moveQuestion('q2', -1);
      expect(editor.state.quiz!.questions.map((q) => q.id).take(2), ['q2', 'q1']);
      editor.duplicateQuestion('q4');
      final copy = editor.state.quiz!.questions[4];
      expect(copy.id, isNot('q4'));
      expect(copy.blanks.map((b) => b.id), isNot(contains('b1')));
      expect(copy.blanks.map((b) => b.answers.single), ['numérateur', 'dénominateur']);
      editor.duplicateQuestion('q1');
      final mcq = editor.state.quiz!.questions.firstWhere((q) => q.id != 'q1' && q.type == QuestionType.mcq);
      expect(mcq.choices.map((c) => c.id), isNot(contains('a')));
      expect(mcq.correct, mcq.choices.first.id);
      editor.removeQuestion('q2');
      expect(editor.state.quiz!.questions.map((q) => q.id), isNot(contains('q2')));
      await editor.close();
    });

    test('"Publier" stops at an unfinished question, then publishes once it is', () async {
      final editor = cubit();
      await editor.load();
      editor.addQuestion(QuestionType.mcq);
      final added = editor.state.quiz!.questions.last;
      expect(await editor.publish(), isA<ApiFailure>().having((f) => f.code, 'code', 'quiz_question_incomplete'));
      expect(editor.state.incompleteId, added.id);
      expect(editor.state.selectedId, added.id);
      editor.removeQuestion(added.id);
      expect(editor.state.incompleteId, isNull);
      expect(await editor.publish(), isNull);
      expect(editor.state.document!.published, isTrue);
      expect(content.updates.single.$1, 'quiz1');
      await editor.close();
    });
  });

  group('QuizPlayerCubit', () {
    test('a choice is saved at once, a typed answer when the pupil stops; sending grades it', () async {
      final player = QuizPlayerCubit(HomeworkQuizSession(quizzes, 'hw1'), typingPause: const Duration(milliseconds: 5));
      await player.load();
      expect(player.state.questions, hasLength(5));
      expect(player.state.questions.first.correct, isNull);
      player.choose('q1', {'choice': 'a'});
      await Future<void>.delayed(Duration.zero);
      expect(quizzes.savedAnswers.single, {
        'q1': {'choice': 'a'},
      });
      player.type('q3', {'text': '1'});
      expect(player.state.unsaved, contains('q3'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(player.state.unsaved, isEmpty);
      expect(player.state.answeredCount, 2);
      expect(await player.submit(), isNull);
      expect(player.state.review!.autoScore, 4);
      expect(player.state.review!.pending, isTrue);
      await player.close();
    });

    test('when the time is up the server sent it: the player shows the grade', () async {
      final player = QuizPlayerCubit(HomeworkQuizSession(quizzes, 'hw1'));
      await player.load();
      quizzes.answersFailure = const ApiFailure(code: 'quiz_time_over', statusCode: 409);
      player.choose('q1', {'choice': 'b'});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(player.state.review, isNotNull);
      await player.close();
    });

    test('"Aperçu élève" saves nothing and shows every right answer', () async {
      final player = QuizPlayerCubit(PreviewQuizSession(quizzes, sampleQuiz(), () => now));
      await player.load();
      expect(player.state.attempt!.endsAt, now.add(const Duration(minutes: 15)));
      player.choose('q1', {'choice': 'a'});
      await player.submit();
      expect(quizzes.savedAnswers, isEmpty);
      expect(player.state.review!.answersShown, isTrue);
      expect(player.state.review!.items.first.right, isTrue);
      await player.close();
    });
  });

  group('QuizCorrectionCubit', () {
    test('an open question takes points in half points up to its own', () async {
      final copies = [const RecipientRow(studentId: 's1', firstName: 'Adam', lastName: 'Gharbi')];
      final correction = QuizCorrectionCubit(quizzes, 'hw1', copies);
      await correction.load();
      expect(correction.state.scores.keys, ['q5']);
      correction.setScore('q5', '3,5');
      expect(await correction.save(), isFalse);
      expect(correction.state.errors, {'q5'});
      correction.setScore('q5', '2,5');
      correction.setComment('Bonne idée.');
      expect(await correction.save(), isTrue);
      expect(quizzes.corrections.single.$2, {'q5': 2.5});
      expect(quizzes.corrections.single.$3, 'Bonne idée.');
      await correction.close();
    });
  });

  group('screens', () {
    testWidgets('the builder: settings, the five questions, a new true / false, every field with a hint', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, const Scaffold(body: QuizEditorScreen(quizId: 'quiz1')));
      expect(find.text('Quiz : les fractions'), findsWidgets);
      expect(find.text(fr.quizSettings), findsOneWidget);
      expect(find.text(fr.questionMcq), findsWidgets);
      expect(find.text(fr.questionBlanks), findsWidgets);
      // The selected question is edited in place, with its ribbon; the others read as pupils will.
      expect(find.byType(QuillEditor), findsNWidgets(5));
      expect(find.byKey(const Key('tool-formula')), findsOneWidget);
      expectEveryFieldHasAHint(find.byType(QuizEditorScreen));

      await tester.ensureVisible(find.byKey(const Key('add-trueFalse')));
      await tester.tap(find.byKey(const Key('add-trueFalse')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(fr.answerFalse).last);
      await tester.tap(find.text(fr.answerFalse).last);
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      final saved = quizzes.saves.last.$3;
      expect(saved, hasLength(6));
      expect(saved.last.type, QuestionType.trueFalse);
      expect(saved.last.answer, isFalse);
    });

    testWidgets('"Saisie rapide QCM" adds the typed questions with their right choice', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, const Scaffold(body: QuizEditorScreen(quizId: 'quiz1')));
      await tester.tap(find.byKey(const Key('quiz-quick')));
      await tester.pumpAndSettle();
      expectEveryFieldHasAHint(find.byType(QuickQcmPanel));
      await tester.enterText(find.byKey(const Key('quick-text')), 'Quel est le plus grand nombre ?\n1/3\n1/2\n1/4');
      await tester.pumpAndSettle();
      expect(find.text(fr.addQuestions(0)), findsOneWidget);
      await tester.tap(find.byKey(const Key('typed-6-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-add')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      final added = quizzes.saves.last.$3.last;
      expect(added.type, QuestionType.mcq);
      expect(added.choices.map((c) => c.text), ['1/3', '1/2', '1/4']);
      expect(added.correct, added.choices[1].id);
      expect(added.text.first['insert'], 'Quel est le plus grand nombre ?');
    });

    testWidgets('a pupil on a phone: one question per screen, the timer, then the grade', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      registerTestServices(now);
      final repo = FakeQuizRepository(timeLimitMin: 15);
      registerQuizServices(quizzes: repo);
      await pumpSignedIn(
        tester,
        QuizPlayerScreen(session: HomeworkQuizSession(repo, 'hw1'), title: 'Quiz : les fractions', name: 'Adam'),
        user: pupil,
        size: const Size(390, 844),
      );
      expect(find.text(fr.questionOf(1, 5)), findsOneWidget);
      expect(find.byKey(const Key('quiz-timer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('choice-a')));
      await tester.pumpAndSettle();
      expect(find.text(fr.answerSaved), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('quiz-next')));
        await tester.pumpAndSettle();
      }
      expect(find.text(fr.questionOf(5, 5)), findsOneWidget);
      await tester.tap(find.byKey(const Key('quiz-send')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.sendQuiz).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiz-score')), findsOneWidget);
      expect(find.text(fr.quizSentTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the gaps of a "Texte à trous" are real fields: what is typed is saved', (tester) async {
      await pumpSignedIn(
        tester,
        QuizPlayerScreen(session: HomeworkQuizSession(quizzes, 'hw1'), title: 'Quiz : les fractions'),
        user: pupil,
        size: const Size(390, 844),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('quiz-next')));
        await tester.pumpAndSettle();
      }
      expect(find.byType(GapsText), findsOneWidget);
      await tester.enterText(find.byKey(const Key('gap-b1')), 'numérateur');
      await tester.enterText(find.byKey(const Key('gap-b2')), 'dénominateur');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(quizzes.savedAnswers.last['q4'], {
        'blanks': {'b1': 'numérateur', 'b2': 'dénominateur'},
      });
    });

    testWidgets('a quiz homework: start, then each attempt with its grade', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      quizzes.attempts.add(
        AttemptSummary(id: 'att1', number: 1, startedAt: DateTime.utc(2026, 10, 12, 9), submittedAt: DateTime.utc(2026, 10, 12, 9, 10), score: 6),
      );
      await pumpSignedIn(tester, const Scaffold(body: SingleChildScrollView(child: MyQuizArea(assignmentId: 'hw1'))), user: pupil);
      expect(find.byKey(const Key('quiz-start')), findsOneWidget);
      expect(find.text(fr.startAgain), findsOneWidget);
      expect(find.text(fr.attemptNumber(1)), findsOneWidget);
      expect(find.byKey(const Key('quiz-kept')), findsOneWidget);
    });

    testWidgets('the teacher scores the open question of a quiz', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      final given = assignment('hw1', 'Quiz : les fractions', mode: SubmissionMode.quiz, contentItemId: 'quiz1');
      await pumpSignedIn(
        tester,
        QuizCorrectionBody(
          assignment: given,
          copies: const [RecipientRow(studentId: 's1', firstName: 'Adam', lastName: 'Gharbi')],
          index: 0,
        ),
      );
      expect(find.text('Adam Gharbi'), findsWidgets);
      expect(find.text('On met au même dénominateur.'), findsOneWidget);
      expectEveryFieldHasAHint(find.byType(QuizCorrectionBody));
      await tester.enterText(find.byKey(const ValueKey('score-att1-q5')), '2');
      await tester.tap(find.text(fr.save));
      await tester.pumpAndSettle();
      expect(quizzes.corrections.single.$2, {'q5': 2.0});
    });
  });
}
