import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/home_screen.dart';
import 'package:obhijatra_manager/src/locale_provider.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Root widget of the Obhijatra manager app.
class ObhijatraManagerApp extends ConsumerWidget {
  const ObhijatraManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ObhijatraTheme.light(locale: locale),
      darkTheme: ObhijatraTheme.dark(locale: locale),
      home: const HomeScreen(),
    );
  }
}
