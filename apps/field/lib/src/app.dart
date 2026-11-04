import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/screens/connect_screen.dart';
import 'package:obhijatra_field/src/screens/main_shell.dart';
import 'package:obhijatra_field/src/screens/sign_in_screen.dart';
import 'package:obhijatra_field/src/screens/splash_screen.dart';
import 'package:obhijatra_field/src/screens/startup_problem_screen.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Root widget of the Obhijatra field app.
class ObhijatraFieldApp extends ConsumerWidget {
  /// Creates the app. [home] is only for tests that show one screen.
  const ObhijatraFieldApp({this.home = const AppGate(), super.key});

  /// The first screen.
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      home: home,
    );
  }
}

/// Decides what to show: the splash while the saved data opens, then the
/// connect screen, the sign-in screen or the app itself.
class AppGate extends ConsumerWidget {
  /// Creates the gate.
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(deviceDatabaseProvider);
    return database.when(
      loading: () => const SplashScreen(),
      error: (error, _) => StartupProblemScreen(
        code: problemOf(error),
        onRetry: () => ref.invalidate(deviceDatabaseProvider),
      ),
      data: (_) {
        final connection = ref.watch(serverProvider);
        return connection.when(
          loading: () => const SplashScreen(),
          error: (error, _) => StartupProblemScreen(
            code: problemOf(error),
            onRetry: () => ref.invalidate(serverProvider),
          ),
          data: (server) {
            if (server == null) return const ConnectScreen();
            return ref.watch(sessionProvider) == null
                ? const SignInScreen()
                : const MainShell();
          },
        );
      },
    );
  }
}
