import '../model/content.dart';
import '../model/written_page.dart';

/// The teacher's pages written in the app (release 3). Publishing, sharing and archiving are the
/// library's ([ContentRepository]), as for a file.
abstract interface class PageRepository {
  /// An empty page, a draft, placed and tagged as [draft] says.
  Future<WrittenPage> create(DocumentDraft draft);

  Future<WrittenPage> page(String id);

  /// Both documents, whole; the library row comes back with its new date.
  Future<ContentDocument> save(String id, {required List<Map<String, dynamic>> body, required List<Map<String, dynamic>> answerBody});

  /// A photo or an image for the page, made lighter first.
  Future<UploadedPicture> uploadPicture(PickedFile picture);
}
