import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The language shown. Bangla is the default; the user can switch to English.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('bn');

  /// Shows the app in [locale].
  void select(Locale locale) => state = locale;

  /// Switches between Bangla and English.
  void toggle() =>
      state = state.languageCode == 'bn' ? const Locale('en') : const Locale('bn');
}

/// Holds the current [Locale].
final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
