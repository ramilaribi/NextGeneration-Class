import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngclass/core/di/injection.dart';
import 'package:ngclass/core/l10n/app_language.dart';
import 'package:ngclass/core/l10n/formatting.dart';
import 'package:ngclass/core/platform/document_printer.dart';
import 'package:ngclass/data/files/worksheet_pdf.dart';
import 'package:ngclass/domain/model/content.dart';
import 'package:ngclass/domain/model/worksheet.dart';
import 'package:ngclass/domain/repositories/page_repository.dart';
import 'package:ngclass/domain/repositories/quiz_repository.dart';
import 'package:ngclass/domain/services/worksheet_layout.dart';
import 'package:ngclass/domain/services/worksheet_maker.dart';
import 'package:ngclass/view/screens/teacher/contents/worksheet_screen.dart';
import 'package:ngclass/view/stateManager/common/load_status.dart';
import 'package:ngclass/view/stateManager/worksheet/worksheet_cubit.dart';
import 'package:ngclass/view/widgets/worksheet_preview.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/page_fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/quiz_fixtures.dart';
import '../helpers/student_fixtures.dart' show now;
import 'student_import_test.dart' show FakeDocumentPrinter;

/// Release 3 step 4: printed sheets (designs `r3/Fiche.png`, `r3/FicheVersions.png`).
void main() {
  setUpAll(initializeAppDates);

  final words = SheetWords(
    answerTrue: 'Vrai',
    answerFalse: 'Faux',
    answer: 'Réponse :',
    or: ' ou ',
    explanation: 'Explication :',
    toCorrect: 'Question ouverte : à corriger.',
    corrige: 'Corrigé',
    points: (p) => p == 1 ? '1 pt' : '$p pts',
  );
  final labels = SheetLabels(
    words: words,
    place: 'Mathématiques · 4ème année · Les fractions',
    date: '6 octobre 2026',
    teacherName: 'Ines Haddad',
    nameLabel: 'Nom et prénom :',
    markLabel: 'Note :',
    corrigeTitle: (title) => '$title · Corrigé',
  );

  group('layout', () {
    test('a page: its formats, formula, table and lines; the Corrigé after a new page for the teacher only', () {
      final pupil = pageBlocks(samplePageBody(), sampleAnswer(), teacher: false, pictureUrls: const {}, words: words);
      expect(pupil.first, const SheetLine([SheetText('Exercice 1', bold: true)]));
      expect(pupil[1], const SheetLine([SheetText('Calcule : '), SheetFormula('3/4 + 1/2'), SheetText(' = ')]));
      expect(pupil.whereType<SheetTable>().single.rows.first, ['Fraction', r'$3/5$', r'$4/7$']);
      expect(pupil.whereType<SheetLines>().single.count, 2);
      expect(pupil.last, const SheetLine([SheetText('أحسب')]));
      expect(pupil.whereType<SheetPageBreak>(), isEmpty);

      final teacher = pageBlocks(samplePageBody(), sampleAnswer(), teacher: true, pictureUrls: const {}, words: words);
      final cut = teacher.indexWhere((b) => b is SheetPageBreak);
      expect(cut, greaterThan(0));
      expect(teacher[cut + 1], const SheetLine([SheetText('Corrigé')], heading: 1));
      expect(teacher.last, const SheetLine([SheetText('Réponse : 5/4')]));
    });

    test('a quiz: the same questions; only the answers differ between the two versions', () {
      final quiz = sampleQuiz();
      final pupil = quizBlocks(quiz, teacher: false, words: words);
      final teacher = quizBlocks(quiz, teacher: true, words: words);
      expect(pupil.whereType<SheetQuestion>().map((q) => q.points), ['2 pts', '1 pt', '2 pts', '2 pts', '3 pts']);
      expect(teacher.whereType<SheetQuestion>().map((q) => (q.number, q.points)), pupil.whereType<SheetQuestion>().map((q) => (q.number, q.points)));
      // "2/4" typed as a choice prints as a fraction, as on screen; the right one is marked for the teacher only.
      expect(pupil.whereType<SheetChoices>().first.choices, [(r'$2/4$', false), (r'$2/3$', false), (r'$3/4$', false)]);
      expect(teacher.whereType<SheetChoices>().first.choices.first, (r'$2/4$', true));
      expect(teacher.whereType<SheetChoices>().elementAt(1).choices, [('Vrai', true), ('Faux', false)]);
      // The gaps: dots for the pupils, the answers in green for the teacher.
      List<String?> gaps(List<SheetBlock> blocks) =>
          blocks.whereType<SheetQuestion>().expand((q) => q.spans).whereType<SheetGap>().map((g) => g.answer).toList();
      expect(gaps(pupil), [null, null]);
      expect(gaps(teacher), ['numérateur', 'dénominateur']);
      // A short answer: dots, or every accepted answer; an open question: lines, and "à corriger".
      expect(pupil.whereType<SheetLine>().any((l) => l.spans.any((s) => s is SheetGap)), isTrue);
      final answer = teacher.whereType<SheetLine>().firstWhere((l) => l.spans.first == const SheetText('Réponse : '));
      expect(answer.spans.skip(1), [
        const SheetText('1 ou ', answer: true),
        const SheetFormula('4/4', answer: true),
        const SheetText(' ou 1,0', answer: true),
      ]);
      expect(pupil.whereType<SheetLines>().single.count, 3);
      expect(
        teacher.whereType<SheetLine>().any((l) => l.spans.contains(const SheetText('Question ouverte : à corriger.', answer: true, italic: true))),
        isTrue,
      );
      expect(pupil.whereType<SheetLine>().any((l) => l.spans.any((s) => s is SheetText && s.answer)), isFalse);
    });

    test('in Arabic, the answer lines and the Corrigé are written from the right', () {
      final arabic = SheetWords(
        answerTrue: 'صحيح',
        answerFalse: 'خطأ',
        answer: 'الإجابة:',
        or: ' أو ',
        explanation: 'الشرح:',
        toCorrect: 'سؤال مفتوح: للتصحيح.',
        corrige: 'إصلاح',
        points: (p) => '$p',
        rtl: true,
      );
      final teacher = quizBlocks(sampleQuiz(), teacher: true, words: arabic);
      bool arabicLabel(SheetLine l) => switch (l.spans.firstOrNull) {
        SheetText(:final text) => text.startsWith('ال') || text.startsWith('سؤال'),
        _ => false,
      };
      final labels = teacher.whereType<SheetLine>().where(arabicLabel);
      expect(labels, hasLength(3));
      expect(labels.every((l) => l.rtl), isTrue);
      // The questions keep their own direction: these are written in French.
      expect(teacher.whereType<SheetQuestion>().every((q) => !q.rtl), isTrue);
      final page = pageBlocks(samplePageBody(), sampleAnswer(), teacher: true, pictureUrls: const {}, words: arabic);
      expect(page.whereType<SheetLine>().firstWhere((l) => l.heading == 1).rtl, isTrue);
    });

    test('the header follows the choices; the teacher\'s quiz is titled Corrigé and marked out of its points', () {
      const options = WorksheetOptions(title: 'Contrôle : les fractions', showDate: false, showTeacher: false);
      final sheet = worksheetOf(quiz: sampleQuiz(), options: options, labels: labels);
      expect(sheet.title, 'Contrôle : les fractions');
      expect(sheet.place, labels.place);
      expect(sheet.date, isNull);
      expect(sheet.teacherName, isNull);
      expect(sheet.mark, '/ 10');
      expect(worksheetOf(quiz: sampleQuiz(), options: options.copyWith(teacher: true), labels: labels).title, 'Contrôle : les fractions · Corrigé');
      final page = worksheetOf(
        page: samplePage(),
        options: const WorksheetOptions(title: ' ', showPlace: false),
        labels: labels,
      );
      expect(page.title, 'Série 3 : les fractions');
      expect(page.place, isNull);
      expect(page.mark, isNull);
    });
  });

  group('PDF', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final maker = PdfWorksheetMaker(formulas: (source, {required answer, required size}) async => (png: _pixel, width: 18.0, height: 14.0));

    test('a page and a quiz print as A4 PDFs with the app\'s fonts, in French and in Arabic', () async {
      for (final teacher in [false, true]) {
        final options = WorksheetOptions(title: 'Série 3', teacher: teacher);
        for (final sheet in [
          worksheetOf(page: samplePage(), options: options, labels: labels),
          worksheetOf(quiz: sampleQuiz(), options: options, labels: labels),
        ]) {
          for (final arabic in [false, true]) {
            final bytes = await maker.pdf(sheet, arabic: arabic);
            expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
          }
        }
      }
    });
  });

  group('cubit', () {
    late FakeWorksheetMaker maker;
    late FakeDocumentPrinter printer;
    late FakeContentRepository contents;

    setUp(() {
      maker = FakeWorksheetMaker();
      printer = FakeDocumentPrinter();
      contents = FakeContentRepository();
    });

    WorksheetCubit cubitFor(FileKind kind, String id) =>
        WorksheetCubit(FakePageRepository(), FakeQuizRepository(), contents, maker, printer, id: id, kind: kind);

    test('loads the quiz, prints, and keeps the sheet in Contenus once per choice of settings', () async {
      final cubit = cubitFor(FileKind.quiz, 'quiz1');
      await cubit.load();
      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.options.title, 'Quiz : les fractions');
      final sheet = worksheetOf(quiz: cubit.state.quiz, options: cubit.state.options, labels: labels);

      expect(await cubit.make(sheet, WorksheetAction.print, arabic: false), WorksheetOutcome.done);
      expect(printer.printed, ['Quiz - les fractions.pdf']);
      expect(contents.uploads, isEmpty);

      cubit.setOptions(cubit.state.options.copyWith(saveToLibrary: true));
      expect(await cubit.make(sheet, WorksheetAction.download, arabic: false), WorksheetOutcome.saved);
      expect(printer.shared, ['Quiz - les fractions.pdf']);
      final (draft, file) = contents.uploads.single;
      expect((draft.title, draft.subjectId, draft.levelId, draft.tag), ('Quiz : les fractions', 'math', 'l4', ContentTag.serie));
      expect(file.extension, 'pdf');

      // Printed again as it is: not kept twice. The teacher's version is another sheet, kept as a Corrigé.
      expect(await cubit.make(sheet, WorksheetAction.print, arabic: false), WorksheetOutcome.done);
      cubit.setOptions(cubit.state.options.copyWith(teacher: true));
      expect(await cubit.make(sheet, WorksheetAction.print, arabic: true), WorksheetOutcome.saved);
      expect(contents.uploads.last.$1.tag, ContentTag.corrige);
      expect(maker.arabic.last, isTrue);
    });

    test('a page that cannot be made says so', () async {
      final cubit = cubitFor(FileKind.page, 'page1');
      await cubit.load();
      maker.fail = true;
      final sheet = worksheetOf(page: cubit.state.page, options: cubit.state.options, labels: labels);
      expect(await cubit.make(sheet, WorksheetAction.print, arabic: false), WorksheetOutcome.failed);
      expect(cubit.state.busy, isNull);
      expect(printer.printed, isEmpty);
    });
  });

  group('screen', () {
    late FakeWorksheetMaker maker;
    late FakeDocumentPrinter printer;

    setUp(() {
      registerTestServices(now);
      registerContentServices();
      maker = FakeWorksheetMaker();
      printer = FakeDocumentPrinter();
      sl.registerSingleton<PageRepository>(FakePageRepository());
      sl.registerSingleton<QuizRepository>(FakeQuizRepository());
      sl.registerSingleton<WorksheetMaker>(maker);
      sl.registerSingleton<DocumentPrinter>(printer);
    });

    testWidgets('"Fiche": the settings beside the A4 sheet; the teacher\'s version adds the answers; printed', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(
        tester,
        const Scaffold(
          body: WorksheetScreen(id: 'quiz1', kind: FileKind.quiz),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(fr.worksheetTitle('Quiz : les fractions')), findsOneWidget);
      expect(find.byType(WorksheetPreview), findsOneWidget);
      expect(find.textContaining('Explique comment'), findsOneWidget);
      expect(find.textContaining('numérateur'), findsNothing);
      expectEveryFieldHasAHint(find.byType(WorksheetSettings));

      await tester.tap(find.text(fr.worksheetTeacher));
      await tester.pumpAndSettle();
      expect(find.textContaining('numérateur'), findsOneWidget);
      expect(find.text('Quiz : les fractions${fr.dotSeparator}${fr.tagCorrige}'), findsOneWidget);

      await tester.tap(find.text(fr.worksheetTest('Quiz : les fractions')));
      await tester.pumpAndSettle();
      expect(find.text('Contrôle : Quiz : les fractions${fr.dotSeparator}${fr.tagCorrige}'), findsOneWidget);

      await tester.tap(find.byKey(const Key('worksheet-print')));
      await tester.pumpAndSettle();
      expect(maker.sheets.single.title, 'Contrôle : Quiz : les fractions${fr.dotSeparator}${fr.tagCorrige}');
      expect(printer.printed, hasLength(1));
    });

    testWidgets('on a phone: the sheet takes the screen, the settings open in a panel; "Partager"', (tester) async {
      final ar = l10nOf(AppLanguage.ar);
      await pumpSignedIn(
        tester,
        const Scaffold(
          body: WorksheetScreen(id: 'page1', kind: FileKind.page),
        ),
        language: AppLanguage.ar,
        size: const Size(390, 844),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorksheetPreview), findsOneWidget);
      expect(find.byType(WorksheetSettings), findsNothing);
      await tester.tap(find.byKey(const Key('worksheet-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(WorksheetSettings), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('worksheet-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('worksheet-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.close).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.worksheetShare));
      await tester.pumpAndSettle();
      expect(printer.shared, hasLength(1));
      expect(maker.arabic.single, isTrue);
      expect(find.text(ar.worksheetSaved), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A transparent pixel: the formula pictures of the PDF test.
final _pixel = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class FakeWorksheetMaker implements WorksheetMaker {
  final sheets = <Worksheet>[];
  final arabic = <bool>[];
  bool fail = false;

  @override
  Future<Uint8List> pdf(Worksheet sheet, {required bool arabic}) async {
    if (fail) throw StateError('no pdf');
    sheets.add(sheet);
    this.arabic.add(arabic);
    return Uint8List.fromList(ascii.encode('%PDF-1.4 fake'));
  }
}
