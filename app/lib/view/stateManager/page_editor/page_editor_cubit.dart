import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/tunis_time.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/model/content.dart';
import '../../../domain/model/written_page.dart';
import '../../../domain/repositories/content_repository.dart';
import '../../../domain/repositories/page_repository.dart';
import '../common/load_status.dart';

/// Where the page stands with the server: everything saved, a change waiting for the pause, being sent,
/// or not sent (the next change or "Réessayer" sends it again).
enum PageSave { saved, pending, saving, failed }

class PageEditorState extends Equatable {
  const PageEditorState({
    this.status = LoadStatus.loading,
    this.page,
    this.document,
    this.pictureUrls = const {},
    this.save = PageSave.saved,
    this.savedAt,
    this.publishing = false,
    this.failure,
  });

  final LoadStatus status;

  /// As opened: the editor builds its documents from it once.
  final WrittenPage? page;

  /// The library row, kept current (title, status, date).
  final ContentDocument? document;

  /// By picture id; pictures added while writing come in here.
  final Map<String, String> pictureUrls;
  final PageSave save;
  final DateTime? savedAt;
  final bool publishing;

  /// The page could not be opened.
  final ApiFailure? failure;

  bool get unsaved => save != PageSave.saved;

  PageEditorState copyWith({
    LoadStatus? status,
    WrittenPage? page,
    ContentDocument? document,
    Map<String, String>? pictureUrls,
    PageSave? save,
    DateTime? savedAt,
    bool? publishing,
    ApiFailure? Function()? failure,
  }) => PageEditorState(
    status: status ?? this.status,
    page: page ?? this.page,
    document: document ?? this.document,
    pictureUrls: pictureUrls ?? this.pictureUrls,
    save: save ?? this.save,
    savedAt: savedAt ?? this.savedAt,
    publishing: publishing ?? this.publishing,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, page, document, pictureUrls, save, savedAt, publishing, failure?.code];
}

/// The Word-like page (release 3, design `r3/EditeurDocument.png`): saved on its own a moment after the
/// teacher stops typing, both documents whole; "Publier" saves what is left first.
class PageEditorCubit extends Cubit<PageEditorState> {
  PageEditorCubit(this._pages, this._contents, this._now, this.id, {this.pause = const Duration(milliseconds: 1200)})
    : super(const PageEditorState());

  final PageRepository _pages;
  final ContentRepository _contents;
  final Now _now;
  final String id;

  /// How long the teacher stops typing before the page is sent.
  final Duration pause;

  Timer? _timer;
  List<Map<String, dynamic>>? _body;
  List<Map<String, dynamic>>? _answerBody;

  /// Changes made while a save was on its way: sent right after it.
  bool _again = false;
  Future<void>? _sending;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final page = await _pages.page(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          page: page,
          document: page.document,
          pictureUrls: page.pictureUrls,
          savedAt: page.document.updatedAt,
        ),
      );
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  /// The editor's documents after a change; sent after [pause].
  void changed({required List<Map<String, dynamic>> body, required List<Map<String, dynamic>> answerBody}) {
    _body = body;
    _answerBody = answerBody;
    if (state.save == PageSave.saving) {
      _again = true;
      return;
    }
    emit(state.copyWith(save: PageSave.pending));
    _timer?.cancel();
    _timer = Timer(pause, () => unawaited(_send()));
  }

  /// Sends what is waiting now (before publishing, before leaving). True when everything is saved.
  Future<bool> flush() async {
    _timer?.cancel();
    if (_sending != null) await _sending;
    if (state.save == PageSave.pending || state.save == PageSave.failed) await _send();
    return state.save == PageSave.saved;
  }

  Future<void> retry() => _send();

  Future<void> _send() {
    final body = _body;
    final answerBody = _answerBody;
    if (body == null || answerBody == null || isClosed) return Future.value();
    final sending = _sendNow(body, answerBody);
    _sending = sending;
    return sending.whenComplete(() => _sending = null);
  }

  Future<void> _sendNow(List<Map<String, dynamic>> body, List<Map<String, dynamic>> answerBody) async {
    _again = false;
    emit(state.copyWith(save: PageSave.saving));
    try {
      final document = await _pages.save(id, body: body, answerBody: answerBody);
      if (isClosed) return;
      emit(state.copyWith(document: document, save: _again ? PageSave.pending : PageSave.saved, savedAt: _now()));
    } on Object {
      if (isClosed) return;
      emit(state.copyWith(save: PageSave.failed));
      return;
    }
    if (_again) {
      _timer?.cancel();
      _timer = Timer(pause, () => unawaited(_send()));
    }
  }

  /// The picture's id once sent (its link is then known to the page), or null with nothing changed.
  Future<String?> addPicture(PickedFile picture) async {
    final uploaded = await _pages.uploadPicture(picture);
    if (isClosed) return null;
    emit(state.copyWith(pictureUrls: {...state.pictureUrls, uploaded.id: uploaded.url}));
    return uploaded.id;
  }

  /// "Publier": what is left is saved first, then the page leaves the drafts. Null when published.
  Future<ApiFailure?> publish() async {
    final document = state.document;
    if (document == null || state.publishing) return null;
    emit(state.copyWith(publishing: true));
    try {
      if (!await flush()) {
        if (!isClosed) emit(state.copyWith(publishing: false));
        return const ApiFailure(code: ApiFailure.network);
      }
      final published = await _contents.update(
        id,
        DocumentDraft(
          title: document.title,
          subjectId: document.subjectId,
          levelId: document.levelId,
          chapterId: document.chapterId,
          tag: document.tag,
        ),
      );
      if (!isClosed) emit(state.copyWith(document: published, publishing: false));
      return null;
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(publishing: false));
      return ApiFailure.from(error);
    }
  }

  /// After "Modifier les détails" or a share: the row as the server has it now.
  void documentChanged(ContentDocument document) => emit(state.copyWith(document: document));

  @override
  Future<void> close() {
    _timer?.cancel();
    // Leaving the page sends what is waiting; the screen asks first when the last save failed.
    if (state.save == PageSave.pending && _body != null && _answerBody != null) {
      unawaited(_pages.save(id, body: _body!, answerBody: _answerBody!).then((_) {}, onError: (Object _) {}));
    }
    return super.close();
  }
}
