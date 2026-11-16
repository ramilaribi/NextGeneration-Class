import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ngclass/core/l10n/app_language.dart';
import 'package:ngclass/core/l10n/language_store.dart';
import 'package:ngclass/core/network/token_store.dart';
import 'package:ngclass/l10n/app_localizations.dart';
import 'package:ngclass/view/stateManager/language/language_cubit.dart';
import 'package:ngclass/view/widgets/feedback.dart';

/// Pre-production audit F4: a browser that blocks site data (it throws on every read and write) never leaves
/// a blank page, and a part that fails to build shows a sentence.
class _BlockedSecureStorage extends Mock implements FlutterSecureStorage {}

class _BlockedLanguageStore implements LanguageStore {
  @override
  Future<AppLanguage?> read() => Future.error(StateError('SecurityError: localStorage is blocked'));

  @override
  Future<void> save(AppLanguage language) => Future.error(StateError('SecurityError: localStorage is blocked'));
}

void main() {
  test('the language stays the device one, and still switches', () async {
    final cubit = LanguageCubit(_BlockedLanguageStore(), initial: AppLanguage.fr);
    await cubit.load();
    expect(cubit.state, AppLanguage.fr);
    await cubit.change(AppLanguage.ar);
    expect(cubit.state, AppLanguage.ar);
  });

  test('the session is kept in memory when the browser refuses the storage', () async {
    final storage = _BlockedSecureStorage();
    final blocked = StateError('SecurityError: localStorage is blocked');
    when(() => storage.read(key: any(named: 'key'))).thenThrow(blocked);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value'))).thenThrow(blocked);
    when(() => storage.delete(key: any(named: 'key'))).thenThrow(blocked);
    final tokens = TokenStore(storage);

    expect(await tokens.readRefreshToken(), isNull);
    await tokens.save(accessToken: 'a', refreshToken: 'r', userJson: '{}');
    expect(tokens.accessToken, 'a');
    expect(await tokens.readRefreshToken(), 'r');
    await tokens.clear();
    expect(await tokens.readRefreshToken(), isNull);
  });

  for (final language in AppLanguage.values) {
    testWidgets('a part that fails to build says so, ${language.name}', (tester) async {
      final l10n = lookupAppLocalizations(Locale(language.code));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language.code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: BrokenPart()),
        ),
      );
      expect(find.text(l10n.errorDisplay), findsOneWidget);
    });
  }

  testWidgets('outside the app\'s languages it shows the icon only', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: BrokenPart()));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
