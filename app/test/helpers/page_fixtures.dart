import 'package:ngclass/core/di/injection.dart';
import 'package:ngclass/core/network/api_failure.dart';
import 'package:ngclass/domain/model/content.dart';
import 'package:ngclass/domain/model/written_page.dart';
import 'package:ngclass/domain/repositories/page_repository.dart';

import 'content_fixtures.dart';
import 'fakes.dart' show math;

/// "Série 3 : les fractions", written in the app, a draft of 4ème année · Maths, chapter "Les fractions".
ContentDocument pageDocument({ContentStatus status = ContentStatus.draft}) =>
    doc('page1', 'Série 3 : les fractions', kind: FileKind.page, status: status, shared: const []);

/// A title, a formula, a table, answer lines and an Arabic line; the Corrigé has one line.
List<Map<String, dynamic>> samplePageBody() => [
  {
    'insert': 'Exercice 1',
    'attributes': {'bold': true},
  },
  {'insert': '\nCalcule : '},
  {
    'insert': {'formula': '3/4 + 1/2'},
  },
  {'insert': ' = \n'},
  {
    'insert': {
      'table': {
        'rows': [
          ['Fraction', r'$3/5$', r'$4/7$'],
          [r'Plus grande que $1/2$ ?', '', ''],
        ],
      },
    },
  },
  {'insert': '\n'},
  {
    'insert': {
      'lines': {'count': 2},
    },
  },
  {'insert': '\nأحسب\n'},
];

List<Map<String, dynamic>> sampleAnswer() => [
  {'insert': 'Réponse : 5/4\n'},
];

/// The page as pupils and parents open it: the text, never the Corrigé.
DocumentView samplePageView() => DocumentView(
  id: 'page1',
  title: 'Série 3 : les fractions',
  subjectName: math,
  chapterTitle: 'Les fractions',
  kind: FileKind.page,
  tag: ContentTag.serie,
  fileName: '',
  sizeBytes: 0,
  pageUrls: const [],
  downloadUrl: null,
  body: samplePageBody(),
);

WrittenPage samplePage({ContentStatus status = ContentStatus.draft}) =>
    WrittenPage(document: pageDocument(status: status), body: samplePageBody(), answerBody: sampleAnswer());

/// Keeps the pages in memory and records what the editor sends.
class FakePageRepository implements PageRepository {
  FakePageRepository({WrittenPage? page}) : pages = {'page1': page ?? samplePage()};

  final Map<String, WrittenPage> pages;
  final List<DocumentDraft> created = [];
  final List<(String, List<Map<String, dynamic>>, List<Map<String, dynamic>>)> saves = [];
  final List<PickedFile> pictures = [];

  /// Saves fail while set (the network is down).
  ApiFailure? saveFailure;

  @override
  Future<WrittenPage> create(DocumentDraft draft) async {
    created.add(draft);
    final page = WrittenPage(
      document: ContentDocument(
        id: 'page-new',
        title: draft.title.trim(),
        subjectId: draft.subjectId,
        levelId: draft.levelId,
        chapterId: draft.chapterId,
        tag: draft.tag,
        status: ContentStatus.draft,
        kind: FileKind.page,
        fileName: '',
        sizeBytes: 0,
        updatedAt: DateTime.utc(2026, 10, 11, 9),
      ),
      body: const [
        {'insert': '\n'},
      ],
      answerBody: const [
        {'insert': '\n'},
      ],
    );
    pages[page.document.id] = page;
    return page;
  }

  @override
  Future<WrittenPage> page(String id) async => pages[id] ?? (throw const ApiFailure(code: 'content_not_found', statusCode: 404));

  @override
  Future<ContentDocument> save(String id, {required List<Map<String, dynamic>> body, required List<Map<String, dynamic>> answerBody}) async {
    if (saveFailure != null) throw saveFailure!;
    saves.add((id, body, answerBody));
    return pages[id]!.document;
  }

  @override
  Future<UploadedPicture> uploadPicture(PickedFile picture) async {
    pictures.add(picture);
    return UploadedPicture(id: 'pic${pictures.length}', url: 'http://localhost/files/pic${pictures.length}');
  }
}

/// The content services, the page repository, and the page in the library (so "Publier" finds it).
({FakeContentRepository content, FakePageRepository pages}) registerPageServices({FakePageRepository? pages}) {
  final services = registerContentServices();
  final repo = pages ?? FakePageRepository();
  services.repository.library_ = services.repository.library_.copyWith(
    documents: [...services.repository.library_.documents, for (final p in repo.pages.values) p.document],
  );
  sl.registerSingleton<PageRepository>(repo);
  return (content: services.repository, pages: repo);
}
