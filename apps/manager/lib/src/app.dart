import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/choose_password_screen.dart';
import 'package:obhijatra_manager/src/ui/shell.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The root of the manager app: state, then the app itself.
class ManagerRoot extends StatelessWidget {
  /// Creates the root. [overrides] are for tests and for `main`.
  const ManagerRoot({this.overrides = const <Override>[], super.key});

  /// Provider overrides.
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) => ProviderScope(
    retry: noAutomaticRetry,
    overrides: overrides,
    child: const ObhijatraManagerApp(),
  );
}

/// Root widget of the Obhijatra manager app.
class ObhijatraManagerApp extends ConsumerWidget {
  /// Creates the app.
  const ObhijatraManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final stage = ref.watch(
      sessionProvider.select(
        (user) => switch (user) {
          null => _Stage.signedOut,
          StaffUser(mustChangePassword: true) => _Stage.choosePassword,
          _ => _Stage.signedIn,
        },
      ),
    );
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en'), Locale('bn')],
      theme: ObhijatraTheme.light(locale: locale),
      home: switch (stage) {
        _Stage.signedOut => const SignInScreen(),
        _Stage.choosePassword => const ChoosePasswordScreen(),
        _Stage.signedIn => const ManagerShell(),
      },
    );
  }
}

/// Where the person is: signed out, replacing a one-time password, or in.
enum _Stage { signedOut, choosePassword, signedIn }
