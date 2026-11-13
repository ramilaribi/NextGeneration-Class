import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/tunis_time.dart';
import '../../../core/network/api_failure.dart';
import '../../../domain/model/clock_time.dart';
import '../../../domain/model/content.dart';
import '../../../domain/model/session.dart';
import '../../../domain/repositories/content_repository.dart';
import '../../../domain/repositories/group_repository.dart';
import '../common/load_status.dart';

/// What "Fin de séance" hands back to session mode.
class EndChoice extends Equatable {
  const EndChoice({required this.end, this.next, this.giveHomework = false, this.chapterId});

  final SessionEnd end;

  /// The next session of a one-off group, when planned.
  final SessionDraft? next;
  final bool giveHomework;
  final String? chapterId;

  @override
  List<Object?> get props => [end, next, giveHomework, chapterId];
}

class EndSessionState extends Equatable {
  const EndSessionState({
    this.status = LoadStatus.loading,
    this.chapters = const [],
    this.documents = const [],
    this.shared = const {},
    this.chapterId,
    this.contentIds = const {},
    this.details = '',
    this.sessionNote = '',
    this.giveHomework = false,
    this.planNext = false,
    this.nextDate,
    this.nextStart,
    this.nextEnd,
    this.failure,
  });

  final LoadStatus status;

  /// The teacher's chapters of the group's subject and level.
  final List<Chapter> chapters;

  /// Her documents, not archived.
  final List<ContentDocument> documents;

  /// The documents the group already has ("Contenu du jour").
  final Set<String> shared;
  final String? chapterId;
  final Set<String> contentIds;
  final String details;
  final String sessionNote;
  final bool giveHomework;
  final bool planNext;
  final DateTime? nextDate;
  final ClockTime? nextStart;
  final ClockTime? nextEnd;
  final ApiFailure? failure;

  /// The documents of the chosen chapter: those of the day first.
  List<ContentDocument> get chapterDocuments => chapterId == null
      ? const []
      : (documents.where((d) => d.chapterId == chapterId).toList()
          ..sort((a, b) => (shared.contains(b.id) ? 1 : 0).compareTo(shared.contains(a.id) ? 1 : 0)));

  bool get nextValid => !planNext || (nextStart != null && nextEnd != null && nextStart!.minutes < nextEnd!.minutes);

  EndSessionState copyWith({
    LoadStatus? status,
    List<Chapter>? chapters,
    List<ContentDocument>? documents,
    Set<String>? shared,
    String? Function()? chapterId,
    Set<String>? contentIds,
    String? details,
    String? sessionNote,
    bool? giveHomework,
    bool? planNext,
    DateTime? nextDate,
    ClockTime? nextStart,
    ClockTime? nextEnd,
    ApiFailure? Function()? failure,
  }) => EndSessionState(
    status: status ?? this.status,
    chapters: chapters ?? this.chapters,
    documents: documents ?? this.documents,
    shared: shared ?? this.shared,
    chapterId: chapterId != null ? chapterId() : this.chapterId,
    contentIds: contentIds ?? this.contentIds,
    details: details ?? this.details,
    sessionNote: sessionNote ?? this.sessionNote,
    giveHomework: giveHomework ?? this.giveHomework,
    planNext: planNext ?? this.planNext,
    nextDate: nextDate ?? this.nextDate,
    nextStart: nextStart ?? this.nextStart,
    nextEnd: nextEnd ?? this.nextEnd,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    status,
    chapters,
    documents,
    shared,
    chapterId,
    contentIds,
    details,
    sessionNote,
    giveHomework,
    planNext,
    nextDate,
    nextStart,
    nextEnd,
    failure?.code,
  ];
}

/// "Fin de séance" (Release 4, designs `r4/FinDeSeance.png`, `r4/FinDeSeancePhone.png`): prefilled with what the
/// session already says, or the chapter and documents of the day, and the quick note. Nothing is required.
class EndSessionCubit extends Cubit<EndSessionState> {
  EndSessionCubit(this._contents, this._groups, {required this.detail, String quickNote = ''})
    : super(EndSessionState(sessionNote: detail.sessionNote ?? quickNote));

  final ContentRepository _contents;
  final GroupRepository _groups;
  final SessionDetail detail;

  Session get session => detail.session;

  Future<void> load() async {
    // A one-off session (a private lesson) proposes the next one, the same day next week at the same time.
    final day = TunisTime.day(session.startsAt);
    emit(
      state.copyWith(
        planNext: !session.recurring,
        nextDate: TunisTime.addDays(day, 7),
        nextStart: TunisTime.clock(session.startsAt),
        nextEnd: TunisTime.clock(session.endsAt),
      ),
    );
    try {
      // The chapters of the group's subject and level.
      final (library, groups) = await (_contents.library(), _groups.list()).wait;
      if (isClosed) return;
      final group = groups.where((g) => g.id == session.group.id).firstOrNull;
      final chapters = library.chapters.where((c) => c.subjectId == group?.subjectId && c.levelId == group?.levelId).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      final shared = library.sharedWith(session.group.id);
      final covered = detail.covered;
      final dayChapter = shared.map((d) => d.chapterId).where((id) => chapters.any((c) => c.id == id)).firstOrNull;
      final chapterId = covered?.chapterId ?? dayChapter;
      final contentIds = covered != null
          ? {for (final d in covered.documents) d.id}
          : {
              for (final d in shared.take(3))
                if (d.chapterId == chapterId) d.id,
            };
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          chapters: chapters,
          documents: library.documents.where((d) => d.status != ContentStatus.archived).toList(),
          shared: {for (final d in shared) d.id},
          chapterId: () => chapterId,
          contentIds: contentIds,
          details: covered?.details ?? '',
        ),
      );
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  /// Another chapter keeps only the documents of the new one.
  void setChapter(String? id) {
    final inChapter = {
      for (final d in state.documents)
        if (d.chapterId == id) d.id,
    };
    emit(state.copyWith(chapterId: () => id, contentIds: state.contentIds.intersection(inChapter)));
  }

  void toggleDocument(String id) =>
      emit(state.copyWith(contentIds: state.contentIds.contains(id) ? ({...state.contentIds}..remove(id)) : {...state.contentIds, id}));

  void setDetails(String value) => emit(state.copyWith(details: value));

  void setSessionNote(String value) => emit(state.copyWith(sessionNote: value));

  void setGiveHomework(bool value) => emit(state.copyWith(giveHomework: value));

  void setPlanNext(bool value) => emit(state.copyWith(planNext: value));

  void setNextDate(DateTime value) => emit(state.copyWith(nextDate: value));

  void setNextStart(ClockTime value) => emit(state.copyWith(nextStart: value));

  void setNextEnd(ClockTime value) => emit(state.copyWith(nextEnd: value));

  /// What session mode sends; null while the next session's times are wrong.
  EndChoice? choice() {
    if (!state.nextValid) return null;
    final details = state.details.trim();
    return EndChoice(
      end: SessionEnd(
        chapterId: state.chapterId,
        contentIds: [
          for (final d in state.documents)
            if (state.contentIds.contains(d.id)) d.id,
        ],
        details: details.isEmpty ? null : details,
        sessionNote: state.sessionNote.trim(),
      ),
      next: session.recurring || !state.planNext
          ? null
          : SessionDraft(
              groupId: session.group.id,
              date: state.nextDate!,
              start: state.nextStart!,
              end: state.nextEnd!,
              mode: session.mode,
              location: session.location,
            ),
      giveHomework: state.giveHomework,
      chapterId: state.chapterId,
    );
  }
}
