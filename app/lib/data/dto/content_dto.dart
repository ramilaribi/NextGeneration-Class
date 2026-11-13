import '../../domain/model/content.dart';
import '../../domain/model/written_page.dart';
import 'school_dto.dart';
import 'user_dto.dart';

ContentTag contentTag(Object? value) => switch (value) {
  'SERIE' => ContentTag.serie,
  'COURS' => ContentTag.cours,
  'CORRIGE' => ContentTag.corrige,
  _ => ContentTag.autre,
};

String contentTagParam(ContentTag tag) => tag.name.toUpperCase();

ContentStatus contentStatus(Object? value) => switch (value) {
  'DRAFT' => ContentStatus.draft,
  'ARCHIVED' => ContentStatus.archived,
  _ => ContentStatus.published,
};

FileKind fileKind(Object? value) => switch (value) {
  'IMAGE' => FileKind.image,
  'WORD' => FileKind.word,
  'PAGE' => FileKind.page,
  'QUIZ' => FileKind.quiz,
  _ => FileKind.pdf,
};

List<String> _ids(Object? value) => (value as List<dynamic>? ?? const []).cast<String>();

Chapter chapterOf(Json json) => Chapter(
  id: json['id'] as String,
  subjectId: json['subjectId'] as String,
  levelId: json['levelId'] as String,
  title: json['title'] as String? ?? '',
  position: (json['position'] as num? ?? 0).toInt(),
  sharedGroupIds: _ids(json['sharedGroupIds']),
);

ContentDocument documentOf(Json json) => ContentDocument(
  id: json['id'] as String,
  title: json['title'] as String? ?? '',
  subjectId: json['subjectId'] as String,
  levelId: json['levelId'] as String,
  chapterId: json['chapterId'] as String?,
  tag: contentTag(json['tag']),
  status: contentStatus(json['status']),
  kind: fileKind(json['kind']),
  fileName: json['fileName'] as String? ?? '',
  sizeBytes: (json['sizeBytes'] as num? ?? 0).toInt(),
  pageCount: (json['pageCount'] as num?)?.toInt(),
  sharedGroupIds: _ids(json['sharedGroupIds']),
  updatedAt: instant(json['updatedAt']) ?? DateTime.now().toUtc(),
);

Library libraryOf(Json json) => Library(
  chapters: [for (final c in jsonList(json['chapters'])) chapterOf(c)],
  documents: [for (final d in jsonList(json['items'])) documentOf(d)],
);

SubjectRef subjectRefOf(Json subject) => SubjectRef(
  id: subject['id'] as String,
  name: localizedText(subject['name']),
  color: subject['color'] as String? ?? '#2B3990',
  position: (subject['position'] as num? ?? 0).toInt(),
);

SharedDocument sharedDocumentOf(Json json) {
  final subject = json['subject'] as Json;
  final chapter = json['chapter'] as Json?;
  return SharedDocument(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    tag: contentTag(json['tag']),
    kind: fileKind(json['kind']),
    pageCount: (json['pageCount'] as num?)?.toInt(),
    subject: subjectRefOf(subject),
    chapter: chapter == null
        ? null
        : ChapterRef(
            id: chapter['id'] as String,
            title: chapter['title'] as String? ?? '',
            position: (chapter['position'] as num? ?? 0).toInt(),
          ),
    sharedAt: instant(json['sharedAt']),
    isNew: json['isNew'] as bool? ?? false,
  );
}

/// The links are relative to the API base ("files/abc"): [apiBase] makes them absolute.
String absoluteLink(String apiBase, Object? path) => '${apiBase.endsWith('/') ? apiBase : '$apiBase/'}$path';

/// Delta operations as the server keeps them.
List<Map<String, dynamic>> deltaOf(Object? value) => [for (final op in value as List<dynamic>? ?? const []) Map<String, dynamic>.from(op as Map)];

Map<String, String> pictureUrlsOf(Object? value, String apiBase) => {
  for (final e in (value as Map<String, dynamic>? ?? const {}).entries) e.key: absoluteLink(apiBase, e.value),
};

WrittenPage writtenPageOf(Json json, String apiBase) => WrittenPage(
  document: documentOf(json['item'] as Json),
  body: deltaOf(json['body']),
  answerBody: deltaOf(json['answerBody']),
  pictureUrls: pictureUrlsOf(json['pictureUrls'], apiBase),
);

DocumentView documentViewOf(Json json, String apiBase) {
  String absolute(Object? path) => absoluteLink(apiBase, path);
  return DocumentView(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    subjectName: localizedText(json['subjectName']),
    chapterTitle: json['chapterTitle'] as String?,
    kind: fileKind(json['kind']),
    tag: contentTag(json['tag']),
    fileName: json['fileName'] as String? ?? '',
    sizeBytes: (json['sizeBytes'] as num? ?? 0).toInt(),
    pageUrls: [for (final p in (json['pageUrls'] as List<dynamic>? ?? const [])) absolute(p)],
    downloadUrl: json['downloadUrl'] == null ? null : absolute(json['downloadUrl']),
    body: json['body'] == null ? null : deltaOf(json['body']),
    pictureUrls: pictureUrlsOf(json['pictureUrls'], apiBase),
  );
}

Json draftJson(DocumentDraft draft, {bool withGroups = false}) => {
  'title': draft.title.trim(),
  'subjectId': draft.subjectId,
  'levelId': draft.levelId,
  'chapterId': draft.chapterId,
  'tag': contentTagParam(draft.tag),
  'draft': draft.draft,
  if (withGroups) 'groupIds': draft.groupIds,
};
