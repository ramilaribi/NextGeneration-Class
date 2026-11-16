import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngclass/core/di/injection.dart';
import 'package:ngclass/core/l10n/app_language.dart';
import 'package:ngclass/core/l10n/formatting.dart';
import 'package:ngclass/domain/model/results.dart';
import 'package:ngclass/domain/model/student.dart';
import 'package:ngclass/domain/repositories/group_repository.dart';
import 'package:ngclass/domain/repositories/privacy_repository.dart';
import 'package:ngclass/domain/repositories/results_repository.dart';
import 'package:ngclass/domain/repositories/student_repository.dart';
import 'package:ngclass/view/screens/shared/privacy_screens.dart';
import 'package:ngclass/view/screens/teacher/students/student_profile_screen.dart';
import 'package:ngclass/view/stateManager/auth/auth_cubit.dart';
import 'package:ngclass/view/stateManager/auth/auth_state.dart';
import 'package:ngclass/view/stateManager/students/students_cubit.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/fakes.dart';
import '../helpers/homework_fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/student_fixtures.dart';

/// Before going live: the privacy notice and the parents' agreement (designs `r4/AccordParents.png`,
/// `r4/Confidentialite.png`, `r4/ConfidentialitePhone.png`).
void main() {
  setUpAll(initializeAppDates);

  late FakeStudentRepository students;

  setUp(() {
    registerTestServices(now);
    students = FakeStudentRepository()
      ..students = [
        student('s1', 'Adam', 'Gharbi'),
        student('s2', 'Lina', 'Bouzid'),
      ];
    sl.registerSingleton<StudentRepository>(students);
    sl.registerSingleton<GroupRepository>(FakeGroupRepository());
    sl.registerSingleton<ResultsRepository>(FakeResultsRepository(results: const MyResults()));
    registerContentServices();
  });

  FakePrivacyRepository privacy() => sl.get<PrivacyRepository>() as FakePrivacyRepository;

  testWidgets('a parent reads the essentials, ticks the box, and only then continues', (tester) async {
    final fr = l10nOf(AppLanguage.fr);
    await pumpSignedIn(tester, const PrivacyAgreementScreen(), user: parent);
    await tester.pumpAndSettle();
    expect(find.text(fr.privacyAgreementTitle(['Adam', 'Lina'].map(keptTogether).join(fr.andSeparator))), findsOneWidget);
    for (final title in [fr.privacyKeptTitle, fr.privacySeenTitle, fr.privacyHowLongTitle, fr.privacyRightsTitle]) {
      expect(find.text(title), findsOneWidget);
    }
    // "Continuer" does nothing until the box is ticked.
    await tester.ensureVisible(find.byKey(const Key('privacy-continue')));
    await tester.tap(find.byKey(const Key('privacy-continue')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(privacy().accepted, 0);
    await tester.ensureVisible(find.byKey(const Key('privacy-accept')));
    await tester.tap(find.byKey(const Key('privacy-accept')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('privacy-continue')));
    await tester.tap(find.byKey(const Key('privacy-continue')));
    await tester.pumpAndSettle();
    expect(privacy().accepted, 1);
    final auth = tester.element(find.byType(PrivacyAgreementView)).read<AuthCubit>().state as AuthSignedIn;
    expect(auth.user.privacyRequired, isFalse);
  });

  testWidgets('the full notice: seven points in plain words, in Arabic too', (tester) async {
    final ar = l10nOf(AppLanguage.ar);
    await pumpSignedIn(tester, const PrivacyScreen(), language: AppLanguage.ar);
    await tester.pumpAndSettle();
    expect(find.text(ar.privacyPageTitle), findsOneWidget);
    for (final title in [
      ar.privacyWhoTitle,
      ar.privacyKeptTitle,
      ar.privacyWhyTitle,
      ar.privacySeenTitle,
      ar.privacyWhereTitle,
      ar.privacyHowLongTitle,
      ar.privacyRightsTitle,
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('the teacher records an agreement signed on paper in the Fiche élève', (tester) async {
    final fr = l10nOf(AppLanguage.fr);
    await pumpSignedIn(tester, const Scaffold(body: StudentProfileScreen(studentId: 's2')), size: const Size(1440, 1400));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('consent-card'));
    expect(find.descendant(of: card, matching: find.text(fr.consentPending)), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('consent-paper')));
    await tester.tap(find.byKey(const Key('consent-paper')));
    await tester.pumpAndSettle();
    expect(privacy().papers, ['s2']);
    expect(find.descendant(of: card, matching: find.text(fr.consentGiven)), findsOneWidget);
    expect(find.text(fr.consentPaperSaved), findsOneWidget);
  });

  test('"Accord en attente" keeps only the families who have not agreed', () async {
    students.students = [
      student('s1', 'Adam', 'Gharbi').withConsent(StudentConsent(paper: false, givenBy: 'Mouna Gharbi', givenAt: now)),
      student('s2', 'Lina', 'Bouzid'),
    ];
    final cubit = StudentsCubit(students);
    await cubit.load();
    expect(cubit.state.visible.length, 2);
    cubit.filterConsentPending(true);
    expect(cubit.state.visible.map((s) => s.id), ['s2']);
  });
}
