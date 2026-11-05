// One-time passwords: a person whose organisation admin gave them a
// one-time password chooses their own on a full-screen step right after
// signing in, before the app lock is set up or the data opens, and the app
// then carries on exactly as after that sign-in. When sending stops for the
// same reason, a banner on the Today screen opens the same step; queued
// forms stay queued.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/platform/device_authenticator.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/screens/change_password_screen.dart';
import 'package:obhijatra_field/src/screens/lock_screens.dart';
import 'package:obhijatra_field/src/screens/main_shell.dart';
import 'package:obhijatra_field/src/screens/sign_in_screen.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'support/harness.dart';

Finder _button(String label) => find.widgetWithText(PrimaryButton, label);

final Finder _currentField = find.byKey(const Key('current-password-field'));
final Finder _newField = find.byKey(const Key('new-password-field'));
final Finder _repeatField = find.byKey(const Key('repeat-password-field'));

/// The field user every fake server starts with.
const String _userId = 'fielduser1abcde';

/// The one-time password the admin gives.
const String _oneTime = 'kfmw-tqzp-hrvx';

/// The password the person chooses: four words.
const String _own = 'river tea mango kite';

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(await reveal(tester, field), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(await reveal(tester, finder));
  await settleApp(tester);
}

/// Signs in with email and password on the form on screen.
Future<void> _signInWithPassword(
  WidgetTester tester,
  AppLocalizations l,
  String password,
) async {
  await _type(tester, find.byKey(const Key('email-field')), fakeEmail);
  await _type(tester, find.byKey(const Key('password-field')), password);
  await _tap(tester, _button(l.signInTitle));
}

/// Signs in with the code from the SMS on the form on screen.
Future<void> _signInWithSms(
  WidgetTester tester,
  TestEnv env,
  AppLocalizations l,
) async {
  await _type(tester, find.byKey(const Key('phone-field')), '01712-345678');
  await _tap(tester, _button(l.signInSendCode));
  await _type(
    tester,
    find.byKey(const Key('code-field')),
    env.server.sentSms.last.code,
  );
  await settleApp(tester);
}

/// Types the new password twice (or [repeat] the second time) and saves.
Future<void> _chooseNew(
  WidgetTester tester,
  AppLocalizations l, {
  String password = _own,
  String? repeat,
}) async {
  await _type(tester, _newField, password);
  await _type(tester, _repeatField, repeat ?? password);
  await _tap(tester, _button(l.passwordChangeSave));
}

/// No PATCH reached the server.
void _expectNothingSent(TestEnv env) => expect(
  env.server.log.where((r) => r.startsWith('PATCH ')),
  isEmpty,
  reason: 'the password change was sent',
);

/// The phone was used before by the fake's first user: the server address
/// and a session in the database, and an online sign-in [signedInAgo].
Future<void> _usedBefore(
  WidgetTester tester,
  TestEnv env, {
  Duration signedInAgo = const Duration(days: 1),
}) async {
  await tester.runAsync(() async {
    await env.seedDevice((db) => env.seedSignedIn(into: db));
    final lock = env.lockStore(at: env.now.subtract(signedInAgo));
    await lock.recordOnlineSignIn(_userId);
    await lock.rememberServerAddress(FakeObhijatraServer.baseUrl);
  });
}

/// First use of the app on this phone (the server address saved, nobody
/// signed in yet), behind the real app lock.
Future<TestEnv> _firstUse(
  WidgetTester tester, {
  String language = 'en',
  double scale = 1.0,
  bool screenLock = true,
  bool phone = false,
}) async {
  final env = TestEnv()
    ..deviceAuth.screenLock = screenLock
    ..server.offersPhone = phone;
  await tester.runAsync(
    () => env.seedDevice((db) => env.seedSignedIn(signedIn: false, into: db)),
  );
  env.server.giveOneTimePassword(fakeEmail, _oneTime);
  await pumpApp(tester, env, language: language, textScale: scale, locked: true);
  return env;
}

void main() {
  group('right after signing in', () {
    matrix('a one-time password typed to sign in is not asked again; the '
        'app PIN is set up afterwards', (tester, language, scale, l) async {
      final env = await _firstUse(
        tester,
        language: language,
        scale: scale,
        screenLock: false,
      );
      await _signInWithPassword(tester, l, _oneTime);

      // The step, before anything else: no PIN yet, nothing recorded.
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(find.text(l.passwordChangeTitle), findsWidgets);
      expect(await reveal(tester, find.text(l.passwordChangeBody)), findsOne);
      expect(await reveal(tester, find.text(l.passwordChangeHint)), findsOne);
      expect(_currentField, findsNothing);
      expect(await reveal(tester, _newField), findsOneWidget);
      expect(await reveal(tester, _repeatField), findsOneWidget);
      expect(
        await reveal(tester, _button(l.passwordChangeSignOut)),
        findsOneWidget,
      );
      expect(find.byType(SetPinScreen), findsNothing);
      expect(await tester.runAsync(env.lockStore().lastOnlineSignIn), isNull);
      expect(containerOf(tester).read(sessionProvider), isNull);
      await expectAccessibleTargets(tester);

      await _chooseNew(tester, l);

      // The same path as any sign-in: the app lock asks for an app PIN.
      expect(find.byType(SetPinScreen), findsOneWidget);
      expect(env.server.mustChangePassword(fakeEmail), isFalse);
      expect(env.server.passwordOf(fakeEmail), _own);
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.userId, _userId);
      expect(containerOf(tester).read(sessionProvider)?.id, _userId);
      expect(
        containerOf(tester).read(sessionProvider)!.mustChangePassword,
        isFalse,
      );
      await endTest(tester, env);
    });

    testWidgets('the show buttons show what was typed', (tester) async {
      final l = wordsFor('en');
      final env = await _firstUse(tester);
      await _signInWithPassword(tester, l, _oneTime);
      await _type(tester, _newField, _own);
      bool hidden() =>
          tester.widget<TextField>(find.byKey(const Key('new-password-field')))
              .obscureText;
      expect(hidden(), isTrue);
      await tester.tap(find.byTooltip(l.signInShowPassword).first);
      await tester.pump();
      expect(hidden(), isFalse);
      expect(find.text(_own), findsOneWidget);
      await tester.tap(find.byTooltip(l.signInHidePassword).first);
      await tester.pump();
      expect(hidden(), isTrue);
      await endTest(tester, env);
    });

    matrix('after an SMS code the one-time password is asked for', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await _firstUse(
        tester,
        language: language,
        scale: scale,
        phone: true,
      );
      await _signInWithSms(tester, env, l);

      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(await reveal(tester, _currentField), findsOneWidget);
      expect(
        await reveal(tester, find.text(l.passwordChangeCurrent)),
        findsOneWidget,
      );
      await expectAccessibleTargets(tester);
      // The one-time password must be typed.
      await _chooseNew(tester, l);
      expect(
        await reveal(tester, find.text(l.passwordChangeCurrentEmpty)),
        findsOneWidget,
      );
      _expectNothingSent(env);

      await _type(tester, _currentField, _oneTime);
      await _chooseNew(tester, l);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.server.mustChangePassword(fakeEmail), isFalse);
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.userId, _userId);
      await endTest(tester, env);
    });

    testWidgets('a wrong one-time password says so, and the right one '
        'works', (tester) async {
      final l = wordsFor('en');
      final env = await _firstUse(tester, phone: true);
      await _signInWithSms(tester, env, l);
      await _type(tester, _currentField, 'not-the-one-time');
      await _chooseNew(tester, l);
      expect(
        await reveal(tester, find.text(l.problem_currentPasswordWrong)),
        findsOneWidget,
      );
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(env.server.mustChangePassword(fakeEmail), isTrue);
      // The field is empty again, ready for the right password.
      expect(
        tester.widget<TextField>(_currentField).controller!.text,
        isEmpty,
      );

      await _type(tester, _currentField, _oneTime);
      await _chooseNew(tester, l);
      expect(find.text(l.todayTitle), findsWidgets);
      await endTest(tester, env);
    });

    matrix('too short, the one-time password again, or two different '
        'passwords: said plainly, nothing sent', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await _firstUse(tester, language: language, scale: scale);
      await _signInWithPassword(tester, l, _oneTime);
      env.server.log.clear();

      await _chooseNew(tester, l, password: 'tea mango');
      expect(
        await reveal(tester, find.text(l.passwordChangeTooShort)),
        findsOneWidget,
      );
      await _chooseNew(tester, l, password: _oneTime);
      expect(
        await reveal(tester, find.text(l.passwordChangeSameAsOld)),
        findsOneWidget,
      );
      await _chooseNew(tester, l, repeat: 'river tea mango kites');
      expect(
        await reveal(tester, find.text(l.passwordChangeMismatch)),
        findsOneWidget,
      );
      // The repeat is cleared, to be typed again.
      expect(tester.widget<TextField>(_repeatField).controller!.text, isEmpty);
      await expectAccessibleTargets(tester);
      _expectNothingSent(env);
      expect(env.server.mustChangePassword(fakeEmail), isTrue);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      await endTest(tester, env);
    });

    testWidgets('offline says so; trying again works', (tester) async {
      final l = wordsFor('en');
      final env = await _firstUse(tester);
      await _signInWithPassword(tester, l, _oneTime);
      env.server.passwordChangeGlitches.add(const NoConnection());
      await _chooseNew(tester, l);
      expect(
        await reveal(tester, find.text(l.problem_offline)),
        findsOneWidget,
      );
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(env.server.mustChangePassword(fakeEmail), isTrue);

      await _tap(tester, _button(l.passwordChangeSave));
      expect(find.text(l.todayTitle), findsWidgets);
      await endTest(tester, env);
    });

    testWidgets('saved, but signing in with it failed: sign in again with '
        'the new password', (tester) async {
      final l = wordsFor('en');
      final env = await _firstUse(tester);
      await _signInWithPassword(tester, l, _oneTime);
      env.server.signInGlitches.add(const NoConnection());
      await _chooseNew(tester, l);
      expect(
        await reveal(tester, find.text(l.problem_passwordChangedSignInAgain)),
        findsOneWidget,
      );
      expect(_newField, findsNothing);
      expect(await tester.runAsync(env.lockStore().lastOnlineSignIn), isNull);

      await _tap(tester, _button(l.passwordChangeSignInAgain));
      expect(find.byType(ChangePasswordScreen), findsNothing);
      await _signInWithPassword(tester, l, _own);
      expect(find.text(l.todayTitle), findsWidgets);
      await endTest(tester, env);
    });

    testWidgets('Sign out goes back to signing in; nothing is recorded', (
      tester,
    ) async {
      final l = wordsFor('bn');
      final env = await _firstUse(tester, language: 'bn', phone: true);
      await _signInWithSms(tester, env, l);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);

      await _tap(tester, _button(l.passwordChangeSignOut));
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
      // Back at the mobile number: that code is used up.
      expect(
        await reveal(tester, find.byKey(const Key('phone-field'))),
        findsOneWidget,
      );
      expect(containerOf(tester).read(sessionProvider), isNull);
      expect(await tester.runAsync(env.lockStore().lastOnlineSignIn), isNull);
      await endTest(tester, env);
    });

    testWidgets('the app closed during the step: the saved one-time session '
        'does not count as signed in', (tester) async {
      final env = TestEnv();
      final l = wordsFor('en');
      env.server.giveOneTimePassword(fakeEmail, _oneTime);
      await tester.runAsync(() async {
        await env.seedSignedIn(signedIn: false);
        final client = ObhijatraServer(
          baseUrl: FakeObhijatraServer.baseUrl,
          appVersion: appReleaseVersion,
          authStore: await SettingsRepository(env.db).authStore(),
          httpClientFactory: env.server.client,
        );
        await client.signIn(email: fakeEmail, password: _oneTime);
        client.close();
      });
      await pumpApp(tester, env, language: 'en');
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text(l.todayTitle), findsNothing);
      expect(containerOf(tester).read(sessionProvider), isNull);
      await endTest(tester, env);
    });
  });

  group('the app lock stays as it is', () {
    testWidgets('after 30 days offline, an SMS code and a new password renew '
        'the session, but the phone\'s screen lock still opens the data', (
      tester,
    ) async {
      final env = TestEnv()..server.offersPhone = true;
      final l = wordsFor('en');
      await _usedBefore(tester, env, signedInAgo: const Duration(days: 31));
      env.server.giveOneTimePassword(fakeEmail, _oneTime);
      // The phone's own unlock prompt: closed once, then unlocked.
      env.deviceAuth.answers.add(DeviceUnlockResult.cancelled);
      await pumpApp(tester, env, language: 'en', locked: true);
      expect(find.text(l.reSignInExpired), findsOneWidget);

      await _signInWithSms(tester, env, l);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(await reveal(tester, _currentField), findsOneWidget);
      expect(env.opener.opens, 0);
      final before = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(before!.at, isNot(env.now.toUtc()));

      await _type(tester, _currentField, _oneTime);
      await _chooseNew(tester, l);
      // Renewed (the 30 days start again) ...
      final last = await tester.runAsync(env.lockStore().lastOnlineSignIn);
      expect(last!.at, env.now.toUtc());
      expect(env.server.mustChangePassword(fakeEmail), isFalse);
      // ... but the SMS code only shows that someone holds the phone.
      expect(find.byType(DeviceUnlockScreen), findsOneWidget);
      expect(env.deviceAuth.prompts, 1);
      expect(env.opener.opens, 0);

      await _tap(tester, _button(l.lockUnlock));
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.opener.opens, 1);
      // The new session reached the database once it opened.
      expect(containerOf(tester).read(sessionProvider)?.id, _userId);
      await endTest(tester, env);
    });

    testWidgets('after 30 days offline, email and the one-time password, '
        'then a new password, open the data as a password does', (
      tester,
    ) async {
      final env = TestEnv();
      final l = wordsFor('en');
      await _usedBefore(tester, env, signedInAgo: const Duration(days: 31));
      env.server.giveOneTimePassword(fakeEmail, _oneTime);
      await pumpApp(tester, env, language: 'en', locked: true);
      await _signInWithPassword(tester, l, _oneTime);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(_currentField, findsNothing);
      expect(env.opener.opens, 0);

      await _chooseNew(tester, l);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(env.deviceAuth.prompts, 0);
      expect(env.opener.opens, 1);
      await endTest(tester, env);
    });

    testWidgets('another account with a one-time password is refused before '
        'the step', (tester) async {
      final env = TestEnv()..server.offersPhone = true;
      env.server.users['other@example.org'] = const FakeFieldUser(
        id: 'otheruser000000',
        phone: '+8801812345678',
      );
      final l = wordsFor('en');
      await _usedBefore(tester, env, signedInAgo: const Duration(days: 31));
      env.server.giveOneTimePassword('other@example.org', _oneTime);
      await pumpApp(tester, env, language: 'en', locked: true);
      await _type(tester, find.byKey(const Key('phone-field')), '01812345678');
      await _tap(tester, _button(l.signInSendCode));
      await _type(
        tester,
        find.byKey(const Key('code-field')),
        env.server.sentSms.single.code,
      );
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.reSignInWrongAccount)),
        findsOneWidget,
      );
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(env.opener.opens, 0);
      await endTest(tester, env);
    });
  });

  group('when sending stops for it', () {
    matrix('a banner opens the same step; queued forms stay queued, then '
        'go', (tester, language, scale, l) async {
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(() async {
        await env.seedSignedIn();
        await env.storeForm(householdVisitXForm);
        await OutboxRepository(env.db).enqueue(
          const FinalisedInstance(
            form: FormVersionRef('household_visit', '2026110401'),
            instanceId: 'uuid:aaaaaaaa-0000-4000-8000-000000000003',
            xml:
                '<data id="household_visit" version="2026110401"><meta>'
                '<instanceID>uuid:aaaaaaaa-0000-4000-8000-000000000003'
                '</instanceID></meta></data>',
            attachmentNames: <String>[],
          ),
        );
      });
      // The admin asks for a new password while the phone holds a session.
      env.server.requirePasswordChange(fakeEmail);
      await pumpScreen(
        tester,
        env,
        const MainShell(),
        language: language,
        textScale: scale,
      );
      expect(
        await reveal(tester, find.text(l.passwordChangeBanner)),
        findsOneWidget,
      );
      expect(
        (await currentSyncStatus(tester)).blockedBy,
        ProblemCode.passwordChangeRequired,
      );
      final queued = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(queued!.single.state, OutboxState.queued);
      expect(env.server.submissions, isEmpty);
      await expectAccessibleTargets(tester);

      await _tap(tester, _button(l.passwordChangeOpen));
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(await reveal(tester, _currentField), findsOneWidget);
      await expectAccessibleTargets(tester);
      // Here the current password is the person's own (only the flag was
      // set); a one-time password works the same way.
      await _type(tester, _currentField, fakePassword);
      await _chooseNew(tester, l);

      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.text(l.passwordChangeBanner), findsNothing);
      expect(env.server.submissions, hasLength(1));
      final sent = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(sent!.single.state, OutboxState.sent);
      expect((await currentSyncStatus(tester)).blockedBy, isNull);
      await endTest(tester, env);
    });

    testWidgets('updating forms alone shows it too; Back leaves it for later', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(env.seedSignedIn);
      env.server.requirePasswordChange(fakeEmail);
      await pumpScreen(tester, env, const MainShell(), language: 'en');
      expect(
        await reveal(tester, find.text(l.passwordChangeBanner)),
        findsOneWidget,
      );
      // Not the generic "could not update the forms" line as well.
      expect(
        find.text(l.formsUpdateFailed(l.problem_passwordChangeRequired)),
        findsNothing,
      );
      await _tap(tester, _button(l.passwordChangeOpen));
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      await _tap(tester, find.byTooltip(l.actionBack));
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.text(l.passwordChangeBanner), findsOneWidget);
      await endTest(tester, env);
    });

    testWidgets('Sign out from the step goes to signing in; forms stay', (
      tester,
    ) async {
      final l = wordsFor('en');
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(env.seedSignedIn);
      env.server.requirePasswordChange(fakeEmail);
      await pumpApp(tester, env, language: 'en');
      await _tap(tester, _button(l.passwordChangeOpen));
      await _tap(tester, _button(l.passwordChangeSignOut));
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(containerOf(tester).read(sessionProvider), isNull);
      await endTest(tester, env);
    });
  });
}
