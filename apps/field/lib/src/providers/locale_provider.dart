import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';

/// The language shown. Bangla is the default; the choice is remembered on
/// this phone.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Once the database is open, restore the language chosen earlier.
    ref.listen(settingsRepositoryProvider, (previous, next) {
      final settings = next.value;
      if (settings == null) return;
      unawaited(
        settings.read(languageSettingKey).then((saved) {
          if (saved == 'en' || saved == 'bn') state = Locale(saved!);
        }),
      );
    }, fireImmediately: true);
    return const Locale('bn');
  }

  /// Shows the app in [locale] and remembers it.
  Future<void> select(Locale locale) async {
    state = locale;
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.write(languageSettingKey, locale.languageCode);
  }
}

/// Holds the current [Locale].
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
