import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/devices.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/choose_password_screen.dart';
import 'package:obhijatra_manager/src/ui/device_screens.dart';
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
    final user = ref.watch(sessionProvider);
    final gate = ref.watch(deviceGateProvider);
    // The device check's answer, if it is about the person signed in now
    // (while it runs again, the last answer stays on screen).
    final device = switch (gate.value) {
      final DeviceGate value when user != null && value.userId == user.id =>
        value,
      _ => null,
    };
    // A failed check, when nothing newer runs. Its problem is shown in place
    // of the last answer when the person must sign in again, or when there
    // is no last answer; otherwise (for example offline) the last answer
    // stays, with the problem beside it.
    final failed = gate.hasError && !gate.isLoading
        ? problemFrom(gate.error!)
        : null;
    final signInAgain = failed?.action == ProblemAction.signInAgain;
    final problem = signInAgain ? failed : device?.problem ?? failed;
    final stage = switch ((user, device)) {
      (null, _) => _Stage.signedOut,
      (_, null) when failed != null => _Stage.deviceProblem,
      _ when signInAgain => _Stage.deviceProblem,
      (_, null) => _Stage.checking,
      // A one-time password is replaced first, from a waiting device too;
      // the device then waits for approval.
      (StaffUser(mustChangePassword: true), DeviceGate(:final stage))
          when stage == DeviceStage.ready ||
              stage == DeviceStage.waiting ||
              stage == DeviceStage.expired =>
        _Stage.choosePassword,
      (_, DeviceGate(:final stage)) => switch (stage) {
        DeviceStage.ready => _Stage.signedIn,
        DeviceStage.waiting || DeviceStage.expired => _Stage.waiting,
        DeviceStage.revoked => _Stage.revoked,
        DeviceStage.notRecognised => _Stage.notRecognised,
        DeviceStage.clockWrong => _Stage.clockWrong,
        DeviceStage.updateBrowser => _Stage.updateBrowser,
        DeviceStage.secureAddressNeeded => _Stage.secureAddress,
        DeviceStage.problem => _Stage.deviceProblem,
      },
    };
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
        _Stage.checking => const DeviceCheckingScreen(),
        _Stage.deviceProblem => DeviceProblemScreen(problem: problem!),
        _Stage.choosePassword => const ChoosePasswordScreen(),
        _Stage.waiting => DeviceWaitingScreen(gate: device!),
        _Stage.revoked => const DeviceRevokedScreen(),
        _Stage.notRecognised => const DeviceNotRecognisedScreen(),
        _Stage.clockWrong => const DeviceClockScreen(),
        _Stage.updateBrowser => const DeviceUnsupportedScreen(
          secureAddress: false,
        ),
        _Stage.secureAddress => const DeviceUnsupportedScreen(
          secureAddress: true,
        ),
        _Stage.signedIn => const ManagerShell(),
      },
    );
  }
}

/// Where the person is: signed out; signed in while this device is
/// checked, waits for approval or cannot be used; replacing a one-time
/// password; or in.
enum _Stage {
  signedOut,
  checking,
  deviceProblem,
  choosePassword,
  waiting,
  revoked,
  notRecognised,
  clockWrong,
  updateBrowser,
  secureAddress,
  signedIn,
}
