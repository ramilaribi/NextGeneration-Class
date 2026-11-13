import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngclass/core/di/injection.dart';
import 'package:ngclass/core/l10n/app_language.dart';
import 'package:ngclass/core/l10n/formatting.dart';
import 'package:ngclass/core/network/api_failure.dart';
import 'package:ngclass/domain/model/announcement.dart';
import 'package:ngclass/domain/model/app_notification.dart';
import 'package:ngclass/domain/model/session.dart';
import 'package:ngclass/domain/repositories/announcement_repository.dart';
import 'package:ngclass/domain/repositories/student_repository.dart';
import 'package:ngclass/view/screens/teacher/announcements/announcements_screen.dart';
import 'package:ngclass/view/screens/teacher/announcements/new_announcement_panel.dart';
import 'package:ngclass/view/stateManager/announcements/announcement_form_cubit.dart';
import 'package:ngclass/view/stateManager/announcements/announcements_cubit.dart';
import 'package:ngclass/view/stateManager/common/load_status.dart';
import 'package:ngclass/view/stateManager/notifications/notifications_cubit.dart';
import 'package:ngclass/view/stateManager/students/students_cubit.dart';
import 'package:ngclass/view/widgets/announcement_widgets.dart';
import 'package:ngclass/view/widgets/panels.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/student_fixtures.dart';

const ref4A = GroupRef(id: 'g4a', name: '4ème année · Maths', code: '4A', color: '#2B3990', subject: math, privateLesson: false);

/// Release 4: announcements (designs `r4/Annonces.png`, `r4/NouvelleAnnonce.png`, `r4/AnnoncesPhone.png`).
void main() {
  setUpAll(initializeAppDates);

  late FakeAnnouncementRepository repository;

  setUp(() {
    registerTestServices(now);
    repository = FakeAnnouncementRepository();
    sl.registerSingleton<AnnouncementRepository>(repository);
    sl.registerSingleton<StudentRepository>(FakeStudentRepository()..students = [student('s1', 'Lina', 'Bouzid')]);
    sl.registerFactory<StudentsCubit>(() => StudentsCubit(sl.get()));
  });

  group('cubits', () {
    test('the list, a group tab, and deleting only while nobody read it', () async {
      final cubit = AnnouncementsCubit(repository);
      await cubit.load();
      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.items.map((a) => a.id), ['a1', 'a2']);
      cubit.showGroup('other');
      expect(cubit.state.visible, isEmpty);
      cubit.showGroup('g4a');
      expect(cubit.state.visible.map((a) => a.id), ['a1', 'a2']);
      expect(cubit.state.items.first.deletable, isFalse);
      expect(await cubit.delete(cubit.state.items.last), isNull);
      expect(cubit.state.items.map((a) => a.id), ['a1']);
    });

    test('the form needs who, a title and a message; then it is sent', () async {
      final form = AnnouncementFormCubit(repository);
      expect(await form.send(), isNull);
      expect(form.state.errors, {AnnouncementFormError.recipients, AnnouncementFormError.title, AnnouncementFormError.body});
      form
        ..toggleGroup('g4a')
        ..setAudience(Audience.both)
        ..setTitle(' Sortie au musée ')
        ..setBody('Jeudi, départ à 9 h.');
      final sent = await form.send();
      expect(sent, isNotNull);
      expect(repository.sent.single.groupIds, ['g4a']);
      expect(repository.sent.single.audience, Audience.both);
      form.setOnePupil(true);
      expect(await form.send(), isNull);
      expect(form.state.errors, {AnnouncementFormError.recipients});
    });

    test('the families see the announcements of the last 7 days, for the child shown', () {
      final items = [
        announcementNotice('n1', now.subtract(const Duration(days: 1)), studentId: 'me'),
        announcementNotice('n2', now.subtract(const Duration(days: 2)), studentId: 'other'),
        announcementNotice('n3', now.subtract(const Duration(days: 9)), studentId: 'me'),
      ];
      expect(recentAnnouncements(items, now, studentId: 'me').map((n) => n.id), ['n1']);
      expect(recentAnnouncements(items, now).map((n) => n.id), ['n1', 'n2']);
    });
  });

  group('screens', () {
    testWidgets('Annonces: each one with its audience, its groups and how many read it', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, const Scaffold(body: AnnouncementsScreen()));
      expect(find.text(fr.navAnnouncements), findsOneWidget);
      expect(find.text('Sortie au musée jeudi'), findsOneWidget);
      expect(find.text(fr.audienceParents), findsOneWidget);
      expect(find.text(fr.readCount(9, 14)), findsOneWidget);
      // Read by someone: no "Supprimer".
      await tester.tap(find.byKey(const Key('announcement-menu-a1')));
      await tester.pumpAndSettle();
      expect(find.text(fr.notReadYet), findsOneWidget);
      expect(find.text(fr.delete), findsNothing);
      await tester.tap(find.text(fr.notReadYet));
      await tester.pumpAndSettle();
      expect(find.text('Samia Bouzid'), findsOneWidget);
      expect(find.text(fr.parentOf('Lina')), findsOneWidget);
    });

    testWidgets('"Nouvelle annonce": groups or one pupil, the audience, a hint in every field, sent', (tester) async {
      final fr = l10nOf(AppLanguage.fr);
      await pumpSignedIn(tester, const Scaffold(body: AnnouncementsScreen()));
      await tester.tap(find.byKey(const Key('new-announcement')));
      await tester.pumpAndSettle();
      expect(find.byType(NewAnnouncementPanel), findsOneWidget);
      expectEveryFieldHasAHint(find.byType(SidePanel));
      await tester.tap(find.byKey(const Key('send-announcement')));
      await tester.pumpAndSettle();
      expect(find.text(fr.chooseRecipients), findsOneWidget);
      await tester.tap(find.byKey(Key('announcement-group-${group4A.id}')));
      await tester.enterText(find.byKey(const Key('announcement-title')), 'Pas de séance lundi');
      await tester.enterText(find.byKey(const Key('announcement-body')), 'Lundi est férié.');
      await tester.pumpAndSettle();
      expect(find.text('Pas de séance lundi'), findsWidgets);
      await tester.tap(find.byKey(const Key('send-announcement')));
      await tester.pumpAndSettle();
      expect(repository.sent.single.title, 'Pas de séance lundi');
      expect(find.byType(NewAnnouncementPanel), findsNothing);
      expect(find.text(fr.announcementSent(3)), findsOneWidget);
    });

    testWidgets('a family opens an announcement whole, and it is read', (tester) async {
      final notifications = FakeNotificationRepository(items: [announcementNotice('n1', now.subtract(const Duration(hours: 2)), studentId: 'me')]);
      final cubit = NotificationsCubit(notifications);
      await cubit.load();
      await pumpSignedIn(
        tester,
        Scaffold(
          body: FamilyAnnouncements(items: cubit.state.items, now: now),
        ),
        user: parent,
        notifications: cubit,
      );
      expect(find.text('Sortie au musée jeudi'), findsOneWidget);
      await tester.tap(find.byKey(const Key('family-announcement-n1')));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.textContaining('casquette'), findsWidgets);
      expect(notifications.readIds, ['n1']);
    });
  });
}

AppNotification announcementNotice(String id, DateTime at, {String? studentId}) => AppNotification(
  id: id,
  kind: NotificationKind.announcement,
  groupName: '4ème année · Maths',
  startsAt: at,
  createdAt: at,
  studentId: studentId,
  title: 'Sortie au musée jeudi',
  body: 'Jeudi 15 octobre, sortie au musée. Pensez au goûter et à une casquette.',
  author: 'Ines Haddad',
  announcementId: 'a1',
);

class FakeAnnouncementRepository implements AnnouncementRepository {
  final List<Announcement> items = [
    Announcement(
      id: 'a1',
      title: 'Sortie au musée jeudi',
      body: 'Jeudi 15 octobre, sortie au musée du Bardo.',
      audience: Audience.parents,
      targets: const [AnnouncementTarget(group: ref4A, label: '4ème année · Maths')],
      createdAt: now.subtract(const Duration(hours: 1)),
      recipients: 14,
      read: 9,
    ),
    Announcement(
      id: 'a2',
      title: 'Bravo pour le quiz !',
      body: 'Toute la classe a bien travaillé.',
      audience: Audience.pupils,
      targets: const [AnnouncementTarget(group: ref4A, label: '4ème année · Maths')],
      createdAt: now.subtract(const Duration(days: 3)),
      recipients: 6,
    ),
  ];
  final List<AnnouncementDraft> sent = [];
  final List<String> deleted = [];

  @override
  Future<List<Announcement>> list() async => items;

  @override
  Future<Announcement> send(AnnouncementDraft draft) async {
    sent.add(draft);
    return Announcement(id: 'new', title: draft.title.trim(), body: draft.body, audience: draft.audience, createdAt: now, recipients: 3);
  }

  @override
  Future<List<UnreadPerson>> unread(String id) async => const [
    UnreadPerson(firstName: 'Samia', lastName: 'Bouzid', parent: true, childFirstName: 'Lina'),
  ];

  @override
  Future<void> delete(String id) async {
    if (items.firstWhere((a) => a.id == id).read > 0) throw const ApiFailure(code: 'announcement_already_read');
    deleted.add(id);
  }
}
