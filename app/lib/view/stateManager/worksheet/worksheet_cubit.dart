import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/platform/document_printer.dart';
import '../../../domain/model/content.dart';
import '../../../domain/model/quiz.dart';
import '../../../domain/model/worksheet.dart';
import '../../../domain/model/written_page.dart';
import '../../../domain/repositories/content_repository.dart';
import '../../../domain/repositories/page_repository.dart';
import '../../../domain/repositories/quiz_repository.dart';
import '../../../domain/services/worksheet_maker.dart';
import '../common/load_status.dart';

/// What the teacher does with the sheet.
enum WorksheetAction { print, download }

/// How it went: [saved] when it was also kept in Contenus.
enum WorksheetOutcome { done, saved, failed }

class WorksheetState extends Equatable {
  const WorksheetState({
    this.status = LoadStatus.loading,
    this.failure,
    this.page,
    this.quiz,
    this.options = const WorksheetOptions(title: ''),
    this.busy,
    this.savedFor,
  });

  final LoadStatus status;
  final ApiFailure? failure;
  final WrittenPage? page;
  final Quiz? quiz;
  final WorksheetOptions options;

  /// The action under way: its button turns.
  final WorksheetAction? busy;

  /// The choices last kept in Contenus: the same sheet is not kept twice.
  final WorksheetOptions? savedFor;

  ContentDocument? get document => page?.document ?? quiz?.document;

  WorksheetState copyWith({
    LoadStatus? status,
    ApiFailure? failure,
    bool clearFailure = false,
    WrittenPage? page,
    Quiz? quiz,
    WorksheetOptions? options,
    WorksheetAction? busy,
    bool idle = false,
    WorksheetOptions? savedFor,
  }) => WorksheetState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    page: page ?? this.page,
    quiz: quiz ?? this.quiz,
    options: options ?? this.options,
    busy: idle ? null : (busy ?? this.busy),
    savedFor: savedFor ?? this.savedFor,
  );

  @override
  List<Object?> get props => [status, failure, page, quiz, options, busy, savedFor];
}

/// "Imprimer une fiche" (release 3 step 4, designs `r3/Fiche.png`, `r3/FicheVersions.png`): a page written
/// in the app or a quiz, as an A4 sheet for the pupils or for the teacher; printed, downloaded, and kept
/// in Contenus as a PDF when she wants it.
class WorksheetCubit extends Cubit<WorksheetState> {
  WorksheetCubit(this._pages, this._quizzes, this._contents, this._maker, this._printer, {required this.id, required this.kind})
    : super(const WorksheetState());

  final PageRepository _pages;
  final QuizRepository _quizzes;
  final ContentRepository _contents;
  final WorksheetMaker _maker;
  final DocumentPrinter _printer;
  final String id;

  /// [FileKind.page] or [FileKind.quiz].
  final FileKind kind;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, clearFailure: true));
    try {
      if (kind == FileKind.quiz) {
        final quiz = await _quizzes.quiz(id);
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            quiz: quiz,
            options: WorksheetOptions(title: quiz.document.title),
          ),
        );
      } else {
        final page = await _pages.page(id);
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            page: page,
            options: WorksheetOptions(title: page.document.title),
          ),
        );
      }
    } on ApiFailure catch (failure) {
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
    }
  }

  void setOptions(WorksheetOptions options) => emit(state.copyWith(options: options));

  /// Builds the PDF of [sheet], prints it or saves it on the device, then keeps it in Contenus when asked.
  Future<WorksheetOutcome> make(Worksheet sheet, WorksheetAction action, {required bool arabic}) async {
    final document = state.document;
    if (document == null || state.busy != null) return WorksheetOutcome.failed;
    emit(state.copyWith(busy: action));
    final fileName = '${_fileName(sheet.title)}.pdf';
    try {
      final Uint8List bytes = await _maker.pdf(sheet, arabic: arabic);
      if (action == WorksheetAction.print) {
        await _printer.printPdf(fileName, (_) async => bytes);
      } else {
        await _printer.share(fileName, bytes);
      }
      final options = state.options;
      if (!options.saveToLibrary || options == state.savedFor) {
        emit(state.copyWith(idle: true));
        return WorksheetOutcome.done;
      }
      await _contents.upload(
        DocumentDraft(
          title: sheet.title,
          subjectId: document.subjectId,
          levelId: document.levelId,
          chapterId: document.chapterId,
          tag: options.teacher ? ContentTag.corrige : ContentTag.serie,
        ),
        PickedFile(name: fileName, bytes: bytes),
      );
      emit(state.copyWith(idle: true, savedFor: options));
      return WorksheetOutcome.saved;
    } on Object {
      emit(state.copyWith(idle: true));
      return WorksheetOutcome.failed;
    }
  }

  /// "Contrôle : les fractions" → "Contrôle - les fractions": a name every device accepts.
  static String _fileName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' -').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? 'fiche' : cleaned;
  }
}
