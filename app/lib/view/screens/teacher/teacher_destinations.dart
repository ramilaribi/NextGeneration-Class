import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/router/routes.dart';
import '../../widgets/app_destination.dart';
import 'contents/contents_screen.dart';
import 'homework/homework_screen.dart';
import 'planning/planning_screen.dart';
import 'settings/settings_screen.dart';
import 'students/students_screen.dart';
import 'teacher_home_screen.dart';

/// Teacher navigation (docs/03-conception/05-SCREENS_NAVIGATION.md). On phones, Devoirs and Paramètres
/// sit in the "Plus" sheet (design `r2/ContenusPhone.png`). A homework opens inside the shell
/// (`Routes.teacherHomework`, core/router/app_router.dart). Annonces (release 4) comes back here once its
/// design is approved; until then the menu shows nothing unfinished (user decision 2026-11-13).
List<AppDestination> teacherDestinations() => [
  AppDestination(
    path: Routes.teacherHome,
    icon: LucideIcons.calendarCheck,
    label: (l10n) => l10n.navTeacherHome,
    screen: () => const TeacherHomeScreen(),
  ),
  AppDestination(
    path: Routes.teacherPlanning,
    icon: LucideIcons.calendar,
    label: (l10n) => l10n.navPlanning,
    screen: () => const PlanningScreen(),
  ),
  AppDestination(
    path: Routes.teacherStudents,
    icon: LucideIcons.users,
    label: (l10n) => l10n.navStudents,
    screen: () => const StudentsScreen(),
  ),
  AppDestination(
    path: Routes.teacherContents,
    icon: LucideIcons.folder,
    label: (l10n) => l10n.navContents,
    screen: () => const ContentsScreen(),
  ),
  AppDestination(
    path: Routes.teacherAssignments,
    icon: LucideIcons.clipboard,
    label: (l10n) => l10n.navAssignments,
    inPhoneBar: false,
    screen: () => const HomeworkScreen(),
  ),
  AppDestination(
    path: Routes.teacherSettings,
    icon: LucideIcons.slidersHorizontal,
    label: (l10n) => l10n.navSettings,
    inPhoneBar: false,
    screen: () => const SettingsScreen(),
  ),
];
