import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ngclass/core/di/injection.dart';
import 'package:ngclass/core/l10n/app_language.dart';
import 'package:ngclass/core/l10n/formatting.dart';
import 'package:ngclass/core/network/api_failure.dart';
import 'package:ngclass/core/router/routes.dart';
import 'package:ngclass/domain/model/content.dart';
import 'package:ngclass/view/screens/shared/document_screen.dart' show DocumentScreen;
import 'package:ngclass/view/screens/teacher/contents/document_form_panel.dart';
import 'package:ngclass/view/screens/teacher/contents/page/page_editor_screen.dart';
import 'package:ngclass/view/stateManager/common/load_status.dart';
import 'package:ngclass/view/stateManager/library/library_cubit.dart';
import 'package:ngclass/view/stateManager/page_editor/page_editor_cubit.dart';
import 'package:ngclass/view/widgets/panels.dart';
import 'package:ngclass/view/widgets/written_page.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/page_fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/student_fixtures.dart' show now, pupil;

/// Release 3, step 1: the Word-like page (design `r3/EditeurDocument.png`).
void main() {
  setUpAll(initializeAppDates);

  late FakeContentRepository content;
  late FakePageRepository pages;

  setUp(() {
    registerTestServices(now);
    final services = registerPageServices();
    content = services.content;
    pages = services.pages;
  });

  /// As in the teacher's shell, which holds the Scaffold.
  const editorScreen = Scaffold(body: PageEditorScreen(pageId: 'page1'));

  /// The editor's controller of the tab on screen.
  QuillController editorOf(WidgetTester tester) => tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

  Iterable<Map<String, dynamic>> embedsOf(QuillController controller, String type) => [
    for (final op in controller.document.toDelta().toJson())
      if (op['insert'] is Map && (op['insert'] as Map).containsKey(type)) Map<String, dynamic>.from(op['insert'] as Map),
  ];

  group('PageEditorCubit', () {
    PageEditorCubit cubit() => PageEditorCubit(pages, content, () => now, 'page1', pause: const Duration(milliseconds: 5));

    final body = [
      {'insert': 'Exercice 1\n'},
    ];
    final answer = [
      {'insert': '5/4\n'},
    ];

    test('the page is sent a moment after the teacher stops typing', () async {
      final editor = cubit();
      await editor.load();
      expect(editor.state.status, LoadStatus.ready);
      expect(editor.state.document?.title, 'Série 3 : les fractions');

      editor.changed(body: body, answerBody: answer);
      expect(editor.state.save, PageSave.pending);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(editor.state.save, PageSave.saved);
      expect(editor.state.savedAt, now);
      expect(pages.saves.single.$2, body);
      expect(pages.saves.single.$3, answer);
      await editor.close();
    });

    test('a save that failed waits: "Réessayer" sends it again', () async {
      final editor = cubit();
      await editor.load();
      pages.saveFailure = const ApiFailure(code: ApiFailure.network);
      editor.changed(body: body, answerBody: answer);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(editor.state.save, PageSave.failed);
      expect(await editor.flush(), isFalse);

      pages.saveFailure = null;
      await editor.retry();
      expect(editor.state.save, PageSave.saved);
      expect(pages.saves, hasLength(1));
      await editor.close();
    });

    test('"Publier" saves what is waiting first, then publishes', () async {
      final editor = cubit();
      await editor.load();
      editor.changed(body: body, answerBody: answer);
      expect(await editor.publish(), isNull);
      expect(pages.saves, hasLength(1));
      expect(content.updates.single.$1, 'page1');
      expect(content.updates.single.$2.draft, isFalse);
      expect(editor.state.document?.published, isTrue);
      await editor.close();
    });

    test('a picture sent joins the page\'s links', () async {
      final editor = cubit();
      await editor.load();
      final id = await editor.addPicture(const PickedFile(name: 'image.jpg', bytes: [1, 2, 3]));
      expect(id, 'pic1');
      expect(editor.state.pictureUrls, {'pic1': 'http://localhost/files/pic1'});
      await editor.close();
    });

    test('changes left when the page closes are still sent', () async {
      final editor = cubit();
      await editor.load();
      editor.changed(body: body, answerBody: answer);
      await editor.close();
      await Future<void>.delayed(Duration.zero);
      expect(pages.saves.single.$2, body);
    });
  });

  group('the editor', () {
    testWidgets('shows the page with its formula, table and answer lines; typing saves it', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, editorScreen);

      expect(find.text('Série 3 : les fractions'), findsWidgets);
      expect(find.byType(Math), findsWidgets);
      expect(find.byType(PageTableView), findsOneWidget);
      expect(find.byType(AnswerLinesView), findsOneWidget);
      expect(find.text(fr.publish), findsOneWidget);
      expect(find.text(fr.studentPreview), findsOneWidget);
      // Subject, level, chapter, tag and the save, in one line.
      final facts = tester.widget<Text>(find.byKey(const Key('page-facts'))).data!;
      expect(facts, contains(isolated('Les fractions')));
      expect(facts, contains(fr.tagSerie));

      final controller = editorOf(tester);
      controller.replaceText(0, 0, 'Bonjour ', const TextSelection.collapsed(offset: 8));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('page-facts'))).data, contains(fr.pageSaving));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(pages.saves, hasLength(1));
      expect(pages.saves.single.$2.first['insert'], 'Bonjour Exercice 1');
      expect(tester.widget<Text>(find.byKey(const Key('page-facts'))).data, contains(fr.pageSavedNow));
    });

    testWidgets('ƒx Formule: typed in simple notation, previewed, inserted at the cursor', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, editorScreen);
      final controller = editorOf(tester);
      controller.updateSelection(const TextSelection.collapsed(offset: 0), ChangeSource.local);

      await tester.tap(find.byKey(const Key('tool-formula')));
      await tester.pumpAndSettle();
      expect(find.text(fr.formulaPreviewEmpty), findsOneWidget);
      expectEveryFieldHasAHint(find.byType(AppDialog));
      // The templates are small buttons side by side, never bars as wide as the window.
      final fraction = tester.getRect(find.byTooltip(fr.formulaFraction));
      final power = tester.getRect(find.byTooltip(fr.formulaPower));
      expect(fraction.width, lessThan(80));
      expect(power.top, fraction.top);

      await tester.enterText(find.byKey(const Key('formula-source')), '(3/4');
      await tester.pump();
      expect(find.text(fr.formulaInvalid), findsOneWidget);

      await tester.enterText(find.byKey(const Key('formula-source')), 'sqrt(9) = 3');
      await tester.pump();
      expect(find.descendant(of: find.byKey(const Key('formula-preview')), matching: find.byType(Math)), findsOneWidget);
      await tester.tap(find.text(fr.insert));
      await tester.pumpAndSettle();

      expect(embedsOf(controller, PageEmbeds.formula).map((e) => e[PageEmbeds.formula]), contains('sqrt(9) = 3'));
      expect(controller.document.toDelta().toJson().first['insert'], {PageEmbeds.formula: 'sqrt(9) = 3'});
    });

    testWidgets('a table is filled in its window and sits on a line of its own', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, editorScreen);
      final controller = editorOf(tester);
      // The cursor in the middle of "Exercice 1".
      controller.updateSelection(const TextSelection.collapsed(offset: 4), ChangeSource.local);

      await tester.tap(find.byKey(const Key('tool-table')));
      await tester.pumpAndSettle();
      expectEveryFieldHasAHint(find.byType(AppDialog));
      await tester.enterText(find.byKey(const Key('table-cell-0-0')), 'Fraction');
      await tester.tap(find.text(fr.tableAddColumn));
      await tester.pump();
      expect(find.byKey(const Key('table-cell-0-3')), findsOneWidget);
      await tester.tap(find.text(fr.insert));
      await tester.pumpAndSettle();

      final ops = controller.document.toDelta().toJson();
      final at = ops.indexWhere((op) => op['insert'] is Map && (op['insert'] as Map).containsKey(PageEmbeds.table));
      final table = (ops[at]['insert'] as Map)[PageEmbeds.table] as Map;
      expect((table['rows'] as List).first, ['Fraction', '', '', '']);
      // "Exer" ends its line before the table, "cice 1" starts the next one.
      expect(controller.document.toPlainText(), startsWith('Exer\n\uFFFC\ncice 1'));
    });

    testWidgets('a tap on a formula opens it to change it', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, editorScreen);
      await tester.tap(find.byType(FormulaView).first);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('formula-source'))).controller!.text, '3/4 + 1/2');
      await tester.enterText(find.byKey(const Key('formula-source')), '3/4 - 1/2');
      await tester.tap(find.text(fr.validate));
      await tester.pumpAndSettle();
      expect(embedsOf(editorOf(tester), PageEmbeds.formula).single[PageEmbeds.formula], '3/4 - 1/2');
    });

    testWidgets('a line that starts in Arabic is written from the right, typed or pasted; French stays as it is', (tester) async {
      await pumpSignedIn(tester, editorScreen);
      final controller = editorOf(tester);
      final end = controller.document.length - 1;
      controller.replaceText(end, 0, '\nأحسب ناتج العملية', TextSelection.collapsed(offset: end + 18));
      await tester.pumpAndSettle();
      final arabic = controller.document.queryChild(end + 5).node! as Line;
      expect(arabic.style.attributes[Attribute.direction.key], Attribute.rtl);
      final french = controller.document.queryChild(0).node! as Line;
      expect(french.style.attributes.containsKey(Attribute.direction.key), isFalse);

      // The teacher turns it back with ¶: it stays left to right while she goes on typing.
      controller.formatText(arabic.documentOffset, arabic.length, Attribute.clone(Attribute.rtl, null));
      controller.replaceText(end + 18, 0, ' ؟', TextSelection.collapsed(offset: end + 20));
      await tester.pumpAndSettle();
      expect((controller.document.queryChild(end + 5).node! as Line).style.attributes.containsKey(Attribute.direction.key), isFalse);
    });

    testWidgets('the Corrigé is a second document, for the teacher only', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, editorScreen);
      await tester.tap(find.text(fr.tagCorrige).first);
      await tester.pumpAndSettle();
      expect(find.text(fr.pageOnlyYou), findsOneWidget);
      expect(find.text('Série 3 : les fractions${fr.dotSeparator}${fr.tagCorrige}'), findsOneWidget);
      expect(editorOf(tester).document.toPlainText(), contains('Réponse : 5/4'));
    });

    testWidgets('"Aperçu élève" shows the page as pupils read it, without the Corrigé', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, editorScreen);
      await tester.tap(find.byKey(const Key('page-preview')));
      await tester.pumpAndSettle();
      expect(find.text(fr.studentPreviewSubtitle), findsOneWidget);
      final preview = find.byType(WrittenPageView);
      expect(preview, findsOneWidget);
      expect(find.descendant(of: preview, matching: find.byType(PageTableView)), findsOneWidget);
      expect(find.textContaining('Réponse'), findsNothing);
    });

    testWidgets('"Publier" publishes the draft, then asks which groups see it', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, editorScreen);
      await tester.tap(find.byKey(const Key('page-publish')));
      await tester.pumpAndSettle();
      expect(content.updates.single.$2.draft, isFalse);
      expect(find.text(fr.shareDocumentTitle('Série 3 : les fractions')), findsOneWidget);
      await tester.tap(find.text(fr.cancel).last);
      await tester.pumpAndSettle();
      expect(find.text(fr.actionShare), findsOneWidget);
    });

    testWidgets('on a phone the ribbon sits at the bottom, the page takes the screen, in Arabic', (tester) async {
      final ar = l10nOf(AppLanguage.ar);
      await pumpSignedIn(tester, editorScreen, language: AppLanguage.ar, size: const Size(390, 844));
      expect(find.text(ar.publish), findsOneWidget);
      final ribbon = tester.getRect(find.byKey(const Key('tool-formula')));
      expect(ribbon.top, greaterThan(700));
      // The page keeps its own direction: the Arabic line is marked right to left.
      final ops = editorOf(tester).document.toDelta().toJson();
      expect(ops.last['attributes'], isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('writing and reading', () {
    testWidgets('"Écrire un document" creates a draft page and opens its editor', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      final library = sl.get<LibraryCubit>();
      await library.load();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => DocumentFormPanel.write(context, library: library),
                  child: const Text('write'),
                ),
              ),
            ),
          ),
          GoRoute(path: Routes.teacherPage(':id'), builder: (_, state) => Text('editor ${state.pathParameters['id']}')),
        ],
      );
      await pumpSignedIn(tester, const SizedBox(), router: router);
      await tester.tap(find.text('write'));
      await tester.pumpAndSettle();

      expect(find.text(fr.writeDocument), findsOneWidget);
      expect(find.text(fr.chooseFile), findsNothing);
      expectEveryFieldHasAHint(find.byType(SidePanel));
      await tester.enterText(find.byType(TextField).first, 'Série 4 : les décimaux');
      await tester.tap(find.text(fr.createAndWrite));
      await tester.pumpAndSettle();

      expect(pages.created.single.title, 'Série 4 : les décimaux');
      expect(pages.created.single.tag, ContentTag.serie);
      expect(pages.created.single.subjectId, 'math');
      expect(find.text('editor page-new'), findsOneWidget);
      await library.close();
    });

    testWidgets('a pupil reads a written page in Cours: no download, the page on its sheet', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      content.views['page1'] = samplePageView();
      await pumpSignedIn(
        tester,
        const DocumentScreen(documentId: 'page1', backTo: Routes.studentCourses),
        user: pupil,
        size: const Size(390, 844),
      );
      expect(find.byKey(const Key('written-page')), findsOneWidget);
      expect(find.byType(PageTableView), findsOneWidget);
      expect(find.byType(Math), findsWidgets);
      expect(find.text(fr.download), findsNothing);
      expect(find.text(fr.wordNoPreview), findsNothing);
    });
  });
}
