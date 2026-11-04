import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/providers/app_lock_provider.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';

/// The language shown. Bangla is the default; the choice is remembered on
/// this phone: in the database, and in the protected store so the lock
/// screens (shown before the database opens) use it too.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Before the database opens (lock screens): the copy in the protected
    // store.
    unawaited(
      _read(() => ref.read(secureValuesProvider).read(languageSecureKey)),
    );
    // Once the database is open, restore the language chosen earlier.
    ref.listen(settingsRepositoryProvider, (previous, next) {
      final settings = next.value;
      if (settings == null) return;
      unawaited(
        _read(() async {
          final saved = await settings.read(languageSettingKey);
          if (saved != null) await _mirror(saved);
          return saved;
        }),
      );
    }, fireImmediately: true);
    return const Locale('bn');
  }

  Future<void> _read(Future<String?> Function() load) async {
    try {
      final saved = await load();
      if (saved == 'en' || saved == 'bn') state = Locale(saved!);
    } on Object {
      // Keep the current language.
    }
  }

  Future<void> _mirror(String code) async {
    try {
      final store = ref.read(secureValuesProvider);
      if (await store.read(languageSecureKey) != code) {
        await store.write(languageSecureKey, code);
      }
    } on Object {
      // Only the lock screens' language depends on it.
    }
  }

  /// Shows the app in [locale] and remembers it.
  Future<void> select(Locale locale) async {
    state = locale;
    await _mirror(locale.languageCode);
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.write(languageSettingKey, locale.languageCode);
  }
}

/// Holds the current [Locale].
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
