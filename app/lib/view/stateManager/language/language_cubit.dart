import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/language_store.dart';

/// The interface language of this device. Starts from the device language, then the saved choice.
class LanguageCubit extends Cubit<AppLanguage> {
  LanguageCubit(this._store, {AppLanguage? initial}) : super(initial ?? AppLanguage.fromDevice());

  final LanguageStore _store;

  /// A browser that blocks site data cannot read the saved choice: the device language stays.
  Future<void> load() async {
    try {
      final saved = await _store.read();
      if (saved != null) emit(saved);
    } on Object {
      // Nothing saved can be read: keep the device language.
    }
  }

  Future<void> change(AppLanguage language) async {
    if (language == state) return;
    emit(language);
    try {
      await _store.save(language);
    } on Object {
      // Not kept for next time when the browser blocks site data; the app still switches now.
    }
  }
}
