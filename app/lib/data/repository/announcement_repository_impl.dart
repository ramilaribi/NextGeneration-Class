import '../../domain/model/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../dto/school_dto.dart';
import '../remote/announcement_api.dart';
import 'api_guard.dart';

Audience audienceOf(Object? value) => switch (value) {
  'PUPILS' => Audience.pupils,
  'PARENTS' => Audience.parents,
  _ => Audience.both,
};

String audienceParam(Audience audience) => switch (audience) {
  Audience.pupils => 'PUPILS',
  Audience.parents => 'PARENTS',
  Audience.both => 'BOTH',
};

Announcement announcementOf(Json json) => Announcement(
  id: json['id'] as String,
  title: json['title'] as String? ?? '',
  body: json['body'] as String? ?? '',
  audience: audienceOf(json['audience']),
  targets: [
    for (final t in jsonList(json['targets']))
      AnnouncementTarget(
        group: t['group'] == null ? null : groupRef(t['group'] as Json),
        studentId: t['studentId'] as String?,
        label: t['label'] as String? ?? '',
      ),
  ],
  createdAt: instant(json['createdAt'])!,
  recipients: (json['recipients'] as num? ?? 0).toInt(),
  read: (json['read'] as num? ?? 0).toInt(),
);

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  AnnouncementRepositoryImpl(this._api);

  final AnnouncementApi _api;

  @override
  Future<List<Announcement>> list() => guard(() async => [for (final a in await _api.list()) announcementOf(a as Json)]);

  @override
  Future<Announcement> send(AnnouncementDraft draft) => guard(
    () async => announcementOf(
      await _api.send({
        'title': draft.title.trim(),
        'body': draft.body.trim(),
        'audience': audienceParam(draft.audience),
        if (draft.studentId != null) 'studentId': draft.studentId else 'groupIds': draft.groupIds,
      }),
    ),
  );

  @override
  Future<List<UnreadPerson>> unread(String id) => guard(
    () async => [
      for (final p in await _api.unread(id))
        UnreadPerson(
          firstName: (p as Json)['firstName'] as String? ?? '',
          lastName: p['lastName'] as String? ?? '',
          parent: p['parent'] as bool? ?? false,
          childFirstName: p['childFirstName'] as String?,
        ),
    ],
  );

  @override
  Future<void> delete(String id) => guard(() => _api.delete(id));
}
