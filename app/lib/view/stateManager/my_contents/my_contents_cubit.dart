import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/model/content.dart';
import '../../../domain/repositories/content_repository.dart';
import '../common/load_status.dart';

/// A chapter (or "Sans chapitre") of a subject, with its documents, for the Cours list.
class CoursSection extends Equatable {
  const CoursSection({required this.subject, required this.chapter, required this.documents, this.covered});

  final SubjectRef subject;
  final ChapterRef? chapter;
  final List<SharedDocument> documents;

  /// "Vu en classe" (Release 4): when the chapter was last covered, and the documents used.
  final CoveredChapter? covered;

  @override
  List<Object?> get props => [subject, chapter, documents, covered];
}

class MyContentsState extends Equatable {
  const MyContentsState({
    this.status = LoadStatus.loading,
    this.documents = const [],
    this.covered = const {},
    this.subjectId,
    this.studentId,
    this.failure,
  });

  final LoadStatus status;

  /// Ordered by the server: subject, chapter, newest share first.
  final List<SharedDocument> documents;

  /// The chapters covered in class, by chapter id.
  final Map<String, CoveredChapter> covered;

  /// The subject filter; null shows everything.
  final String? subjectId;

  /// The child a parent is looking at.
  final String? studentId;
  final ApiFailure? failure;

  List<SubjectRef> get subjects {
    final seen = <String>{};
    return [
      for (final d in documents)
        if (seen.add(d.subject.id)) d.subject,
    ];
  }

  List<CoursSection> get sections {
    final out = <CoursSection>[];
    for (final d in documents.where((d) => subjectId == null || d.subject.id == subjectId)) {
      final last = out.lastOrNull;
      if (last != null && last.subject.id == d.subject.id && last.chapter?.id == d.chapter?.id) {
        out[out.length - 1] = CoursSection(subject: last.subject, chapter: last.chapter, documents: [...last.documents, d], covered: last.covered);
      } else {
        out.add(CoursSection(subject: d.subject, chapter: d.chapter, documents: [d], covered: covered[d.chapter?.id]));
      }
    }
    return out;
  }

  int get newCount => documents.where((d) => d.isNew).length;

  MyContentsState copyWith({
    LoadStatus? status,
    List<SharedDocument>? documents,
    Map<String, CoveredChapter>? covered,
    String? Function()? subjectId,
    String? Function()? studentId,
    ApiFailure? Function()? failure,
  }) => MyContentsState(
    status: status ?? this.status,
    documents: documents ?? this.documents,
    covered: covered ?? this.covered,
    subjectId: subjectId != null ? subjectId() : this.subjectId,
    studentId: studentId != null ? studentId() : this.studentId,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, documents, covered, subjectId, studentId, failure?.code];
}

/// Cours (spec 09): what is shared with the pupil's groups, for the pupil or for a parent.
class MyContentsCubit extends Cubit<MyContentsState> {
  MyContentsCubit(this._repository) : super(const MyContentsState());

  final ContentRepository _repository;

  /// [studentId] is required for a parent; switching child clears the subject filter.
  Future<void> load({String? studentId}) async {
    final otherChild = studentId != state.studentId;
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        studentId: () => studentId,
        subjectId: otherChild ? () => null : null,
        documents: otherChild ? const [] : null,
        failure: () => null,
      ),
    );
    try {
      final documents = await _repository.mine(studentId: studentId);
      // "Vu en classe" is a plus: Cours still opens without it.
      final covered = await _repository.covered(studentId: studentId).then<List<CoveredChapter>?>((c) => c, onError: (_) => null);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          documents: documents,
          covered: covered == null ? null : {for (final c in covered) c.chapterId: c},
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  void filterSubject(String? subjectId) => emit(state.copyWith(subjectId: () => subjectId));

  /// Back from the viewer: "Nouveau" goes away at once, as it did on the server.
  void opened(String documentId) => emit(state.copyWith(documents: [for (final d in state.documents) d.id == documentId ? d.opened() : d]));
}
