// The app lock in the whole app: the device database opens only after the
// phone's screen lock or the app PIN, never after 30 days without an online
// sign-in, and closes again after five minutes in the background.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/platform/device_authenticator.dart';
import 'package:obhijatra_field/src/screens/about_screen.dart';
import 'package:obhijatra_field/src/screens/lock_screens.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'finish_flow_test.dart' show settleLong;
import 'support/harness.dart';

Finder _button(String label) => find.widgetWithText(PrimaryButton, label);

/// The field user every fake server starts with.
const String _userId = 'fielduser1abcde';

/// The phone was used before: the server address and (with [session]) a
/// session in the database, an online sign-in [signedInAgo], and the app PIN
/// [pin] if given.
Future<void> _usedBefore(
  WidgetTester tester,
  TestEnv env, {
  Duration signedInAgo = const Duration(days: 1),
  String? pin,
  bool session = true,
}) async {
  await tester.runAsync(() async {
    await env.seedDevice((db) => env.seedSignedIn(signedIn: session, into: db));
    final lock = env.lockStore(at: env.now.subtract(signedInAgo));
    await lock.recordOnlineSignIn(_userId);
    await lock.rememberServerAddress(FakeObhijatraServer.baseUrl);
    if (pin != null) await lock.setPin(pin);
  });
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(await reveal(tester, find.byKey(Key(key))), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(await reveal(tester, finder));
  await settleLong(tester);
}

Future<void> _signIn(
  WidgetTester tester,
  AppLocalizations l,
  String email,
) async {
  await _type(tester, 'email-field', email);
  await _type(tester, 'password-field', fakePassword);
  await _tap(tester, _button(l.signInTitle));
}

void main() {
  group('first use', () {
    testWidgets('connect and sign in; nothing to unlock yet', (tester) async {
      final env = TestEnv();
      env.secureValues.values[AppLock.pinEntry] =
          'left from an earlier install';
      final l = wordsFor('bn');
      await pumpApp(tester, env, locked: true);

      expect(find.text(l.connectTitle), findsWidgets);
      // Old entries from an earlier install (an iOS Keychain outlives the
      // app) are gone.
      expect(env.secureValues.values.keys, isNot(contains(AppLock.pinEntry)));
      await _type(tester, 'server-address-field', 'data.example.org');
      await _tap(tester, _button(l.connectTest));
      await _tap(tester, _button(l.actionContinue));
      expect(find.text(l.signInTitle), findsWidgets);
      await _signIn(tester, l, fakeEmail);

      expect(find.text(l.todayTitle), findsWidgets);
      final lock = env.lockStore();
      final last = await tester.runAsync(lock.lastOnlineSignIn);
      expect(last!.userId, _userId);
      expect(last.at, env.now.toUtc());
      expect(
        await tester.runAsync(lock.serverAddress),
        Uri.parse('https://data.example.org'),
      );
      expect(await tester.runAsync(lock.hasPin), isFalse);
      await endTest(tester, env);
    });

    testWidgets('a phone without a screen lock must choose an app PIN', (
      tester,
    ) async {
      final env = TestEnv();
      env.deviceAuth.screenLock = false;
      final l = wordsFor('en');
      await tester.runAsync(
        () =>
            env.seedDevice((db) => env.seedSignedIn(signedIn: false, into: db)),
      );
      // The database exists but nobody has signed in on this phone yet.
      await pumpApp(tester, env, language: 'en', locked: true);
      expect(find.text(l.signInTitle), findsWidgets);
      await _signIn(tester, l, fakeEmail);

      expect(find.byType(SetPinScreen), findsOneWidget);
      expect(find.text(l.todayTitle), findsNothing);
      await _type(tester, 'new-pin-field', '4815');
      await _tap(tester, _button(l.pinSave));
      expect(find.text(l.pinNeedsSixDigits), findsOneWidget);
      await _type(tester, 'new-pin-field', '481592');
      await _type(tester, 'confirm-pin-field', '481593');
      await _tap(tester, _button(l.pinSave));
      expect(find.text(l.pinMismatch), findsOneWidget);
      await _type(tester, 'confirm-pin-field', '481592');
      await _tap(tester, _button(l.pinSave));

      expect(find.text(l.todayTitle), findsWidgets);
      final stored = env.secureValues.values[AppLock.pinEntry]!;
      expect(stored, startsWith(r'pbkdf2-sha256$'));
      expect(stored, isNot(contains('481592')));
      final check = await tester.runAsync(
        () => env.lockStore().checkPin('481592'),
      );
      expect(check, isA<PinAccepted>());
      await endTest(tester, env);
    });
  });

  group('a phone with a screen lock', () {
    matrix('opens the data only after the phone unlocks', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      await _usedBefore(tester, env);
      env.deviceAuth.answers.add(DeviceUnlockResult.cancelled);
      await pumpApp(
        tester,
        env,
        language: language,
        textScale: scale,
        locked: true,
      );

      // The prompt came up by itself and was closed: still locked, and the
      // database was never opened.
      expect(env.deviceAuth.prompts, 1);
      expect(env.deviceAuth.lastText!.reason, l.lockDeviceReason);
      expect(find.byType(DeviceUnlockScreen), findsOneWidget);
      expect(find.text(l.lockTitle), findsOneWidget);
      expect(await reveal(tester, find.text(l.lockDeviceCancelled)), findsOne);
      expect(env.opener.opens, 0);
      await expectAccessibleTargets(tester);

      await _tap(tester, _button(l.lockUnlock));
      expect(env.deviceAuth.prompts, 2);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 1);
      await endTest(tester, env);
    });

    testWidgets('a removed screen lock falls back to an online sign-in', (
      tester,
    ) async {
      final env = TestEnv();
      await _usedBefore(tester, env);
      env.deviceAuth.screenLock = false;
      final l = wordsFor('bn');
      await pumpApp(tester, env, locked: true);

      expect(find.text(l.reSignInNoLock), findsOneWidget);
      expect(env.opener.opens, 0);
      await _signIn(tester, l, fakeEmail);
      expect(find.byType(SetPinScreen), findsOneWidget);
      await _type(tester, 'new-pin-field', '২৭১৮২৮');
      await _type(tester, 'confirm-pin-field', '271828');
      await _tap(tester, _button(l.pinSave));
      expect(find.text(l.todayTitle), findsWidgets);
      await endTest(tester, env);
    });

    testWidgets('locks again after five minutes in the background', (
      tester,
    ) async {
      final env = TestEnv();
      await _usedBefore(tester, env);
      final l = wordsFor('bn');
      await pumpApp(tester, env, locked: true);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 1);

      Future<void> away(Duration time) async {
        for (final state in <AppLifecycleState>[
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        env.now = env.now.add(time);
        for (final state in <AppLifecycleState>[
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await settleLong(tester);
      }

      // A short break: still open.
      await away(const Duration(minutes: 4, seconds: 59));
      expect(find.text(l.todayTitle), findsWidgets);
      expect(find.byType(DeviceUnlockScreen), findsNothing);

      // Five minutes: locked, the app's screens gone, the database closed.
      env.deviceAuth.answers.add(DeviceUnlockResult.cancelled);
      await away(const Duration(minutes: 5));
      expect(find.byType(DeviceUnlockScreen), findsOneWidget);
      expect(find.text(l.todayTitle), findsNothing);

      await _tap(tester, _button(l.lockUnlock));
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 2, reason: 'opened again after the unlock');
      await endTest(tester, env);
    });
  });

  group('a phone without a screen lock', () {
    matrix('asks for the app PIN; five wrong tries make it wait', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      env.deviceAuth.screenLock = false;
      await _usedBefore(tester, env, pin: '481592');
      await pumpApp(
        tester,
        env,
        language: language,
        textScale: scale,
        locked: true,
      );

      expect(find.byType(PinUnlockScreen), findsOneWidget);
      expect(await reveal(tester, find.text(l.lockPinBody)), findsOneWidget);
      await expectAccessibleTargets(tester);

      await _type(tester, 'pin-field', '123');
      await _tap(tester, _button(l.lockUnlock));
      expect(find.text(l.pinNeedsSixDigits), findsOneWidget);

      for (var left = 4; left >= 1; left--) {
        await _type(tester, 'pin-field', '000000');
        await _tap(tester, _button(l.lockUnlock));
        expect(await reveal(tester, find.text(l.pinWrong(left))), findsOne);
      }
      await _type(tester, 'pin-field', '000000');
      await _tap(tester, _button(l.lockUnlock));
      expect(await reveal(tester, find.text(l.pinWaitSeconds(30))), findsOne);
      final unlock = tester.widget<PrimaryButton>(_button(l.lockUnlock));
      expect(unlock.onPressed, isNull, reason: 'no tries during the wait');
      expect(env.opener.opens, 0);
      await expectAccessibleTargets(tester);

      // After the wait, the right PIN opens the data.
      env.now = env.now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await _type(tester, 'pin-field', '481592');
      await _tap(tester, _button(l.lockUnlock));
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 1);
      await endTest(tester, env);
    });

    testWidgets('a wait survives closing the app', (tester) async {
      final env = TestEnv();
      env.deviceAuth.screenLock = false;
      await _usedBefore(tester, env, pin: '481592');
      final lock = env.lockStore();
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await lock.checkPin('000000');
        }
      });
      final l = wordsFor('en');
      await pumpApp(tester, env, language: 'en', locked: true);
      expect(await reveal(tester, find.text(l.pinWaitSeconds(30))), findsOne);
      await endTest(tester, env);
    });

    testWidgets('forgot the PIN: sign in again, then choose a new one', (
      tester,
    ) async {
      final env = TestEnv();
      env.deviceAuth.screenLock = false;
      await _usedBefore(tester, env, pin: '481592');
      final l = wordsFor('bn');
      await pumpApp(tester, env, locked: true);

      await _tap(tester, _button(l.pinForgot));
      expect(find.text(l.reSignInForgotPin), findsOneWidget);
      await _tap(tester, _button(l.reSignInBack));
      expect(find.byType(PinUnlockScreen), findsOneWidget);
      await _tap(tester, _button(l.pinForgot));

      await _signIn(tester, l, fakeEmail);
      expect(find.byType(SetPinScreen), findsOneWidget);
      expect(env.opener.opens, 0);
      await _type(tester, 'new-pin-field', '271828');
      await _type(tester, 'confirm-pin-field', '271828');
      await _tap(tester, _button(l.pinSave));
      expect(find.text(l.todayTitle), findsWidgets);
      final lock = env.lockStore();
      expect(
        await tester.runAsync(() => lock.checkPin('271828')),
        isA<PinAccepted>(),
      );
      await endTest(tester, env);
    });
  });

  group('after 30 days offline', () {
    matrix('the data stays closed until the same account signs in online', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      env.server.users['field2@example.org'] = const FakeFieldUser(
        id: 'fielduser2abcde',
      );
      // Signed in 31 days ago, and the saved session is gone, so only the
      // new online sign-in can bring one.
      await _usedBefore(
        tester,
        env,
        signedInAgo: const Duration(days: 31),
        session: false,
      );
      await pumpApp(
        tester,
        env,
        language: language,
        textScale: scale,
        locked: true,
      );

      expect(find.byType(OnlineSignInScreen), findsOneWidget);
      expect(await reveal(tester, find.text(l.reSignInExpired)), findsOne);
      expect(env.deviceAuth.prompts, 0);
      expect(env.opener.opens, 0);
      await expectAccessibleTargets(tester);

      // No signal: told plainly; still closed.
      env.server.signInGlitches.add(const NoConnection());
      await _signIn(tester, l, fakeEmail);
      expect(
        await reveal(tester, find.text(l.problem_offline)),
        findsOneWidget,
      );
      // Somebody else's account does not open this phone's data.
      await _signIn(tester, l, 'field2@example.org');
      expect(
        await reveal(tester, find.text(l.reSignInWrongAccount)),
        findsOneWidget,
      );
      expect(env.opener.opens, 0);

      await _signIn(tester, l, fakeEmail);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 1);
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.at, env.now.toUtc());
      await endTest(tester, env);
    });

    testWidgets('a phone clock set back before the sign-in counts as expired', (
      tester,
    ) async {
      final env = TestEnv();
      await _usedBefore(tester, env, signedInAgo: const Duration(hours: -2));
      final l = wordsFor('bn');
      await pumpApp(tester, env, locked: true);
      expect(find.text(l.reSignInExpired), findsOneWidget);
      expect(env.opener.opens, 0);
      await endTest(tester, env);
    });
  });

  matrix('choosing a PIN fits every language and text size', (
    tester,
    language,
    scale,
    l,
  ) async {
    final env = TestEnv();
    await pumpScreen(
      tester,
      env,
      const SetPinScreen(),
      language: language,
      textScale: scale,
    );
    expect(find.text(l.pinSetTitle), findsOneWidget);
    await _type(tester, 'new-pin-field', '481592');
    await _type(tester, 'confirm-pin-field', '000000');
    await _tap(tester, _button(l.pinSave));
    expect(await reveal(tester, find.text(l.pinMismatch)), findsOneWidget);
    await expectAccessibleTargets(tester);
    expect(env.secureValues.values, isNot(contains(AppLock.pinEntry)));
    await endTest(tester, env);
  });

  matrix('the About screen recommends one phone per person', (
    tester,
    language,
    scale,
    l,
  ) async {
    final env = TestEnv();
    await pumpScreen(
      tester,
      env,
      const AboutScreen(),
      language: language,
      textScale: scale,
    );
    expect(
      await reveal(tester, find.text(l.aboutSecurityBody)),
      findsOneWidget,
    );
    expect(find.text(l.aboutSecurityHeading), findsOneWidget);
    await endTest(tester, env);
  });
}
