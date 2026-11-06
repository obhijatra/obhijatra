// The screens shown after sign-in until this computer or browser is
// approved (docs/decisions/0008-device-trust.md), in English and Bangla.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';
import 'package:obhijatra_manager/src/state/devices.dart';
import 'package:obhijatra_manager/src/ui/choose_password_screen.dart';
import 'package:obhijatra_manager/src/ui/device_screens.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/src/ui/shell.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';

import 'support/fake_api.dart';
import 'support/fake_device.dart';
import 'support/harness.dart';

const String thisDevice = 'thisdevice00001';

DeviceView waiting({bool second = false}) => DeviceView(
  id: thisDevice,
  status: DeviceStatus.pending,
  label: 'Windows computer',
  platform: DevicePlatform.windows,
  needsSecondApproval: second,
);

DeviceView approved({bool ranOut = false}) => DeviceView(
  id: thisDevice,
  status: DeviceStatus.active,
  label: 'Windows computer',
  platform: DevicePlatform.windows,
  expires: DateTime(2027, 11, 6),
  approvalExpired: ranOut,
);

/// A store that already holds keys number [keys] for the person `u1`,
/// enrolled as [thisDevice].
MemoryIdentityStore enrolledStore({int keys = 0}) => MemoryIdentityStore()
  ..identities['u1'] = DeviceIdentity(
    keys: FakeDeviceKeys(keys),
    deviceId: thisDevice,
  )
  ..last = 'u1';

/// The six groups of the test vector's code, as shown in [lang].
List<String> shownGroups(String lang) => lang == 'bn'
    ? vectorCodeBangla.split(' ')
    : <String>['225', '142', '753', '699', '752', '889'];

Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> signInWith(
  WidgetTester tester,
  AppLocalizations l10n,
  String email,
  String password,
) async {
  final fields = find.byType(TextFormField);
  final count = fields.evaluate().length;
  if (count == 3) {
    await tester.enterText(fields.at(0), 'https://data.example.org');
  }
  await tester.enterText(fields.at(count - 2), email);
  await tester.enterText(fields.at(count - 1), password);
  await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
  await tester.pumpAndSettle();
}

/// Moves the app to [target] one step at a time, as the platform does
/// (resumed, inactive, hidden and back).
void moveTo(WidgetTester tester, AppLifecycleState target) {
  const order = <AppLifecycleState>[
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
  ];
  var at = order.indexOf(
    tester.binding.lifecycleState ?? AppLifecycleState.resumed,
  );
  final to = order.indexOf(target);
  while (at != to) {
    at += to > at ? 1 : -1;
    tester.binding.handleAppLifecycleStateChanged(order[at]);
  }
}

Finder fieldIn(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(EditableText),
);

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Device check ($lang)', () {
      testWidgets('a new computer is enrolled with its own keys and waits, '
          'showing its 18 numbers in six groups of three', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final semantics = tester.ensureSemantics();
        final api = FakeManagerApi(user: staff('supervisor'))
          ..enrolAnswer = waiting();
        final store = MemoryIdentityStore();
        await pumpManager(tester, api, lang: lang, store: store);
        final l10n = l10nOf(tester);

        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        expect(find.byType(ManagerShell), findsNothing);
        expect(find.text(l10n.deviceWaitingTitle), findsOneWidget);
        expect(find.text(l10n.deviceWaitingIntro), findsOneWidget);
        // Enrolled once, with a plain name and the platform.
        expect(api.enrolments, hasLength(1));
        expect(api.enrolments.single.platform, DevicePlatform.windows);
        expect(api.enrolments.single.label, 'Windows computer');
        expect(api.enrolments.single.code, vectorCode);
        expect(store.identities['u1']!.deviceId, thisDevice);
        expect(store.last, 'u1');

        // Large, six groups of three, in the language's digits.
        for (final group in shownGroups(lang)) {
          expect(find.text(group), findsOneWidget);
        }
        final groupStyle = tester.widget<Text>(find.text(shownGroups(lang)[0]));
        expect(groupStyle.style!.fontSize, greaterThanOrEqualTo(24));
        // Read out digit by digit.
        final spoken = shownGroups(lang)
            .map((group) => group.split('').join(' '))
            .join(', ');
        expect(
          find.bySemanticsLabel('${l10n.deviceCodeLabel}: $spoken'),
          findsOneWidget,
        );

        // Who approves, and how: in person or by phone, never by message.
        expect(find.text(l10n.deviceWhoStaff), findsOneWidget);
        expect(find.text(l10n.deviceNoMessages), findsOneWidget);
        expect(find.text(l10n.deviceWhoAdmin), findsNothing);
        expect(find.byKey(const ValueKey('device-command')), findsNothing);
        expect(
          find.text(l10n.deviceThisDevice('Windows computer')),
          findsOneWidget,
        );
        expect(find.text(l10n.menuSignOut), findsOneWidget);
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('checks every 15 seconds and opens the app once approved', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meAnswer = waiting();
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        final l10n = l10nOf(tester);
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        expect(api.enrolments, isEmpty, reason: 'already enrolled');
        expect(api.meChecks, 1);

        await tester.pump(const Duration(seconds: 14));
        expect(api.meChecks, 1);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(api.meChecks, 2);
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        // The automatic check does not make the button flicker.
        expect(find.text(l10n.deviceCheckAgain), findsOneWidget);

        api.meAnswer = approved();
        await tester.pump(devicePollEvery);
        await tester.pumpAndSettle();
        expect(api.meChecks, 3);
        expect(find.byType(DeviceWaitingScreen), findsNothing);
        expect(find.byType(ManagerShell), findsOneWidget);

        // No checking once the app is open.
        await tester.pump(devicePollEvery * 3);
        expect(api.meChecks, 3);
      });

      testWidgets('stops checking while the window is hidden, and checks at '
          'once when it is shown again', (tester) async {
        addTearDown(() => moveTo(tester, AppLifecycleState.resumed));
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meAnswer = waiting();
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        expect(api.meChecks, 1);

        // Behind another window but visible: still checking.
        moveTo(tester, AppLifecycleState.inactive);
        await tester.pump(devicePollEvery);
        await tester.pumpAndSettle();
        expect(api.meChecks, 2);

        // Minimised, or another browser tab in front: no checks at all.
        moveTo(tester, AppLifecycleState.hidden);
        await tester.pump(devicePollEvery * 4);
        await tester.pumpAndSettle();
        expect(api.meChecks, 2);

        moveTo(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(api.meChecks, 3, reason: 'checked at once');
        await tester.pump(devicePollEvery);
        await tester.pumpAndSettle();
        expect(api.meChecks, 4);
      });

      testWidgets('"Check again" asks at once and says when it last checked', (
        tester,
      ) async {
        final checkedAt = DateTime(2026, 11, 6, 14, 32);
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meAnswer = waiting();
        await pumpManager(
          tester,
          api,
          lang: lang,
          store: enrolledStore(),
          overrides: [deviceClockProvider.overrideWithValue(() => checkedAt)],
        );
        final l10n = l10nOf(tester);
        final lastChecked = find.byKey(const ValueKey('device-last-checked'));
        final time = Format.clock(tester.element(lastChecked), checkedAt);
        expect(
          tester.widget<Text>(lastChecked).data,
          '${l10n.deviceAutoCheck} ${l10n.deviceLastChecked(time)}',
        );

        final gate = api.meGate = Completer<void>();
        await tester.tap(find.byKey(const ValueKey('device-check-again')));
        await tester.pump();
        expect(api.meChecks, 2);
        expect(find.text(l10n.deviceCheckingNow), findsOneWidget);
        // Pressing again while it runs sends nothing more.
        await tester.tap(find.byKey(const ValueKey('device-check-again')));
        await tester.pump();
        expect(api.meChecks, 2);

        api.meGate = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text(l10n.deviceCheckAgain), findsOneWidget);
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
      });

      testWidgets('an organisation admin needs two other organisation admins, '
          'or the server for the very first admin', (tester) async {
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final api = FakeManagerApi(user: staff('org_admin'))
          ..enrolAnswer = waiting();
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.deviceWhoAdmin), findsOneWidget);
        expect(find.text(l10n.deviceWhoStaff), findsNothing);
        expect(find.text(l10n.deviceWhoAdminSecond), findsNothing);
        expect(find.text(l10n.deviceFirstAdminTitle), findsOneWidget);

        // The server command is in English digits, also in Bangla.
        const command =
            'obhijatra-server device approve thisdevice00001 '
            '"225 142 753 699 752 889"';
        expect(find.text(command), findsOneWidget);
        await tapAndSettle(tester, find.byTooltip(l10n.actionCopy));
        expect(copied, <String>[command]);
        expect(find.text(l10n.deviceCommandCopied), findsOneWidget);

        // After the first admin's approval, the screen says one more.
        api.meAnswer = waiting(second: true);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('device-check-again')),
        );
        expect(find.text(l10n.deviceWhoAdminSecond), findsOneWidget);
        // Other admins exist now: the first admin's command is not needed.
        expect(find.text(command), findsNothing);
        expect(find.text(l10n.deviceFirstAdminTitle), findsNothing);
      });

      testWidgets('an approval that ran out shows the same numbers again', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meAnswer = approved(ranOut: true);
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        final l10n = l10nOf(tester);
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        expect(find.text(l10n.deviceRenewTitle), findsOneWidget);
        expect(find.text(l10n.deviceRenewIntro), findsOneWidget);
        for (final group in shownGroups(lang)) {
          expect(find.text(group), findsOneWidget);
        }
        expect(api.enrolments, isEmpty);
      });

      testWidgets('a switched-off device is set up again with new keys, then '
          'waits', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meFailure = const AppProblem(
            ProblemKind.deviceRevoked,
            statusCode: 403,
          )
          ..enrolAnswer = waiting();
        final store = enrolledStore(keys: 5);
        await pumpManager(tester, api, lang: lang, store: store);
        final l10n = l10nOf(tester);
        expect(find.byType(DeviceRevokedScreen), findsOneWidget);
        expect(find.text(l10n.deviceRevokedBody), findsOneWidget);

        // Asked first; cancelling changes nothing.
        await tapAndSettle(tester, find.text(l10n.deviceSetUpAgain));
        expect(find.text(l10n.deviceSetUpAgainBody), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.actionCancel));
        expect(store.wiped, isEmpty);

        await tapAndSettle(tester, find.text(l10n.deviceSetUpAgain));
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('device-set-up-again-confirm')),
        );
        expect(store.wiped, <String>['u1']);
        expect(api.enrolments, hasLength(1));
        expect(api.enrolments.single.code, vectorCode, reason: 'new keys');
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        for (final group in shownGroups(lang)) {
          expect(find.text(group), findsOneWidget);
        }
      });

      testWidgets('setting up again after the session ended asks to sign in '
          'again', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meFailure = const AppProblem(
            ProblemKind.deviceRevoked,
            statusCode: 403,
          )
          ..enrolFailure = const AppProblem(
            ProblemKind.signInRequired,
            statusCode: 401,
          );
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        final l10n = l10nOf(tester);
        await tapAndSettle(tester, find.text(l10n.deviceSetUpAgain));
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('device-set-up-again-confirm')),
        );
        expect(find.byType(DeviceRevokedScreen), findsOneWidget);
        expect(find.text(l10n.problemSignInRequired), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.actionSignInAgain).first);
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(api.signOuts, 1);
      });

      testWidgets('a device switched off while in use shows at once', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meAnswer = approved();
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        final l10n = l10nOf(tester);
        expect(find.byType(ManagerShell), findsOneWidget);

        const revoked = AppProblem(ProblemKind.deviceRevoked, statusCode: 403);
        api
          ..failWith = revoked
          ..meFailure = revoked;
        await tapAndSettle(
          tester,
          find.bySemanticsLabel(l10n.navSubmissions).first,
        );
        expect(find.byType(DeviceRevokedScreen), findsOneWidget);
        expect(find.byType(ManagerShell), findsNothing);
      });

      testWidgets('a device the server no longer knows is enrolled again '
          'with the same keys, and waits with a word on why', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..deviceUnknown = true
          ..enrolAnswer = waiting();
        // Enrolled before, under an id the restored server never had.
        final store = MemoryIdentityStore()
          ..identities['u1'] = DeviceIdentity(
            keys: FakeDeviceKeys(),
            deviceId: 'olddevice000001',
          )
          ..last = 'u1';
        await pumpManager(tester, api, lang: lang, store: store);
        final l10n = l10nOf(tester);

        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        expect(find.text(l10n.deviceServerForgot), findsOneWidget);
        // Asked once, not retried; the id forgotten, the keys kept.
        expect(api.meChecks, 1);
        expect(store.forgotten, <String>['u1']);
        expect(store.wiped, isEmpty);
        expect(store.created, 0, reason: 'no new keys');
        expect(api.enrolments, hasLength(1));
        expect(api.enrolments.single.code, vectorCode, reason: 'same keys');
        expect(store.identities['u1']!.deviceId, thisDevice);
        // The same numbers as before, for the approver.
        for (final group in shownGroups(lang)) {
          expect(find.text(group), findsOneWidget);
        }

        // Later checks ask about the new device; the note stays.
        await tester.pump(devicePollEvery);
        await tester.pumpAndSettle();
        expect(api.meChecks, 2);
        expect(api.enrolments, hasLength(1), reason: 'enrolled once');
        expect(find.text(l10n.deviceServerForgot), findsOneWidget);

        api.meAnswer = approved();
        await tester.pump(devicePollEvery);
        await tester.pumpAndSettle();
        expect(find.byType(ManagerShell), findsOneWidget);
      });

      testWidgets('while in use: a request refused as an unknown device '
          'enrols it again and shows the waiting screen', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meAnswer = approved();
        final store = enrolledStore();
        await pumpManager(tester, api, lang: lang, store: store);
        final l10n = l10nOf(tester);
        expect(find.byType(ManagerShell), findsOneWidget);

        api
          ..failWith = const AppProblem(
            ProblemKind.deviceUnknown,
            statusCode: 403,
          )
          ..deviceUnknown = true
          ..meAnswer = null
          ..enrolAnswer = waiting();
        await tapAndSettle(
          tester,
          find.bySemanticsLabel(l10n.navSubmissions).first,
        );
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        expect(find.text(l10n.deviceServerForgot), findsOneWidget);
        expect(store.forgotten, <String>['u1']);
        expect(store.created, 0);
        expect(api.enrolments.single.code, vectorCode);
      });

      testWidgets('an ordinary wait has no such note', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meAnswer = waiting();
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('device-server-forgot')),
          findsNothing,
        );
      });

      testWidgets('a wrong clock: set the date and time, then check again', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meFailure = const AppProblem(
            ProblemKind.deviceClock,
            statusCode: 403,
          );
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        final l10n = l10nOf(tester);
        expect(find.byType(DeviceClockScreen), findsOneWidget);
        expect(find.text(l10n.deviceClockTitle), findsOneWidget);
        expect(find.text(l10n.deviceClockBody), findsOneWidget);

        api
          ..meFailure = null
          ..meAnswer = approved();
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('device-check-again')),
        );
        expect(find.byType(ManagerShell), findsOneWidget);
      });

      testWidgets('keys the server does not know: check again, or set up '
          'again', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meFailure = const AppProblem(
            ProblemKind.deviceCheckFailed,
            statusCode: 403,
          )
          ..enrolAnswer = waiting();
        final store = enrolledStore(keys: 3);
        await pumpManager(tester, api, lang: lang, store: store);
        final l10n = l10nOf(tester);
        expect(find.byType(DeviceNotRecognisedScreen), findsOneWidget);
        expect(find.text(l10n.deviceCheckAgain), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.deviceSetUpAgain));
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('device-set-up-again-confirm')),
        );
        expect(store.wiped, <String>['u1']);
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
      });

      for (final (kind, message)
          in <(ProblemKind, String Function(AppLocalizations))>[
            (ProblemKind.signInRequired, (l10n) => l10n.problemSignInRequired),
            (
              ProblemKind.sessionOtherDevice,
              (l10n) => l10n.problemSessionOtherDevice,
            ),
          ]) {
        testWidgets('${kind.name}: sign in again', (tester) async {
          final api = FakeManagerApi(user: staff('supervisor'))
            ..enrolFailure = AppProblem(kind, statusCode: 401);
          await pumpManager(tester, api, lang: lang);
          final l10n = l10nOf(tester);
          expect(find.byType(DeviceProblemScreen), findsOneWidget);
          expect(find.text(message(l10n)), findsOneWidget);
          await tapAndSettle(tester, find.text(l10n.actionSignInAgain));
          expect(find.byType(SignInScreen), findsOneWidget);
          expect(api.signOuts, 1);
        });
      }

      testWidgets('offline during the check: try again, with no dead end', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..meFailure = const AppProblem(ProblemKind.offline);
        await pumpManager(tester, api, lang: lang, store: enrolledStore());
        final l10n = l10nOf(tester);
        expect(find.byType(DeviceProblemScreen), findsOneWidget);
        expect(find.text(l10n.menuSignOut), findsOneWidget);
        api
          ..meFailure = null
          ..meAnswer = approved();
        await tapAndSettle(tester, find.text(l10n.actionTryAgain));
        expect(find.byType(ManagerShell), findsOneWidget);
      });

      testWidgets('a one-time password: the device is enrolled first, then '
          'the person chooses a password, then waits', (tester) async {
        final api = FakeManagerApi()
          ..signInMustChange = true
          ..signInRole = 'supervisor'
          ..enrolAnswer = waiting();
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, l10n, 'shila@example.org', 'kfmw-tqzp-hrvx');
        expect(api.enrolments, hasLength(1));
        expect(find.byType(ChoosePasswordScreen), findsOneWidget);
        expect(find.byType(DeviceWaitingScreen), findsNothing);

        await tester.enterText(fieldIn('new-password'), 'three green mangoes');
        await tester.enterText(
          fieldIn('repeat-password'),
          'three green mangoes',
        );
        await tapAndSettle(
          tester,
          find.widgetWithText(FilledButton, l10n.choosePasswordSave),
        );
        expect(api.passwordChanges, hasLength(1));
        expect(find.byType(ChoosePasswordScreen), findsNothing);
        expect(find.byType(DeviceWaitingScreen), findsOneWidget);
        expect(api.enrolments, hasLength(1), reason: 'not enrolled twice');
      });

      for (final (support, title)
          in <(KeyStoreSupport, String Function(AppLocalizations))>[
            (
              KeyStoreSupport.updateBrowser,
              (l10n) => l10n.deviceUpdateBrowserTitle,
            ),
            (
              KeyStoreSupport.secureAddressNeeded,
              (l10n) => l10n.deviceSecureAddressTitle,
            ),
          ]) {
        testWidgets('${support.name}: no keys are made, and no weaker way is '
            'offered', (tester) async {
          final api = FakeManagerApi(user: staff('supervisor'));
          final store = MemoryIdentityStore()..supportAnswer = support;
          await pumpManager(tester, api, lang: lang, store: store);
          final l10n = l10nOf(tester);
          expect(find.byType(DeviceUnsupportedScreen), findsOneWidget);
          expect(find.text(title(l10n)), findsOneWidget);
          expect(store.created, 0);
          expect(api.enrolments, isEmpty);
          expect(find.byType(ManagerShell), findsNothing);
          await tapAndSettle(tester, find.text(l10n.menuSignOut));
          expect(find.byType(SignInScreen), findsOneWidget);
        });
      }

      for (final size in <Size>[const Size(1280, 900), const Size(400, 800)]) {
        testWidgets('the waiting screen fits large text at '
            '${size.width.toInt()} wide', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final api = FakeManagerApi(user: staff('org_admin'))
            ..meAnswer = waiting(second: true);
          await pumpManager(
            tester,
            api,
            lang: lang,
            size: size,
            store: enrolledStore(),
          );
          final l10n = l10nOf(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(DeviceWaitingScreen), findsOneWidget);
          for (final group in shownGroups(lang)) {
            expect(find.text(group), findsOneWidget);
          }
          // Every button can be reached and is at least 48 high.
          for (final label in <String>[
            l10n.deviceCheckAgain,
            l10n.menuSignOut,
          ]) {
            final button = find.text(label);
            await tester.ensureVisible(button);
            expect(tester.getSize(button).height, greaterThan(0));
          }
          final check = find.byKey(const ValueKey('device-check-again'));
          expect(tester.getSize(check).height, greaterThanOrEqualTo(48));
        });
      }
    });
  }
}
