import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ngclass/core/di/injection.dart';
import 'package:ngclass/core/l10n/app_language.dart';
import 'package:ngclass/core/l10n/formatting.dart';
import 'package:ngclass/core/router/routes.dart';
import 'package:ngclass/domain/model/clock_time.dart';
import 'package:ngclass/domain/model/content.dart';
import 'package:ngclass/domain/model/results.dart';
import 'package:ngclass/domain/model/session.dart';
import 'package:ngclass/domain/repositories/group_repository.dart';
import 'package:ngclass/domain/repositories/homework_repository.dart';
import 'package:ngclass/domain/repositories/planning_repository.dart';
import 'package:ngclass/domain/repositories/results_repository.dart';
import 'package:ngclass/view/screens/shared/my_contents_screen.dart';
import 'package:ngclass/view/screens/shared/my_results_screen.dart';
import 'package:ngclass/view/screens/teacher/homework/assign_panel.dart';
import 'package:ngclass/view/screens/teacher/planning/end_session_panel.dart';
import 'package:ngclass/view/screens/teacher/planning/session_mode_screen.dart';
import 'package:ngclass/view/stateManager/session_mode/session_mode_cubit.dart';
import 'package:ngclass/view/widgets/panels.dart';
import 'package:ngclass/view/widgets/progress_charts.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/fakes.dart';
import '../helpers/homework_fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/student_fixtures.dart' show now, pupil;

/// Release 4: the end of a session (designs `r4/FinDeSeance*.png`) and the progress charts (`r4/Progression*.png`).
void main() {
  setUpAll(initializeAppDates);

  final tuesday = DateTime.utc(2026, 10, 6);
  late FakePlanningRepository planning;
  late FakeContentRepository contents;

  setUp(() {
    registerTestServices(now);
    contents = registerContentServices().repository;
    planning = FakePlanningRepository();
    sl.registerSingleton<PlanningRepository>(planning);
    sl.registerSingleton<HomeworkRepository>(FakeHomeworkRepository());
    sl.registerSingleton<GroupRepository>(FakeGroupRepository());
    sl.registerSingleton<ResultsRepository>(FakeResultsRepository());
  });

  SessionDetail detail({bool recurring = true, PreviousSession? previous}) => SessionDetail(
    session: session('s1', tuesday, const ClockTime(10, 0), status: SessionStatus.inProgress, recurring: recurring),
    roster: const [
      RosterEntry(studentId: 'a', firstName: 'Amine', lastName: 'Kefi'),
      RosterEntry(studentId: 'b', firstName: 'Omar', lastName: 'Saidi'),
    ],
    previous: previous,
  );

  Widget sessionMode() => BlocProvider(
    create: (_) => SessionModeCubit(planning, 's1', attendanceDelay: Duration.zero, noteDelay: Duration.zero)..open(),
    child: const SessionModeView(),
  );

  /// Ending a session leaves for Ma journée.
  GoRouter router() => GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => sessionMode()),
      GoRoute(
        path: Routes.teacherHome,
        builder: (_, _) => const Scaffold(body: Text('Ma journée')),
      ),
    ],
  );

  Future<void> openEnd(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('end-session')));
    await tester.pumpAndSettle();
    expect(find.byType(EndSessionPanel), findsOneWidget);
  }

  group('Fin de séance', () {
    testWidgets('prefilled with the chapter and documents of the day; what was covered is sent', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      planning.detailResult = detail();
      await pumpSignedIn(tester, const SizedBox(), router: router(), size: const Size(1440, 1100));
      await tester.tap(find.text('Omar Saidi'));
      await tester.pumpAndSettle();
      await openEnd(tester);

      expectEveryFieldHasAHint(find.byType(SidePanel));
      // ignore: avoid_print
      expect(find.text(fr.absentCount(1) + fr.dotSeparator + isolated('Omar Saidi')), findsOneWidget);
      // The chapter of the day's documents, its documents of the day ticked.
      expect(find.text('Les fractions'), findsWidgets);
      expect(find.byKey(const Key('end-document-serie2')), findsOneWidget);
      expect(find.text(fr.endNextInSeries), findsOneWidget, reason: 'a weekly session plans nothing');
      await tester.enterText(find.byKey(const Key('end-details')), 'Exercices 1 à 4.');
      await tester.enterText(find.byKey(const Key('end-note')), 'Revoir la simplification.');
      await tester.tap(find.byKey(const Key('end-document-lecon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('end-confirm')));
      await tester.pumpAndSettle();

      final sent = planning.endings.single;
      expect(sent.chapterId, 'ch-fr');
      // The three documents of the day were ticked; "Leçon" was unticked.
      expect(sent.contentIds, ['serie2', 'photo']);
      expect(sent.details, 'Exercices 1 à 4.');
      expect(sent.sessionNote, 'Revoir la simplification.');
      expect(planning.drafts, isEmpty);
      expect(find.text('Ma journée'), findsOneWidget);
    });

    testWidgets('a one-off session plans the next one; "Donner un devoir" opens Nouveau devoir', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      planning.detailResult = detail(recurring: false);
      await pumpSignedIn(tester, const SizedBox(), router: router(), size: const Size(1440, 1100));
      await openEnd(tester);
      expect(find.text(fr.endPlanNext), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('end-give-homework')));
      await tester.tap(find.text(fr.endGiveHomework));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('end-confirm')));
      await tester.pumpAndSettle();

      final next = planning.drafts.single;
      expect(next.date, DateTime.utc(2026, 10, 13));
      expect(next.start, const ClockTime(10, 0));
      expect(next.groupId, 'g4a');
      expect(find.byType(AssignPanel), findsOneWidget);
    });

    testWidgets('"Retour" goes back to the attendance and ends nothing', (tester) async {
      planning.detailResult = detail();
      await pumpSignedIn(tester, sessionMode(), size: const Size(1440, 1100));
      await openEnd(tester);
      await tester.tap(find.byKey(const Key('end-edit-attendance')));
      await tester.pumpAndSettle();
      expect(find.byType(EndSessionPanel), findsNothing);
      expect(planning.ends, 0);
    });

    testWidgets('the next session opens on what the last one covered', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      planning.detailResult = detail(
        previous: PreviousSession(
          startsAt: DateTime.utc(2026, 10, 5, 9),
          sessionNote: 'Revoir la simplification.',
          covered: const Covered(
            chapterId: 'ch-fr',
            chapterTitle: 'Les fractions',
            details: 'Exercices 1 à 4.',
            documents: [CoveredDocument(id: 'serie2', title: 'Série 2 : les fractions', kind: FileKind.pdf)],
          ),
          absent: 1,
          homework: const ['Série 3 : les fractions'],
        ),
      );
      await pumpSignedIn(tester, sessionMode(), size: const Size(1440, 1100));
      final card = find.byKey(const Key('previous-session'));
      expect(find.descendant(of: card, matching: find.text(fr.previousCovered(isolated('Les fractions')))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(fr.absentCount(1))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('Exercices 1 à 4.')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Revoir la simplification.')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(fr.previousHomework(isolated('Série 3 : les fractions')))), findsOneWidget);
    });
  });

  group('Vu en classe', () {
    testWidgets('Cours marks the chapter and the documents used in class', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      contents.coveredChapters = [
        CoveredChapter(chapterId: 'ch-fr', coveredOn: DateTime.utc(2026, 10, 5, 9), details: 'Exercices 1 à 4.', contentIds: const {'serie3'}),
      ];
      await pumpSignedIn(tester, const Scaffold(body: MyContentsScreen()), user: pupil);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('seen-ch-fr')), findsOneWidget);
      expect(find.textContaining(fr.seenInClassOn('')), findsWidgets);
      expect(find.textContaining('Exercices 1 à 4.'), findsOneWidget);
    });
  });

  group('progress charts', () {
    testWidgets('the year of grades: a line per subject, a point shows its grade, the table has the same numbers', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(
        tester,
        const Scaffold(body: MyResultsScreen()),
        user: pupil,
        size: const Size(1440, 1400),
      );
      await tester.pumpAndSettle();
      expect(find.text(fr.chartGradesTitle), findsOneWidget);
      expect(find.text(fr.chartMonthlyTitle), findsOneWidget);
      expect(find.textContaining(fr.chaptersSeen, findRichText: true), findsWidgets);

      // The October grades sit in the second month: tap the chart there.
      final chart = find.descendant(of: find.byType(GradesChartCard), matching: find.byType(CustomPaint)).last;
      final box = tester.getRect(chart);
      for (var x = box.left + box.width * 0.1; x < box.left + box.width * 0.3; x += 3) {
        await tester.tapAt(Offset(x, box.top + box.height * 0.3));
        await tester.pump();
        if (find.byKey(const Key('grade-tooltip')).evaluate().isNotEmpty) break;
      }
      expect(find.byKey(const Key('grade-tooltip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('grades-table')));
      await tester.pumpAndSettle();
      expect(find.byType(GradesTablePanel), findsOneWidget);
      expect(find.text('Série D'), findsWidgets);
      await tester.tap(find.text(fr.tableMonths).last);
      await tester.pumpAndSettle();
      expect(find.text(fr.percentValue(90)), findsOneWidget);
    });

    testWidgets('one grade is not a curve yet', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      final one = sampleResults().subjects.first;
      await pumpSignedIn(
        tester,
        Scaffold(
          body: GradesChartCard(
            results: MyResults(
              subjects: [
                SubjectResult(subject: one.subject, submitted: 1, due: 1, average: 16, gradeCount: 1, grades: [one.grades.first]),
              ],
            ),
            now: now,
            onTable: () {},
          ),
        ),
      );
      expect(find.text(fr.chartOneGrade), findsOneWidget);
    });
  });
}
