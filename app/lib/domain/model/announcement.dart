import 'package:equatable/equatable.dart';

import 'session.dart';

/// Who reads an announcement (spec 08): the pupils, their parents, or both.
enum Audience { pupils, parents, both }

/// A group as chosen ([group] null once it is deleted), or one pupil ([studentId]); [label] its name of the day.
class AnnouncementTarget extends Equatable {
  const AnnouncementTarget({this.group, this.studentId, required this.label});

  final GroupRef? group;
  final String? studentId;
  final String label;

  @override
  List<Object?> get props => [group, studentId, label];
}

/// A one-way message from the teacher (Release 4, design `r4/Annonces.png`). [recipients]: the people it reached;
/// [read]: how many opened it.
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    this.targets = const [],
    required this.createdAt,
    this.recipients = 0,
    this.read = 0,
  });

  final String id;
  final String title;
  final String body;
  final Audience audience;
  final List<AnnouncementTarget> targets;
  final DateTime createdAt;
  final int recipients;
  final int read;

  /// Deleting is possible while nobody read it.
  bool get deletable => read == 0;

  @override
  List<Object?> get props => [id, title, body, audience, targets, createdAt, recipients, read];
}

/// What the teacher sends: [groupIds], or one [studentId].
class AnnouncementDraft extends Equatable {
  const AnnouncementDraft({required this.title, required this.body, required this.audience, this.groupIds = const [], this.studentId});

  final String title;
  final String body;
  final Audience audience;
  final List<String> groupIds;
  final String? studentId;

  @override
  List<Object?> get props => [title, body, audience, groupIds, studentId];
}

/// Someone who has not read it yet: a pupil, or a parent of [childFirstName].
class UnreadPerson extends Equatable {
  const UnreadPerson({required this.firstName, required this.lastName, this.parent = false, this.childFirstName});

  final String firstName;
  final String lastName;
  final bool parent;
  final String? childFirstName;

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [firstName, lastName, parent, childFirstName];
}
