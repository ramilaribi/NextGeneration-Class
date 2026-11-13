import 'package:equatable/equatable.dart';

import 'content.dart';

/// A page written in the app, like in Word (release 3, design `r3/EditeurDocument.png`): its library row,
/// the page and its Corrigé as the editor's documents (Delta operations, JSON), and links to its pictures.
class WrittenPage extends Equatable {
  const WrittenPage({required this.document, required this.body, required this.answerBody, this.pictureUrls = const {}});

  final ContentDocument document;
  final List<Map<String, dynamic>> body;

  /// Read by the teacher only.
  final List<Map<String, dynamic>> answerBody;

  /// By picture id, absolute; they work for half an hour.
  final Map<String, String> pictureUrls;

  @override
  List<Object?> get props => [document, body, answerBody, pictureUrls];
}

/// A picture sent for a page: the page names it by [id], [url] shows it.
class UploadedPicture extends Equatable {
  const UploadedPicture({required this.id, required this.url});

  final String id;
  final String url;

  @override
  List<Object?> get props => [id, url];
}
