// Sign-in by SMS code and by Google, next to email and password: the
// screen shows only what the server offers, every way ends in the same
// online sign-in (so the app lock is set up the same way), and the person
// can always step back or cancel.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/platform/device_authenticator.dart';
import 'package:obhijatra_field/src/providers/app_lock_provider.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/screens/lock_screens.dart';
import 'package:obhijatra_field/src/screens/sign_in_screen.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'support/harness.dart';

Finder _button(String label) => find.widgetWithText(PrimaryButton, label);

final Finder _phoneField = find.byKey(const Key('phone-field'));
final Finder _codeField = find.byKey(const Key('code-field'));
final Finder _emailField = find.byKey(const Key('email-field'));

/// The field user every fake server starts with.
const String _userId = 'fielduser1abcde';

/// Lets requests and the screen move on without waiting for spinners to
/// stop (the Google waiting state spins until the person comes back).
Future<void> _settleBriefly(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The countdown under "Send a new code".
Future<String?> _countdown(WidgetTester tester) async => tester
    .widget<Text>(
      await reveal(tester, find.byKey(const Key('new-code-countdown'))),
    )
    .data;

/// Whether [label]'s button can be pressed.
bool _enabled(WidgetTester tester, String label) {
  final button = tester.widget<PrimaryButton>(_button(label));
  return button.onPressed != null && !button.busy;
}

/// The sign-in screen on its own, with [server] offering what the test
/// sets.
Future<TestEnv> _open(
  WidgetTester tester, {
  required FakeObhijatraServer server,
  String language = 'en',
  double scale = 1.0,
}) async {
  final env = TestEnv(server: server);
  await tester.runAsync(() => env.seedSignedIn(signedIn: false));
  await pumpScreen(
    tester,
    env,
    const SignInScreen(),
    language: language,
    textScale: scale,
  );
  return env;
}

FakeObhijatraServer _offering({bool phone = false, bool google = false}) =>
    FakeObhijatraServer()
      ..offersPhone = phone
      ..offersGoogle = google;

/// Types [code] in the code field, as from the keyboard.
Future<void> _typeCode(WidgetTester tester, String code) async =>
    tester.enterText(await reveal(tester, _codeField), code);

Future<void> _typeNumberAndSend(
  WidgetTester tester,
  AppLocalizations l, [
  String number = '01712-345678',
]) async {
  await tester.enterText(await reveal(tester, _phoneField), number);
  await tester.tap(_button(l.signInSendCode));
  await settleApp(tester);
}

void main() {
  group('the ways shown', () {
    matrix('SMS code first when the server sends codes; the others below', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await _open(
        tester,
        server: _offering(phone: true, google: true),
        language: language,
        scale: scale,
      );
      expect(await reveal(tester, _phoneField), findsOneWidget);
      expect(find.text('+880'), findsOneWidget);
      expect(_emailField, findsNothing);
      expect(_button(l.signInSendCode), findsOneWidget);
      expect(await reveal(tester, find.text(l.signInOtherWays)), findsOne);
      expect(await reveal(tester, _button(l.signInWithGoogle)), findsOne);
      expect(await reveal(tester, _button(l.signInUseEmail)), findsOne);
      expect(_button(l.signInUsePhone), findsNothing);
      await expectAccessibleTargets(tester);

      // Email and password are one tap away, and the way back too.
      await tester.tap(await reveal(tester, _button(l.signInUseEmail)));
      await settleApp(tester);
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(_phoneField, findsNothing);
      expect(_button(l.signInTitle), findsOneWidget);
      expect(await reveal(tester, _button(l.signInUsePhone)), findsOne);
      expect(await reveal(tester, _button(l.signInWithGoogle)), findsOne);
      await expectAccessibleTargets(tester);
      await tester.tap(await reveal(tester, _button(l.signInUsePhone)));
      await settleApp(tester);
      expect(await reveal(tester, _phoneField), findsOneWidget);
      await endTest(tester, env);
    });

    testWidgets('email and password only: no other choices', (tester) async {
      final l = wordsFor('en');
      final env = await _open(tester, server: _offering());
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(find.text(l.signInOtherWays), findsNothing);
      expect(_button(l.signInWithGoogle), findsNothing);
      expect(_button(l.signInUsePhone), findsNothing);
      expect(_phoneField, findsNothing);
      await endTest(tester, env);
    });

    testWidgets('Google without SMS: email and password first', (tester) async {
      final l = wordsFor('bn');
      final env = await _open(
        tester,
        server: _offering(google: true),
        language: 'bn',
      );
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(await reveal(tester, _button(l.signInWithGoogle)), findsOne);
      expect(_button(l.signInUsePhone), findsNothing);
      expect(_button(l.signInUseEmail), findsNothing);
      await endTest(tester, env);
    });

    testWidgets('a server from before these ways offers the password', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = await _open(
        tester,
        server: _offering(phone: true, google: true)
          ..answersSignInMethods = false,
      );
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(find.text(l.signInOtherWays), findsNothing);
      await endTest(tester, env);
    });

    testWidgets('when the ways cannot be checked: the password, the reason '
        'and Try again', (tester) async {
      final l = wordsFor('en');
      final server = _offering(phone: true)
        ..signInMethodsGlitches.add(const NoConnection());
      final env = await _open(tester, server: server);
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(
        await reveal(tester, find.text(l.signInMethodsFailed)),
        findsOneWidget,
      );
      expect(await reveal(tester, find.text(l.problem_offline)), findsOne);
      await tester.tap(await reveal(tester, _button(l.actionTryAgain)));
      await settleApp(tester);
      expect(await reveal(tester, _phoneField), findsOneWidget);
      expect(find.text(l.signInMethodsFailed), findsNothing);
      await endTest(tester, env);
    });
  });

  group('SMS code', () {
    matrix('the code from the SMS signs in, without a button press', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await _open(
        tester,
        server: _offering(phone: true),
        language: language,
        scale: scale,
      );
      await _typeNumberAndSend(tester, l);

      // The code step: where the SMS went, who sends it, one large field.
      final shown = language == 'bn' ? '+৮৮০ ১৭১২-৩৪৫৬৭৮' : '+880 1712-345678';
      expect(await reveal(tester, find.text(l.signInCodeTitle)), findsOne);
      expect(
        await reveal(tester, find.text(l.signInCodeSent(shown))),
        findsOne,
      );
      expect(await reveal(tester, find.text(l.signInCodeFrom)), findsOne);
      expect(env.server.sentSms.single.phone, fakePhone);
      expect(await reveal(tester, _codeField), findsOneWidget);
      expect(find.text(l.signInOtherWays), findsNothing);
      final field = tester.widget<TextField>(_codeField);
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.keyboardType, TextInputType.number);
      await expectAccessibleTargets(tester);

      // Typed in Bangla digits: six digits sign in by themselves.
      const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
      final code = env.server.sentSms.single.code
          .split('')
          .map((d) => bangla[int.parse(d)])
          .join();
      await _typeCode(tester, code);
      await settleApp(tester);
      expect(containerOf(tester).read(sessionProvider)?.id, _userId);
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.userId, _userId);
      await endTest(tester, env);
    });

    testWidgets('the number must be a mobile number before a code is sent', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = await _open(tester, server: _offering(phone: true));
      await tester.tap(_button(l.signInSendCode));
      await settleApp(tester);
      expect(await reveal(tester, find.text(l.signInPhoneEmpty)), findsOne);
      await _typeNumberAndSend(tester, l, '0171234');
      expect(await reveal(tester, find.text(l.signInPhoneInvalid)), findsOne);
      expect(env.server.sentSms, isEmpty);
      expect(
        env.server.log,
        isNot(contains('POST /api/obhijatra/v1/signin/phone/code')),
      );
      await endTest(tester, env);
    });

    testWidgets('a number without an account looks the same', (tester) async {
      final l = wordsFor('en');
      final env = await _open(tester, server: _offering(phone: true));
      await _typeNumberAndSend(tester, l, '01812345678');
      expect(find.text(l.signInCodeSent('+880 1812-345678')), findsOneWidget);
      expect(env.server.sentSms, isEmpty);
      await endTest(tester, env);
    });

    testWidgets('a wrong code says so plainly and can be typed again', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = await _open(tester, server: _offering(phone: true));
      await _typeNumberAndSend(tester, l);
      final right = env.server.sentSms.single.code;
      final wrong = right == '000000' ? '111111' : '000000';
      await _typeCode(tester, wrong);
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.problem_signInCodeWrong)),
        findsOneWidget,
      );
      expect(containerOf(tester).read(sessionProvider), isNull);
      // The field is empty again, ready for the right code.
      final field = await reveal(tester, _codeField);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.enterText(field, right);
      await settleApp(tester);
      expect(containerOf(tester).read(sessionProvider)?.id, _userId);
      await endTest(tester, env);
    });

    testWidgets('fewer than 6 digits are not sent', (tester) async {
      final l = wordsFor('bn');
      final env = await _open(
        tester,
        server: _offering(phone: true),
        language: 'bn',
      );
      await _typeNumberAndSend(tester, l);
      await _typeCode(tester, '১২৩');
      await tester.tap(_button(l.signInTitle));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.signInCodeIncomplete)),
        findsOneWidget,
      );
      expect(
        env.server.log,
        isNot(contains('POST /api/obhijatra/v1/signin/phone/verify')),
      );
      await endTest(tester, env);
    });

    testWidgets('a new code only after the countdown; then use the newest', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = await _open(tester, server: _offering(phone: true));
      await _typeNumberAndSend(tester, l);
      // The server said 60 seconds; settling the screen took about one.
      final full = anyOf(l.signInNewCodeIn(60), l.signInNewCodeIn(59));
      expect(await _countdown(tester), full);
      expect(_enabled(tester, l.signInNewCode), isFalse);

      await tester.pump(const Duration(seconds: 57));
      expect(
        await _countdown(tester),
        anyOf(l.signInNewCodeIn(3), l.signInNewCodeIn(2)),
      );
      expect(_enabled(tester, l.signInNewCode), isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('new-code-countdown')), findsNothing);
      expect(_enabled(tester, l.signInNewCode), isTrue);
      expect(l.signInNewCodeIn(1), 'You can ask for a new code in 1 second.');

      final first = env.server.sentSms.single.code;
      await tester.tap(await reveal(tester, _button(l.signInNewCode)));
      await settleApp(tester);
      expect(env.server.sentSms, hasLength(2));
      expect(await reveal(tester, find.text(l.signInCodeNew)), findsOne);
      expect(await _countdown(tester), full);
      expect(_enabled(tester, l.signInNewCode), isFalse);

      // The first code belongs to the first request: it no longer works.
      await _typeCode(tester, first);
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.problem_signInCodeWrong)),
        findsOneWidget,
      );
      await _typeCode(tester, env.server.sentSms.last.code);
      await settleApp(tester);
      expect(containerOf(tester).read(sessionProvider)?.id, _userId);
      await endTest(tester, env);
    });

    testWidgets('Change number and the back button go back to the number', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = await _open(tester, server: _offering(phone: true));
      await _typeNumberAndSend(tester, l);
      await tester.tap(await reveal(tester, _button(l.signInChangeNumber)));
      await settleApp(tester);
      expect(await reveal(tester, _phoneField), findsOneWidget);
      expect(find.text('01712-345678'), findsOneWidget); // kept
      expect(find.byKey(const Key('new-code-countdown')), findsNothing);

      await _typeNumberAndSend(tester, l);
      expect(_codeField, findsOneWidget);
      // Android's back button.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await settleApp(tester);
      expect(await reveal(tester, _phoneField), findsOneWidget);
      expect(_codeField, findsNothing);
      await endTest(tester, env);
    });

    testWidgets('too many codes, SMS switched off, too many tries, offline', (
      tester,
    ) async {
      final l = wordsFor('en');
      final server = _offering(phone: true)
        ..phoneCodeGlitches.addAll(const [
          ErrorStatus(429),
          ErrorStatus(403),
          NoConnection(),
        ]);
      final env = await _open(tester, server: server);
      for (final expected in [
        l.problem_tooManySignInCodes,
        l.problem_signInMethodOff,
        l.problem_offline,
      ]) {
        await _typeNumberAndSend(tester, l);
        expect(
          await reveal(tester, find.text(expected)),
          findsOneWidget,
          reason: expected,
        );
        expect(_codeField, findsNothing);
      }
      await _typeNumberAndSend(tester, l);
      server.signInGlitches.add(const ErrorStatus(429));
      await _typeCode(tester, '123456');
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.problem_tooManyCodeTries)),
        findsOneWidget,
      );
      await endTest(tester, env);
    });
  });

  group('Google', () {
    testWidgets('waits for Google, signs in, and closes the tab', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = await _open(
        tester,
        server: _offering(phone: true, google: true),
      );
      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await _settleBriefly(tester);
      expect(find.text(l.signInGoogleWaiting), findsOneWidget);
      expect(find.text(l.signInGoogleWaitingHelp), findsOneWidget);
      expect(_button(l.actionCancel), findsOneWidget);
      expect(_phoneField, findsNothing);
      expect(_button(l.signInChangeServer), findsNothing);
      await expectAccessibleTargets(tester);
      final page = env.browser.opened.single;
      expect(page.scheme, 'https');

      expect(env.server.finishGoogleSignIn(page), isTrue);
      await _settleBriefly(tester);
      expect(containerOf(tester).read(sessionProvider)?.id, _userId);
      expect(env.browser.closes, 1);
      expect(env.server.openRealtimeConnections, 0);
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.userId, _userId);
      await endTest(tester, env);
    });

    matrix('Cancel stops waiting and goes back, with nothing to fix', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await _open(
        tester,
        server: _offering(phone: true, google: true),
        language: language,
        scale: scale,
      );
      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await _settleBriefly(tester);
      expect(find.text(l.signInGoogleWaiting), findsOneWidget);
      expect(env.server.openRealtimeConnections, 1);

      await tester.tap(_button(l.actionCancel));
      await settleApp(tester);
      expect(find.text(l.signInGoogleWaiting), findsNothing);
      expect(await reveal(tester, _phoneField), findsOneWidget);
      expect(find.text(l.problem_signInCancelled), findsNothing);
      expect(env.server.openRealtimeConnections, 0);
      // Finishing on Google's page afterwards changes nothing.
      expect(env.server.finishGoogleSignIn(env.browser.opened.single), isFalse);
      await settleApp(tester);
      expect(containerOf(tester).read(sessionProvider), isNull);
      await endTest(tester, env);
    });

    testWidgets('the back button cancels too', (tester) async {
      final l = wordsFor('bn');
      final env = await _open(
        tester,
        server: _offering(google: true),
        language: 'bn',
      );
      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await _settleBriefly(tester);
      expect(find.text(l.signInGoogleWaiting), findsOneWidget);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await settleApp(tester);
      expect(find.text(l.signInGoogleWaiting), findsNothing);
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(env.server.openRealtimeConnections, 0);
      await endTest(tester, env);
    });

    matrix('a Google account the server refuses: one plain sentence', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await _open(
        tester,
        server: _offering(google: true),
        language: language,
        scale: scale,
      );
      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await _settleBriefly(tester);
      env.server.finishGoogleSignIn(
        env.browser.opened.single,
        googleEmail: 'stranger@example.org',
      );
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.problem_googleSignInRefused)),
        findsOneWidget,
      );
      expect(find.text(l.signInGoogleWaiting), findsNothing);
      // The other ways stay right there.
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(containerOf(tester).read(sessionProvider), isNull);
      expect(env.server.openRealtimeConnections, 0);
      await endTest(tester, env);
    });

    testWidgets('no browser on the phone', (tester) async {
      final l = wordsFor('en');
      final env = await _open(tester, server: _offering(google: true));
      env.browser.works = false;
      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.problem_browserUnavailable)),
        findsOneWidget,
      );
      expect(env.server.openRealtimeConnections, 0);
      await endTest(tester, env);
    });
  });

  group('the app lock is set up the same way', () {
    testWidgets('first use with an SMS code on a phone without a screen '
        'lock: choose an app PIN', (tester) async {
      final env = TestEnv(server: _offering(phone: true));
      env.deviceAuth.screenLock = false;
      final l = wordsFor('en');
      await tester.runAsync(
        () =>
            env.seedDevice((db) => env.seedSignedIn(signedIn: false, into: db)),
      );
      await pumpApp(tester, env, language: 'en', locked: true);
      await _typeNumberAndSend(tester, l);
      await _typeCode(tester, env.server.sentSms.single.code);
      await settleApp(tester);

      expect(find.byType(SetPinScreen), findsOneWidget);
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.userId, _userId);
      await endTest(tester, env);
    });

    testWidgets('first use with Google: the lock records the sign-in', (
      tester,
    ) async {
      final env = TestEnv(server: _offering(phone: true, google: true));
      final l = wordsFor('bn');
      await tester.runAsync(
        () =>
            env.seedDevice((db) => env.seedSignedIn(signedIn: false, into: db)),
      );
      await pumpApp(tester, env, locked: true);
      // First use on this phone: every way the server offers.
      expect(await reveal(tester, _phoneField), findsOneWidget);
      expect(await reveal(tester, _button(l.signInUseEmail)), findsOne);
      expect(find.text(l.reSignInPasswordForLock), findsNothing);
      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await _settleBriefly(tester);
      env.server.finishGoogleSignIn(env.browser.opened.single);
      await settleApp(tester);

      expect(find.text(l.todayTitle), findsWidgets);
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.userId, _userId);
      expect(last.at, env.now.toUtc());
      await endTest(tester, env);
    });

    testWidgets('after 30 days offline, an SMS code renews the session, but '
        'the app PIN still opens the data', (tester) async {
      final env = TestEnv(server: _offering(phone: true));
      env.deviceAuth.screenLock = false;
      final l = wordsFor('en');
      await _usedBefore(
        tester,
        env,
        signedInAgo: const Duration(days: 31),
        pin: '481592',
      );
      await pumpApp(tester, env, language: 'en', locked: true);
      expect(find.text(l.reSignInExpired), findsOneWidget);
      expect(env.opener.opens, 0);

      await _typeNumberAndSend(tester, l);
      await _typeCode(tester, env.server.sentSms.single.code);
      await settleApp(tester);
      // The session is renewed (the 30 days start again) ...
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.at, env.now.toUtc());
      // ... but the code only shows that someone holds the phone: the PIN
      // still has to open the data, and a wrong one keeps it closed.
      expect(find.byType(PinUnlockScreen), findsOneWidget);
      expect(env.opener.opens, 0);
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('pin-field'))),
        '000000',
      );
      await tester.tap(await reveal(tester, _button(l.lockUnlock)));
      await settleApp(tester);
      expect(await reveal(tester, find.text(l.pinWrong(4))), findsOneWidget);
      expect(find.byType(PinUnlockScreen), findsOneWidget);
      expect(env.opener.opens, 0);

      await tester.enterText(
        await reveal(tester, find.byKey(const Key('pin-field'))),
        '481592',
      );
      await tester.tap(await reveal(tester, _button(l.lockUnlock)));
      await settleApp(tester);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 1);
      await endTest(tester, env);
    });

    testWidgets('after 30 days offline, Google renews the session, but the '
        'phone\'s screen lock still opens the data', (tester) async {
      final env = TestEnv(server: _offering(google: true));
      final l = wordsFor('en');
      await _usedBefore(tester, env, signedInAgo: const Duration(days: 31));
      // The phone's own unlock prompt: closed once, then unlocked.
      env.deviceAuth.answers.add(DeviceUnlockResult.cancelled);
      await pumpApp(tester, env, language: 'en', locked: true);
      expect(find.text(l.reSignInExpired), findsOneWidget);
      expect(env.deviceAuth.prompts, 0);

      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await _settleBriefly(tester);
      env.server.finishGoogleSignIn(env.browser.opened.single);
      await settleApp(tester);
      expect(find.byType(DeviceUnlockScreen), findsOneWidget);
      expect(env.deviceAuth.prompts, 1);
      expect(env.opener.opens, 0);

      await tester.tap(await reveal(tester, _button(l.lockUnlock)));
      await settleApp(tester);
      expect(env.deviceAuth.prompts, 2);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 1);
      await endTest(tester, env);
    });

    testWidgets('after 30 days offline, only the same account: by SMS code '
        'and by Google', (tester) async {
      final env = TestEnv(server: _offering(phone: true, google: true));
      env.server.users['other@example.org'] = const FakeFieldUser(
        id: 'otheruser000000',
        phone: '+8801812345678',
      );
      final l = wordsFor('en');
      await _usedBefore(tester, env, signedInAgo: const Duration(days: 31));
      await pumpApp(tester, env, language: 'en', locked: true);

      await _typeNumberAndSend(tester, l, '01812345678');
      await _typeCode(tester, env.server.sentSms.single.code);
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.reSignInWrongAccount)),
        findsOneWidget,
      );
      expect(env.opener.opens, 0);

      await tester.tap(await reveal(tester, _button(l.signInChangeNumber)));
      await settleApp(tester);
      await tester.tap(await reveal(tester, _button(l.signInWithGoogle)));
      await _settleBriefly(tester);
      env.server.finishGoogleSignIn(
        env.browser.opened.single,
        googleEmail: 'other@example.org',
      );
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.reSignInWrongAccount)),
        findsOneWidget,
      );
      expect(env.opener.opens, 0);
      expect(find.byType(OnlineSignInScreen), findsOneWidget);
      await endTest(tester, env);
    });
  });

  group('where the existing unlock cannot be checked: password only', () {
    /// Asks the app lock directly for an SMS-code and a Google sign-in, as a
    /// tampered screen could: both are refused before anything is sent.
    Future<void> expectRefused(WidgetTester tester, TestEnv env) async {
      final lock = containerOf(tester).read(appLockProvider.notifier);
      final before = lock.state.value;
      await tester.runAsync(() async {
        // A real code for this account, which would work if it were sent.
        final request = await lock.withServer(
          (server) => server.requestPhoneCode(fakePhone),
        );
        await expectLater(
          lock.signInOnlineWith(
            PhoneCodeSignIn(request, env.server.sentSms.last.code),
          ),
          throwsA(isA<PasswordRequired>()),
        );
        await expectLater(
          lock.signInOnlineWith(
            GoogleBrowserSignIn(env.browser, SignInCancellation()),
          ),
          throwsA(isA<PasswordRequired>()),
        );
      });
      expect(
        env.server.log,
        isNot(contains('POST /api/obhijatra/v1/signin/phone/verify')),
      );
      expect(env.browser.opened, isEmpty);
      expect(env.server.openRealtimeConnections, 0);
      expect(lock.state.value, same(before));
      expect(env.opener.opens, 0);
    }

    /// Only email and password on the screen, with [note].
    Future<void> expectPasswordOnly(
      WidgetTester tester,
      AppLocalizations l,
      String note,
    ) async {
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(_phoneField, findsNothing);
      expect(_button(l.signInWithGoogle), findsNothing);
      expect(_button(l.signInUsePhone), findsNothing);
      expect(find.text(l.signInOtherWays), findsNothing);
      expect(await reveal(tester, find.text(note)), findsOneWidget);
    }

    matrix('a forgotten PIN: email and password only, then a new PIN', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(server: _offering(phone: true, google: true));
      env.deviceAuth.screenLock = false;
      await _usedBefore(tester, env, pin: '481592');
      await pumpApp(
        tester,
        env,
        language: language,
        textScale: scale,
        locked: true,
      );
      await tester.tap(await reveal(tester, _button(l.pinForgot)));
      await settleApp(tester);
      expect(find.text(l.reSignInForgotPin), findsOneWidget);
      await expectPasswordOnly(tester, l, l.reSignInPasswordForPin);
      await expectAccessibleTargets(tester);
      await expectRefused(tester, env);

      await tester.enterText(await reveal(tester, _emailField), fakeEmail);
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('password-field'))),
        fakePassword,
      );
      await tester.tap(await reveal(tester, _button(l.signInTitle)));
      await settleApp(tester);
      expect(find.byType(SetPinScreen), findsOneWidget);
      expect(env.opener.opens, 0);
      await endTest(tester, env);
    });

    testWidgets('no screen lock and no PIN: email and password only', (
      tester,
    ) async {
      final env = TestEnv(server: _offering(phone: true, google: true));
      env.deviceAuth.screenLock = false;
      final l = wordsFor('bn');
      await _usedBefore(tester, env);
      await pumpApp(tester, env, locked: true);
      expect(find.text(l.reSignInNoLock), findsOneWidget);
      await expectPasswordOnly(tester, l, l.reSignInPasswordForLock);
      await expectRefused(tester, env);
      await endTest(tester, env);
    });

    testWidgets('30 days offline on a phone with no way to unlock: email and '
        'password only', (tester) async {
      final env = TestEnv(server: _offering(phone: true, google: true));
      env.deviceAuth.screenLock = false;
      final l = wordsFor('en');
      await _usedBefore(tester, env, signedInAgo: const Duration(days: 31));
      await pumpApp(tester, env, language: 'en', locked: true);
      expect(find.text(l.reSignInExpired), findsOneWidget);
      await expectPasswordOnly(tester, l, l.reSignInPasswordForLock);
      await expectRefused(tester, env);
      await endTest(tester, env);
    });

    testWidgets('no note when the server offers only the password', (
      tester,
    ) async {
      final env = TestEnv();
      env.deviceAuth.screenLock = false;
      final l = wordsFor('en');
      await _usedBefore(tester, env, pin: '481592');
      await pumpApp(tester, env, language: 'en', locked: true);
      await tester.tap(await reveal(tester, _button(l.pinForgot)));
      await settleApp(tester);
      expect(await reveal(tester, _emailField), findsOneWidget);
      expect(find.text(l.reSignInPasswordForPin), findsNothing);
      await endTest(tester, env);
    });

    test('the sentences', () {
      final en = wordsFor('en');
      expect(
        en.reSignInPasswordForPin,
        'To reset your PIN, sign in with your email and password. If your '
        'account has no password, ask your organisation admin.',
      );
    });
  });
}

/// The phone was used before by the fake's first user: the server address
/// and a session in the database, an online sign-in [signedInAgo], and the
/// app PIN [pin] if given.
Future<void> _usedBefore(
  WidgetTester tester,
  TestEnv env, {
  Duration signedInAgo = const Duration(days: 1),
  String? pin,
}) async {
  await tester.runAsync(() async {
    await env.seedDevice((db) => env.seedSignedIn(into: db));
    final lock = env.lockStore(at: env.now.subtract(signedInAgo));
    await lock.recordOnlineSignIn(_userId);
    await lock.rememberServerAddress(FakeObhijatraServer.baseUrl);
    if (pin != null) await lock.setPin(pin);
  });
}
