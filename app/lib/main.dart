import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/l10n/formatting.dart';
import 'view/stateManager/auth/auth_cubit.dart';
import 'view/stateManager/language/language_cubit.dart';
import 'view/widgets/feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _catchErrors();
  // The brand fonts ship with the app (assets/google_fonts, SIL Open Font License): nothing is fetched from Google.
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeAppDates();
  configureDependencies(AppConfig.fromEnvironment());
  final language = sl.get<LanguageCubit>();
  await language.load();
  final auth = sl.get<AuthCubit>();
  startSession(auth, language);
  unawaited(auth.restore());
  runApp(NgClassApp(authCubit: auth, languageCubit: language));
}

/// No error leaves a blank or grey screen behind: a part that fails to build shows a short message (release
/// builds; debug keeps Flutter's red screen), and every error is written to the browser console.
void _catchErrors() {
  if (kReleaseMode) ErrorWidget.builder = (_) => const BrokenPart();
  FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details, forceReport: true);
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };
}
