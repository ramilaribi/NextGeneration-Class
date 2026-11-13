import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/model/announcement.dart';
import '../../../domain/repositories/announcement_repository.dart';

enum AnnouncementFormError { recipients, title, body }

class AnnouncementFormState extends Equatable {
  const AnnouncementFormState({
    this.toOnePupil = false,
    this.groupIds = const [],
    this.studentId,
    this.audience = Audience.parents,
    this.title = '',
    this.body = '',
    this.errors = const {},
    this.sending = false,
    this.failure,
  });

  /// "Un élève" rather than "Des groupes".
  final bool toOnePupil;
  final List<String> groupIds;
  final String? studentId;
  final Audience audience;
  final String title;
  final String body;
  final Set<AnnouncementFormError> errors;
  final bool sending;
  final ApiFailure? failure;

  AnnouncementFormState copyWith({
    bool? toOnePupil,
    List<String>? groupIds,
    String? Function()? studentId,
    Audience? audience,
    String? title,
    String? body,
    Set<AnnouncementFormError>? errors,
    bool? sending,
    ApiFailure? Function()? failure,
  }) => AnnouncementFormState(
    toOnePupil: toOnePupil ?? this.toOnePupil,
    groupIds: groupIds ?? this.groupIds,
    studentId: studentId != null ? studentId() : this.studentId,
    audience: audience ?? this.audience,
    title: title ?? this.title,
    body: body ?? this.body,
    errors: errors ?? this.errors,
    sending: sending ?? this.sending,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [toOnePupil, groupIds, studentId, audience, title, body, errors, sending, failure?.code];
}

/// "Nouvelle annonce" (design `r4/NouvelleAnnonce.png`): groups or one pupil, pupils, parents or both, a title
/// and a message. Sent at once; no reply (question Q9).
class AnnouncementFormCubit extends Cubit<AnnouncementFormState> {
  AnnouncementFormCubit(this._repository, {String? groupId}) : super(AnnouncementFormState(groupIds: groupId == null ? const [] : [groupId]));

  final AnnouncementRepository _repository;

  void setOnePupil(bool value) => emit(state.copyWith(toOnePupil: value, errors: state.errors.difference({AnnouncementFormError.recipients})));

  void toggleGroup(String id) => emit(
    state.copyWith(
      groupIds: state.groupIds.contains(id) ? state.groupIds.where((g) => g != id).toList() : [...state.groupIds, id],
      errors: state.errors.difference({AnnouncementFormError.recipients}),
    ),
  );

  void setStudent(String id) => emit(state.copyWith(studentId: () => id, errors: state.errors.difference({AnnouncementFormError.recipients})));

  void setAudience(Audience audience) => emit(state.copyWith(audience: audience));

  void setTitle(String value) => emit(state.copyWith(title: value, errors: state.errors.difference({AnnouncementFormError.title})));

  void setBody(String value) => emit(state.copyWith(body: value, errors: state.errors.difference({AnnouncementFormError.body})));

  /// The announcement sent, or null with the reason in the state.
  Future<Announcement?> send() async {
    if (state.sending) return null;
    final errors = {
      if (state.toOnePupil ? state.studentId == null : state.groupIds.isEmpty) AnnouncementFormError.recipients,
      if (state.title.trim().isEmpty) AnnouncementFormError.title,
      if (state.body.trim().isEmpty) AnnouncementFormError.body,
    };
    if (errors.isNotEmpty) {
      emit(state.copyWith(errors: errors));
      return null;
    }
    emit(state.copyWith(sending: true, failure: () => null));
    try {
      final sent = await _repository.send(
        AnnouncementDraft(
          title: state.title,
          body: state.body,
          audience: state.audience,
          groupIds: state.toOnePupil ? const [] : state.groupIds,
          studentId: state.toOnePupil ? state.studentId : null,
        ),
      );
      if (!isClosed) emit(state.copyWith(sending: false));
      return sent;
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(sending: false, failure: () => ApiFailure.from(error)));
      return null;
    }
  }
}
