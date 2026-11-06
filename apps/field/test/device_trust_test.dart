// Device trust (docs/decisions/0008-device-trust.md) in the field app: the
// phone enrols right after sign-in and waits for approval on a screen that
// shows its 18 numbers, checks again by itself, and moves on once approved;
// an approval that ran out and a phone that was switched off have screens of
// their own; a phone the server no longer knew enrols again with the same
// numbers; a wrong clock and an ended session say what to do; forms on the
// phone can be filled in meanwhile, and nothing waiting is lost. Every
// request the app makes is checked by the fake server, signatures included.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/screens/change_password_screen.dart';
import 'package:obhijatra_field/src/screens/device_screen.dart';
import 'package:obhijatra_field/src/screens/settings_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'support/harness.dart';

Finder _button(String label) => find.widgetWithText(PrimaryButton, label);

/// [text] anywhere in the app, also where the list has scrolled it away.
Finder _anywhere(String text) => find.text(text, skipOffstage: false);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(await reveal(tester, finder));
  await settleApp(tester);
}

/// The one-time password an organisation admin gives.
const String _oneTime = 'kfmw-tqzp-hrvx';

/// The password the person then chooses.
const String _own = 'river tea mango kite';

/// Signs in with the email address and [password] on the form on screen.
Future<void> _signIn(
  WidgetTester tester,
  AppLocalizations l, {
  String password = fakePassword,
}) async {
  await tester.enterText(
    await reveal(tester, find.byKey(const Key('email-field'))),
    fakeEmail,
  );
  await tester.enterText(
    await reveal(tester, find.byKey(const Key('password-field'))),
    password,
  );
  await _tap(tester, _button(l.signInTitle));
  await settleApp(tester);
}

/// The six groups of three digits the screen shows, in [language].
List<String> _groups(String code, String language) => <String>[
  for (var i = 0; i < 18; i += 3)
    language == 'bn'
        ? toBanglaDigits(code.substring(i, i + 3))
        : code.substring(i, i + 3),
];

/// The phone's numbers, from its device on the fake server.
String _codeOf(TestEnv env) => env.phoneDevice!.checkCode;

/// A form waiting to be sent.
const FinalisedInstance _waiting = FinalisedInstance(
  form: FormVersionRef('household_visit', '2026110401'),
  instanceId: 'uuid:aaaaaaaa-0000-4000-8000-000000000008',
  xml:
      '<data id="household_visit" version="2026110401"><meta>'
      '<instanceID>uuid:aaaaaaaa-0000-4000-8000-000000000008'
      '</instanceID></meta></data>',
  attachmentNames: <String>[],
);

/// A phone that signed in and enrolled, and waits for approval.
Future<TestEnv> _waitingPhone(
  WidgetTester tester, {
  bool withForms = false,
}) async {
  final env = TestEnv(xform: householdVisitXForm);
  await tester.runAsync(() async {
    await env.seedSignedIn(deviceApproved: false);
    if (withForms) await env.storeForm(householdVisitXForm);
  });
  env.server.approveDevicesAtOnce = false;
  return env;
}

void main() {
  matrix('a new phone waits for approval, shows its numbers large and in '
      'the language of the app, and moves on once approved', (
    tester,
    language,
    scale,
    l,
  ) async {
    final env = await _waitingPhone(tester);
    await pumpApp(tester, env, language: language, textScale: scale);

    expect(find.text(l.deviceWaitingTitle), findsOneWidget);
    expect(await reveal(tester, find.text(l.deviceWaitingBody)), findsOne);
    expect(await reveal(tester, find.text(l.deviceShowInPerson)), findsOne);
    expect(await reveal(tester, find.text(l.deviceNeverSend)), findsOne);
    // Six groups of three, as the approver's app shows them.
    final groups = _groups(_codeOf(env), language);
    for (final group in groups) {
      expect(await reveal(tester, find.text(group)), findsWidgets);
    }
    // Read out digit by digit, group by group.
    final spoken = l.deviceCodeSpoken(
      groups.map((g) => g.split('').join(' ')).join(', '),
    );
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(spoken), findsOneWidget);
    semantics.dispose();
    // Large enough to read at arm's length.
    final digits = tester.widget<Text>(find.text(groups.first).first);
    expect(digits.style!.fontSize, greaterThanOrEqualTo(32));
    // Nothing to fill in on a new phone, so no way to skip the wait.
    expect(_button(l.deviceFillInForms), findsNothing);
    await expectAccessibleTargets(tester);

    // The approver checks the numbers; the person taps Check again.
    env.server.approveDevice(env.phoneDevice!.id, groups.join(' '));
    await _tap(tester, _button(l.deviceCheckAgain));
    expect(find.text(l.todayTitle), findsWidgets);
    expect(_anywhere(l.deviceWaitingTitle), findsNothing);
    await endTest(tester, env);
  }, scales: const <double>[1.0, 2.0]);

  testWidgets('the waiting screen checks again by itself every 15 seconds', (
    tester,
  ) async {
    final env = await _waitingPhone(tester);
    await pumpApp(tester, env, language: 'en');
    final l = wordsFor('en');
    expect(find.text(l.deviceWaitingTitle), findsOneWidget);
    final asked = env.server.log.where((r) => r.endsWith('/devices/me'));
    final before = asked.length;
    expect(before, greaterThanOrEqualTo(1)); // once when it opened

    await tester.pump(deviceCheckInterval);
    await settleApp(tester);
    expect(asked.length, before + 1);
    expect(
      await reveal(tester, find.byKey(const Key('device-last-checked'))),
      findsOneWidget,
    );

    env.server.approveDevice(env.phoneDevice!.id, _codeOf(env));
    await tester.pump(deviceCheckInterval);
    await settleApp(tester);
    expect(find.text(l.todayTitle), findsWidgets);
    // Once approved, the forms come at once.
    expect(
      env.server.log,
      contains('GET /api/collections/form_versions/records'),
    );
    await endTest(tester, env);
  });

  testWidgets('the sign-in enrols the phone, and nothing but its status is '
      'asked before the approval', (tester) async {
    final env = TestEnv(xform: householdVisitXForm);
    env.server.approveDevicesAtOnce = false;
    await tester.runAsync(() => env.seedSignedIn(signedIn: false));
    await pumpApp(tester, env, language: 'en');
    final l = wordsFor('en');
    final code = (await tester.runAsync(
      () => DeviceIdentity.open(env.deviceStore),
    ))!.checkCode;
    expect(env.deviceStore.seedsText, isNotNull); // made before sign-in

    await _signIn(tester, l);

    expect(find.text(l.deviceWaitingTitle), findsOneWidget);
    final device = env.phoneDevice!;
    expect(device.status, 'pending');
    expect(device.checkCode, code);
    expect(device.label, 'Field app, Android');
    expect(device.platform, 'android');
    expect(env.server.log.where((r) => r.contains('form_versions')), isEmpty);
    await endTest(tester, env);
  });

  testWidgets('an approved phone opens offline with the approval it knows', (
    tester,
  ) async {
    final env = TestEnv(xform: householdVisitXForm);
    await tester.runAsync(() async {
      await env.seedSignedIn();
      await env.storeForm(householdVisitXForm);
    });
    env
      ..startOnline = false
      ..server.metaGlitch = const NoConnection()
      ..server.deviceGlitches.addAll(<Glitch>[
        const NoConnection(),
        const NoConnection(),
      ]);
    await pumpApp(tester, env, language: 'en');
    final l = wordsFor('en');
    expect(find.text(l.todayTitle), findsWidgets);
    expect(find.text(l.deviceWaitingTitle), findsNothing);
    expect(await reveal(tester, find.text('Household visit')), findsWidgets);
    await endTest(tester, env);
  });

  matrix('approval ran out: the same numbers, worded for renewal; forms on '
      'the phone can be filled in meanwhile', (
    tester,
    language,
    scale,
    l,
  ) async {
    final env = TestEnv(xform: householdVisitXForm);
    await tester.runAsync(() async {
      await env.seedSignedIn();
      await env.storeForm(householdVisitXForm);
    });
    env.server.expireDevice(env.phoneDevice!.id);
    await pumpApp(tester, env, language: language, textScale: scale);

    // The app learnt it when it asked for forms.
    expect(find.text(l.deviceRenewalTitle), findsOneWidget);
    expect(await reveal(tester, find.text(l.deviceRenewalBody)), findsOne);
    for (final group in _groups(_codeOf(env), language)) {
      expect(await reveal(tester, find.text(group)), findsWidgets);
    }
    await expectAccessibleTargets(tester);

    // Filling in forms does not wait for the approval.
    await _tap(tester, _button(l.deviceFillInForms));
    expect(find.text(l.todayTitle), findsWidgets);
    expect(await reveal(tester, find.text(l.deviceNoticeRenewal)), findsOne);
    expect(await reveal(tester, find.text('Household visit')), findsWidgets);

    // The notice opens the numbers again; the approval closes them.
    await _tap(tester, _button(l.deviceShowCode));
    expect(find.text(l.deviceRenewalTitle), findsOneWidget);
    env.server.approveDevice(env.phoneDevice!.id, _codeOf(env));
    await _tap(tester, _button(l.deviceCheckAgain));
    expect(_anywhere(l.deviceRenewalTitle), findsNothing);
    expect(_anywhere(l.deviceNoticeRenewal), findsNothing);
    expect(find.text(l.todayTitle), findsWidgets);
    await endTest(tester, env);
  }, scales: const <double>[1.0, 2.0]);

  testWidgets('filling in forms meanwhile: "Update forms" asks the server '
      'first, so an approval that came meanwhile counts at once', (
    tester,
  ) async {
    final env = await _waitingPhone(tester, withForms: true);
    await pumpApp(tester, env, language: 'en');
    final l = wordsFor('en');
    await _tap(tester, _button(l.deviceFillInForms));
    expect(await reveal(tester, find.text(l.deviceNoticeWaiting)), findsOne);
    expect(env.server.log.where((r) => r.contains('form_versions')), isEmpty);

    env.server.approveDevice(env.phoneDevice!.id, _codeOf(env));
    await _tap(tester, _button(l.formsUpdate));
    expect(_anywhere(l.deviceNoticeWaiting), findsNothing);
    expect(
      env.server.log,
      contains('GET /api/collections/form_versions/records'),
    );
    await endTest(tester, env);
  });

  matrix('the server no longer knew this phone: it enrols again with the '
      'same numbers, says so, and waits; unsent forms stay and are sent once '
      'approved', (tester, language, scale, l) async {
    final env = TestEnv(xform: householdVisitXForm);
    await tester.runAsync(() async {
      await env.seedSignedIn();
      await env.storeForm(householdVisitXForm);
      await OutboxRepository(env.db).enqueue(_waiting);
    });
    final first = env.phoneDevice!;
    final code = first.checkCode;
    final seeds = env.deviceStore.seedsText;
    // A restore from a backup older than the enrolment.
    env.server
      ..approveDevicesAtOnce = false
      ..forgetDevice(first.id);
    await pumpApp(tester, env, language: language, textScale: scale);

    // The app learnt it when it asked for forms, and enrolled again.
    expect(find.text(l.deviceWaitingTitle), findsOneWidget);
    expect(await reveal(tester, find.text(l.deviceServerForgot)), findsOne);
    final second = env.phoneDevice!;
    expect(second.id, isNot(first.id));
    expect(second.status, 'pending');
    expect(second.checkCode, code);
    expect(env.deviceStore.seedsText, seeds);
    for (final group in _groups(code, language)) {
      expect(await reveal(tester, find.text(group)), findsWidgets);
    }
    await expectAccessibleTargets(tester);
    // Nothing waiting was lost, sent or marked as failed.
    final entry = await tester.runAsync(
      () => OutboxRepository(env.db).find(_waiting.instanceId),
    );
    expect(entry!.state, OutboxState.queued);
    expect(entry.attempts, 0);
    expect(env.server.submissions, isEmpty);

    // Approved again with the same numbers: the app carries on and sends.
    env.server.approveDevice(second.id, code);
    await _tap(tester, _button(l.deviceCheckAgain));
    expect(find.text(l.todayTitle), findsWidgets);
    expect(_anywhere(l.deviceServerForgot), findsNothing);
    expect(env.server.submissions, hasLength(1));
    await endTest(tester, env);
  }, scales: const <double>[1.0, 2.0]);

  matrix('switched off: explained; set up again only after a confirmation, '
      'with new numbers; unsent forms stay', (
    tester,
    language,
    scale,
    l,
  ) async {
    final env = TestEnv(xform: householdVisitXForm);
    await tester.runAsync(() async {
      await env.seedSignedIn();
      await env.storeForm(householdVisitXForm);
      await OutboxRepository(env.db).enqueue(_waiting);
    });
    final first = env.phoneDevice!;
    env.server.revokeDevice(first.id);
    await pumpApp(tester, env, language: language, textScale: scale);

    expect(find.text(l.deviceSwitchedOffTitle), findsOneWidget);
    expect(await reveal(tester, find.text(l.deviceSwitchedOffKept)), findsOne);
    // The waiting form was not sent, and is not marked as failed.
    var entries = await tester.runAsync(
      () => OutboxRepository(env.db).entries(),
    );
    expect(entries!.single.state, OutboxState.queued);
    expect(env.server.submissions, isEmpty);
    await expectAccessibleTargets(tester);

    // A confirmation that names what happens; cancelling changes nothing.
    await _tap(tester, _button(l.deviceSetUpAgain));
    expect(find.text(l.deviceSetUpAgainBody), findsOneWidget);
    await _tap(tester, find.text(l.actionCancel));
    expect(_anywhere(l.deviceSetUpAgainBody), findsNothing);
    expect(await reveal(tester, find.text(l.deviceSwitchedOffTitle)), findsOne);
    expect(env.phoneDevice!.id, first.id);

    await _tap(tester, _button(l.deviceSetUpAgain));
    await _tap(tester, find.text(l.deviceSetUpAgainConfirm));
    // Signed out, with new keys and nothing enrolled.
    expect(find.text(l.signInTitle), findsWidgets);
    expect(env.deviceStore.enrolmentText, isNull);
    entries = await tester.runAsync(() => OutboxRepository(env.db).entries());
    expect(entries, hasLength(1));

    // Sign in again: the phone enrols as a new device and waits.
    env.server.approveDevicesAtOnce = false;
    await _signIn(tester, l);
    expect(find.text(l.deviceWaitingTitle), findsOneWidget);
    final second = env.phoneDevice!;
    expect(second.id, isNot(first.id));
    expect(second.checkCode, isNot(first.checkCode));
    expect(
      await reveal(tester, find.text(_groups(second.checkCode, language)[0])),
      findsWidgets,
    );
    await endTest(tester, env);
  }, scales: const <double>[1.0, 2.0]);

  matrix('a wrong clock: set the date and time, then check again', (
    tester,
    language,
    scale,
    l,
  ) async {
    final env = await _waitingPhone(tester);
    env.server.clockOffset = const Duration(minutes: 6);
    await pumpApp(tester, env, language: language, textScale: scale);
    expect(
      await reveal(tester, find.text(l.problem_deviceClockWrong)),
      findsOneWidget,
    );
    env.server.clockOffset = Duration.zero;
    await _tap(tester, _button(l.deviceCheckAgain));
    expect(_anywhere(l.problem_deviceClockWrong), findsNothing);
    expect(await reveal(tester, find.text(l.deviceWaitingTitle)), findsOne);
    await endTest(tester, env);
  }, scales: const <double>[1.0]);

  testWidgets('no signal: the waiting screen says so and keeps the numbers', (
    tester,
  ) async {
    final env = await _waitingPhone(tester);
    env.server.deviceGlitches.add(const NoConnection());
    await pumpApp(tester, env, language: 'bn');
    final l = wordsFor('bn');
    expect(await reveal(tester, find.text(l.deviceCheckOffline)), findsOne);
    expect(
      await reveal(tester, find.text(_groups(_codeOf(env), 'bn')[0])),
      findsWidgets,
    );
    await endTest(tester, env);
  });

  matrix('an ended session: sign in again', (tester, language, scale, l) async {
    final env = await _waitingPhone(tester);
    env.server.endSessionsOf(fakeEmail);
    await pumpApp(tester, env, language: language, textScale: scale);
    expect(
      await reveal(tester, find.text(l.problem_sessionEnded)),
      findsOneWidget,
    );
    await _tap(tester, _button(l.actionSignInAgain));
    await _signIn(tester, l);
    // The new session is this phone's; it still waits, with the same numbers.
    expect(find.text(l.deviceWaitingTitle), findsOneWidget);
    expect(_anywhere(l.problem_sessionEnded), findsNothing);
    expect(env.server.devices, hasLength(1));
    expect(
      await reveal(tester, find.text(_groups(_codeOf(env), language)[0])),
      findsWidgets,
    );
    await endTest(tester, env);
  }, scales: const <double>[1.0]);

  testWidgets('a one-time password: the phone enrols first, the new password '
      'is chosen from the waiting phone, then it waits', (tester) async {
    final env = TestEnv(xform: householdVisitXForm);
    env.server.approveDevicesAtOnce = false;
    await tester.runAsync(() => env.seedSignedIn(signedIn: false));
    env.server.giveOneTimePassword(fakeEmail, _oneTime);
    await pumpApp(tester, env, language: 'en');
    final l = wordsFor('en');

    await _signIn(tester, l, password: _oneTime);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    // Enrolled before anything else, and waiting.
    expect(env.phoneDevice!.status, 'pending');
    expect(env.server.mustChangePassword(fakeEmail), isTrue);

    for (final key in <String>['new-password-field', 'repeat-password-field']) {
      await tester.enterText(await reveal(tester, find.byKey(Key(key))), _own);
    }
    await _tap(tester, _button(l.passwordChangeSave));
    expect(env.server.mustChangePassword(fakeEmail), isFalse);
    expect(env.server.passwordOf(fakeEmail), _own);
    // The same phone, still waiting: nothing but its status was asked.
    expect(find.text(l.deviceWaitingTitle), findsOneWidget);
    expect(env.server.devices, hasLength(1));
    expect(env.server.log.where((r) => r.contains('form_versions')), isEmpty);

    env.server.approveDevice(env.phoneDevice!.id, _codeOf(env));
    await _tap(tester, _button(l.deviceCheckAgain));
    expect(find.text(l.todayTitle), findsWidgets);
    await endTest(tester, env);
  });

  testWidgets('not set up yet (the enrolment did not go through): the '
      'screen sets the phone up, and says why when it cannot', (tester) async {
    final env = TestEnv(xform: householdVisitXForm);
    await tester.runAsync(env.seedSignedIn);
    // The phone forgot its enrolment (its keys stay).
    env.deviceStore.enrolmentText = null;
    env.server.deviceGlitches.add(const NoConnection());
    await pumpApp(tester, env, language: 'en');
    final l = wordsFor('en');
    expect(find.text(l.deviceSettingUpTitle), findsOneWidget);
    expect(await reveal(tester, find.text(l.deviceCheckOffline)), findsOne);
    await _tap(tester, _button(l.actionTryAgain));
    // The same keys: the same device, approved earlier.
    expect(find.text(l.todayTitle), findsWidgets);
    expect(env.server.devices, hasLength(1));
    await endTest(tester, env);
  });

  testWidgets('switched off while forms wait to be sent: they stay queued, '
      'and the switched-off screen takes over', (tester) async {
    final env = TestEnv(xform: householdVisitXForm);
    await tester.runAsync(() async {
      await env.seedSignedIn();
      await env.storeForm(householdVisitXForm);
    });
    await pumpApp(tester, env, language: 'en');
    final l = wordsFor('en');
    expect(find.text(l.todayTitle), findsWidgets);

    await tester.runAsync(() => OutboxRepository(env.db).enqueue(_waiting));
    env.server.revokeDevice(env.phoneDevice!.id);
    // A send, as when the signal returns (run where the app runs, so the
    // test's clock drives it).
    final engine = await tester.runAsync(
      () => containerOf(tester).read(syncEngineProvider.future),
    );
    unawaited(engine!.syncNow(ignoreBackoff: true));
    await settleApp(tester);

    expect(find.text(l.deviceSwitchedOffTitle), findsOneWidget);
    final entry = await tester.runAsync(
      () => OutboxRepository(env.db).find(_waiting.instanceId),
    );
    expect(entry!.state, OutboxState.queued);
    expect(entry.attempts, 0);
    expect(entry.lastError, ProblemCode.deviceRevoked.name);
    expect(env.server.submissions, isEmpty);
    await endTest(tester, env);
  });

  matrix('Settings shows this phone\'s approval and numbers', (
    tester,
    language,
    scale,
    l,
  ) async {
    final env = TestEnv(xform: householdVisitXForm);
    await tester.runAsync(env.seedSignedIn);
    await pumpScreen(
      tester,
      env,
      const SettingsScreen(),
      language: language,
      textScale: scale,
    );
    expect(await reveal(tester, find.text(l.settingsThisPhone)), findsOne);
    final expires = env.phoneDevice!.expires!.toLocal();
    expect(
      await reveal(
        tester,
        find.text(
          l.deviceStatusApproved(shortDate(expires, bangla: language == 'bn')),
        ),
      ),
      findsOneWidget,
    );
    expect(
      await reveal(tester, find.text(_groups(_codeOf(env), language).last)),
      findsWidgets,
    );
    await expectAccessibleTargets(tester);
    await endTest(tester, env);
  }, scales: const <double>[1.0, 2.0]);
}
