import '../model/announcement.dart';

/// The teacher's announcements (Release 4). Families read them in their notifications.
abstract interface class AnnouncementRepository {
  /// The latest first.
  Future<List<Announcement>> list();

  Future<Announcement> send(AnnouncementDraft draft);

  Future<List<UnreadPerson>> unread(String id);

  /// Only while nobody read it.
  Future<void> delete(String id);
}
