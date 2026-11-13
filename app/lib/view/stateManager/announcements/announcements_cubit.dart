import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/model/announcement.dart';
import '../../../domain/repositories/announcement_repository.dart';
import '../common/load_status.dart';

class AnnouncementsState extends Equatable {
  const AnnouncementsState({this.status = LoadStatus.loading, this.items = const [], this.groupId, this.failure});

  final LoadStatus status;
  final List<Announcement> items;

  /// The group tab chosen; null: all.
  final String? groupId;
  final ApiFailure? failure;

  List<Announcement> get visible => groupId == null ? items : items.where((a) => a.targets.any((t) => t.group?.id == groupId)).toList();

  AnnouncementsState copyWith({LoadStatus? status, List<Announcement>? items, String? Function()? groupId, ApiFailure? Function()? failure}) =>
      AnnouncementsState(
        status: status ?? this.status,
        items: items ?? this.items,
        groupId: groupId != null ? groupId() : this.groupId,
        failure: failure != null ? failure() : this.failure,
      );

  @override
  List<Object?> get props => [status, items, groupId, failure?.code];
}

/// The teacher's announcements (Release 4, design `r4/Annonces.png`): the latest first, how many read each one.
class AnnouncementsCubit extends Cubit<AnnouncementsState> {
  AnnouncementsCubit(this._repository) : super(const AnnouncementsState());

  final AnnouncementRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    try {
      final items = await _repository.list();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.ready, items: items));
    } on Object catch (error) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, failure: () => ApiFailure.from(error)));
    }
  }

  void showGroup(String? groupId) => emit(state.copyWith(groupId: () => groupId));

  /// A new one, on top.
  void sent(Announcement announcement) => emit(state.copyWith(items: [announcement, ...state.items.where((a) => a.id != announcement.id)]));

  Future<List<UnreadPerson>> unread(Announcement announcement) => _repository.unread(announcement.id);

  /// Null when deleted.
  Future<ApiFailure?> delete(Announcement announcement) async {
    try {
      await _repository.delete(announcement.id);
      if (!isClosed) emit(state.copyWith(items: state.items.where((a) => a.id != announcement.id).toList()));
      return null;
    } on Object catch (error) {
      return ApiFailure.from(error);
    }
  }
}
