import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/home_screen.dart';
import 'package:obhijatra_field/src/locale_provider.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Root widget of the Obhijatra field app.
class ObhijatraFieldApp extends ConsumerWidget {
  const ObhijatraFieldApp({super.key});

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
