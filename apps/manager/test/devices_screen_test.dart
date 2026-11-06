// Devices: approving and switching off devices, and "My devices"
// (docs/decisions/0008-device-trust.md), in English and Bangla.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/devices.dart';
import 'package:obhijatra_manager/src/ui/device_screens.dart';
import 'package:obhijatra_manager/src/ui/devices_screen.dart';
import 'package:obhijatra_manager/src/ui/format.dart';

import 'support/fake_api.dart';
import 'support/fake_device.dart';
import 'support/harness.dart';

/// "Now" for every test: 6 November 2026, 10:00.
final DateTime now = DateTime(2026, 11, 6, 10);

/// The device this app runs on (the fake's enrolment answer).
const String thisDevice = 'thisdevice00001';

/// What an organisation admin sees: a new field phone, a staff browser
/// whose approval ran out, an approved phone, an admin's laptop with one
/// approval, a switched-off phone, and their own approved browser.
List<DeviceRecord> adminDevices() => <DeviceRecord>[
  deviceRecord(id: 'd1', created: DateTime(2026, 11, 5, 9)),
  deviceRecord(
    id: 'd2',
    ownerId: 'u5',
    ownerName: 'Karim Hossain',
    ownerContact: 'karim@example.org',
    kind: PersonKind.staff,
    role: 'supervisor',
    label: 'Web browser (Firefox on Windows)',
    platform: DevicePlatform.web,
    status: DeviceStatus.active,
    expires: DateTime(2026, 11, 1),
    keys: 1,
  ),
  deviceRecord(
    id: 'd3',
    ownerId: 'f3',
    ownerName: 'Shirin Akter',
    status: DeviceStatus.active,
    expires: DateTime(2027, 5, 1),
    keys: 2,
  ),
  deviceRecord(
    id: 'd4',
    ownerId: 'u7',
    ownerName: 'Nasima Begum',
    ownerContact: 'nasima@example.org',
    kind: PersonKind.staff,
    role: orgAdminRole,
    label: 'Mac',
    platform: DevicePlatform.macos,
    firstApprovedBy: 'u8',
    keys: 3,
  ),
  deviceRecord(
    id: 'd5',
    ownerId: 'f5',
    ownerName: 'Jamal Uddin',
    status: DeviceStatus.revoked,
    keys: 4,
  ),
  deviceRecord(
    id: thisDevice,
    ownerId: 'u1',
    ownerName: 'Tania Rahman',
    kind: PersonKind.staff,
    role: orgAdminRole,
    label: 'Web browser (Chrome on Windows)',
    platform: DevicePlatform.web,
    status: DeviceStatus.active,
    expires: DateTime(2027, 11, 6),
    keys: 6,
  ),
];

Future<void> openDevices(
  WidgetTester tester,
  FakeManagerApi api, {
  String lang = 'en',
  Size size = const Size(1280, 900),
}) async {
  await pumpManager(
    tester,
    api,
    lang: lang,
    size: size,
    overrides: [deviceClockProvider.overrideWithValue(() => now)],
  );
  final l10n = l10nOf(tester);
  final label = api.user!.canApproveDevices
      ? l10n.navDevices
      : l10n.navMyDevices;
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
  expect(find.byType(DevicesScreen), findsOneWidget);
}

Finder row(String id) => find.byKey(ValueKey<String>('device-$id'));

Finder inRow(String id, Finder finder) =>
    find.descendant(of: row(id), matching: finder);

Finder approveButton(String id) => find.byKey(ValueKey<String>('approve-$id'));

Finder switchOffButton(String id) =>
    find.byKey(ValueKey<String>('switch-off-$id'));

/// Scrolls the list of devices until [target] is built (rows further down
/// are built only when they come near the screen).
Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
  await reveal(tester, target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// The date [day] as the screen writes it.
String dayText(WidgetTester tester, DateTime day) =>
    Format.day(tester.element(find.byType(DevicesScreen)), day);

Future<void> typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const ValueKey('approve-code')), code);
  // An error message fades out over a few frames.
  await tester.pumpAndSettle();
}

/// [finder] inside the open dialog.
Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Future<void> confirmApprove(WidgetTester tester) =>
    tapAndSettle(tester, find.byKey(const ValueKey('approve-confirm')));

/// Whether [above] is drawn higher on screen than [below].
bool isAbove(WidgetTester tester, Finder above, Finder below) =>
    tester.getTopLeft(above).dy < tester.getTopLeft(below).dy;

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Devices ($lang)', () {
      testWidgets('waiting (new, and approvals that ran out), approved and '
          'switched off, with the person, the device and its dates', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff(orgAdminRole))
          ..devices = adminDevices();
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.devicesSummaryAdmin), findsOneWidget);

        // Each heading comes before the badges that use the same words.
        final waiting = find.text(l10n.devicesWaiting).first;
        final approved = find.text(l10n.devicesApproved).first;
        final off = find.text(l10n.devicesSwitchedOff).first;
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(l10n.devicesWaiting))),
          findsWidgets,
        );
        expect(isAbove(tester, waiting, approved), isTrue);
        for (final id in <String>['d1', 'd2', 'd4']) {
          expect(isAbove(tester, row(id), approved), isTrue, reason: id);
        }
        expect(isAbove(tester, approved, row('d3')), isTrue);
        // Your own devices are under My devices, not here.
        expect(row(thisDevice), findsNothing);

        // The person, how to reach them, the device and when it came.
        expect(inRow('d1', find.text('Rokeya Akter')), findsOneWidget);
        expect(inRow('d1', find.text('+8801700000001')), findsOneWidget);
        // The name is not repeated when it is the platform's own.
        expect(
          inRow(
            'd1',
            find.text(
              lang == 'en'
                  ? 'Android phone'
                  : 'Android phone · ${l10n.platformAndroid}',
            ),
          ),
          findsOneWidget,
        );
        expect(
          inRow(
            'd2',
            find.text('Web browser (Firefox on Windows) · ${l10n.platformWeb}'),
          ),
          findsOneWidget,
        );
        expect(
          inRow(
            'd1',
            find.textContaining(
              l10n.deviceAdded(dayText(tester, DateTime(2026, 11, 5))),
            ),
          ),
          findsOneWidget,
        );
        expect(
          inRow('d1', find.text(l10n.deviceStatusWaiting)),
          findsOneWidget,
        );
        expect(inRow('d2', find.text('karim@example.org')), findsOneWidget);
        expect(inRow('d2', find.text(l10n.deviceStatusRanOut)), findsOneWidget);
        expect(
          inRow(
            'd2',
            find.textContaining(
              l10n.deviceApprovalRanOut(dayText(tester, DateTime(2026, 11))),
            ),
          ),
          findsOneWidget,
        );
        expect(inRow('d4', find.text(l10n.deviceNeedsSecond)), findsOneWidget);
        expect(
          inRow(
            'd3',
            find.textContaining(
              l10n.deviceApprovedUntil(dayText(tester, DateTime(2027, 5))),
            ),
          ),
          findsOneWidget,
        );

        // Approve only what waits; switch off anything not already off.
        for (final id in <String>['d1', 'd2', 'd4']) {
          expect(approveButton(id), findsOneWidget, reason: id);
        }
        expect(approveButton('d3'), findsNothing);
        for (final id in <String>['d1', 'd2', 'd3', 'd4']) {
          expect(switchOffButton(id), findsOneWidget, reason: id);
        }

        // Switched off comes last, and has nothing more to do.
        await reveal(tester, row('d5'));
        expect(isAbove(tester, off, row('d5')), isTrue);
        expect(inRow('d5', find.text(l10n.deviceStatusOff)), findsOneWidget);
        expect(approveButton('d5'), findsNothing);
        expect(switchOffButton('d5'), findsNothing);
      });

      testWidgets('approving: the numbers are checked here first, and a '
          'mismatch sends nothing', (tester) async {
        final api = FakeManagerApi(user: staff(orgAdminRole))
          ..devices = adminDevices();
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await tapAndSettle(tester, approveButton('d1'));
        expect(find.text(l10n.approveTitle('Rokeya Akter')), findsOneWidget);
        expect(find.text(l10n.approveHow('Rokeya Akter')), findsOneWidget);
        expect(find.text(l10n.approveCodeHelp), findsOneWidget);

        // Only digits are kept, in groups of three, 18 at most.
        await typeCode(tester, '225-142x753 6997527');
        expect(find.text('225 142 753 699 752 7'), findsOneWidget);

        await typeCode(tester, '225 142 753');
        await confirmApprove(tester);
        expect(find.text(l10n.approveCodeIncomplete), findsOneWidget);

        await typeCode(tester, '225 142 753 699 752 888');
        await confirmApprove(tester);
        expect(find.text(l10n.approveMismatch('Rokeya Akter')), findsOneWidget);
        expect(api.approvals, isEmpty, reason: 'nothing sent on a mismatch');

        // Typing clears the message; Bangla digits work; Enter approves.
        await typeCode(tester, vectorCodeBangla);
        expect(find.text(l10n.approveMismatch('Rokeya Akter')), findsNothing);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(api.approvals, <(String, String)>[('d1', vectorCodeBangla)]);

        // The outcome, in words.
        expect(find.byKey(const ValueKey('approve-result')), findsOneWidget);
        expect(
          find.text(
            l10n.approveDoneUntil(dayText(tester, DateTime(2027, 11, 6))),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.approveDone('Rokeya Akter')), findsOneWidget);
        await tapAndSettle(tester, find.byKey(const ValueKey('approve-done')));
        expect(find.byKey(const ValueKey('approve-result')), findsNothing);
        // The list has it as approved already.
        expect(approveButton('d1'), findsNothing);
        expect(
          inRow('d1', find.text(l10n.deviceStatusApproved)),
          findsOneWidget,
        );
      });

      testWidgets('the server checks the numbers again; its refusal reads the '
          'same', (tester) async {
        final api = FakeManagerApi(user: staff(orgAdminRole))
          ..devices = adminDevices()
          ..approveFailure = const AppProblem(
            ProblemKind.deviceCodeMismatch,
            statusCode: 400,
          );
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await tapAndSettle(tester, approveButton('d1'));
        await typeCode(tester, vectorCode);
        await confirmApprove(tester);
        expect(find.text(l10n.approveMismatch('Rokeya Akter')), findsOneWidget);
        expect(find.byKey(const ValueKey('approve-result')), findsNothing);

        // Any other problem shows with a way on.
        api.approveFailure = const AppProblem(ProblemKind.offline);
        await confirmApprove(tester);
        expect(inDialog(find.text(l10n.actionTryAgain)), findsOneWidget);
        await tapAndSettle(tester, inDialog(find.text(l10n.actionTryAgain)));
        expect(find.byKey(const ValueKey('approve-result')), findsOneWidget);
      });

      testWidgets('an organisation admin’s device needs two different '
          'organisation admins', (tester) async {
        final api = FakeManagerApi(user: staff(orgAdminRole))
          ..devices = <DeviceRecord>[
            ...adminDevices(),
            deviceRecord(
              id: 'd7',
              ownerId: 'u9',
              ownerName: 'Farhana Islam',
              kind: PersonKind.staff,
              role: orgAdminRole,
              label: 'Windows computer',
              platform: DevicePlatform.windows,
              keys: 7,
            ),
          ];
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);

        // The first approval: one more admin is needed.
        await tapAndSettle(tester, approveButton('d7'));
        expect(find.text(l10n.approveAdminDevice), findsOneWidget);
        await typeCode(tester, fakeCode(7));
        await confirmApprove(tester);
        expect(find.text(l10n.approveDoneFirstTitle), findsOneWidget);
        expect(
          find.text(l10n.approveDoneFirst('Farhana Islam')),
          findsOneWidget,
        );
        await tapAndSettle(tester, find.byKey(const ValueKey('approve-done')));
        expect(inRow('d7', find.text(l10n.deviceNeedsSecond)), findsOneWidget);
        expect(
          inRow('d7', find.text(l10n.deviceYouApprovedFirst)),
          findsOneWidget,
        );
        expect(approveButton('d7'), findsNothing, reason: 'not twice');

        // The second, by a different admin: approved.
        await tapAndSettle(tester, approveButton('d4'));
        expect(find.text(l10n.approveAdminSecond), findsOneWidget);
        await typeCode(tester, fakeCode(3));
        await confirmApprove(tester);
        expect(
          find.text(
            l10n.approveDoneUntil(dayText(tester, DateTime(2027, 11, 6))),
          ),
          findsOneWidget,
        );
      });

      testWidgets('branch managers approve field staff phones only, and '
          'never their own device', (tester) async {
        final api = FakeManagerApi(user: staff('branch_manager'))
          ..devices = <DeviceRecord>[
            deviceRecord(id: 'd1'),
            deviceRecord(
              id: 'd4',
              ownerId: 'u7',
              ownerName: 'Nasima Begum',
              kind: PersonKind.staff,
              role: orgAdminRole,
              label: 'Mac',
              platform: DevicePlatform.macos,
              keys: 3,
            ),
            deviceRecord(
              id: 'd8',
              ownerId: 'u5',
              ownerName: 'Karim Hossain',
              kind: PersonKind.staff,
              role: 'supervisor',
              label: 'Windows computer',
              platform: DevicePlatform.windows,
              keys: 8,
            ),
            deviceRecord(
              id: 'd9',
              ownerId: 'u1',
              ownerName: 'Tania Rahman',
              kind: PersonKind.staff,
              role: 'branch_manager',
              label: 'Web browser (Edge on Windows)',
              platform: DevicePlatform.web,
              keys: 9,
            ),
          ];
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.devicesSummaryBranch), findsOneWidget);
        expect(approveButton('d1'), findsOneWidget);
        expect(switchOffButton('d1'), findsOneWidget);
        for (final id in <String>['d4', 'd8']) {
          expect(approveButton(id), findsNothing, reason: id);
          expect(switchOffButton(id), findsNothing, reason: id);
        }
        expect(row('d9'), findsNothing);

        await tapAndSettle(tester, find.text(l10n.navMyDevices).last);
        expect(row('d9'), findsOneWidget);
        expect(approveButton('d9'), findsNothing, reason: 'own device');
        expect(switchOffButton('d9'), findsOneWidget);
        expect(row('d1'), findsNothing);
      });

      testWidgets('switching off asks first and says sessions end at once', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff(orgAdminRole))
          ..devices = adminDevices();
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);

        await tapAndSettle(tester, switchOffButton('d3'));
        expect(find.text(l10n.switchOffTitle), findsOneWidget);
        expect(
          find.text(l10n.switchOffBody('Shirin Akter', 'Android phone')),
          findsOneWidget,
        );
        await tapAndSettle(tester, find.text(l10n.actionCancel));
        expect(api.revocations, isEmpty);

        await tapAndSettle(tester, switchOffButton('d3'));
        api.revokeFailure = const AppProblem(ProblemKind.offline);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('switch-off-confirm')),
        );
        expect(api.revocations, isEmpty);
        expect(find.text(l10n.switchOffTitle), findsOneWidget);
        await tapAndSettle(tester, inDialog(find.text(l10n.actionTryAgain)));
        expect(api.revocations, <String>['d3']);
        expect(find.text(l10n.switchOffTitle), findsNothing);
        expect(find.text(l10n.switchOffDone), findsOneWidget);
        expect(inRow('d3', find.text(l10n.deviceStatusOff)), findsOneWidget);
        expect(switchOffButton('d3'), findsNothing);
      });

      testWidgets('switching off the device in use says so, then shows the '
          'switched-off screen', (tester) async {
        final api = FakeManagerApi(user: staff(orgAdminRole))
          ..devices = adminDevices();
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await tapAndSettle(tester, find.text(l10n.navMyDevices).last);
        expect(
          inRow(thisDevice, find.text(l10n.deviceThisOne)),
          findsOneWidget,
        );
        expect(approveButton(thisDevice), findsNothing);

        await tapAndSettle(tester, switchOffButton(thisDevice));
        expect(find.text(l10n.switchOffCurrent), findsOneWidget);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('switch-off-confirm')),
        );
        expect(api.revocations, <String>[thisDevice]);
        expect(find.byType(DeviceRevokedScreen), findsOneWidget);
      });

      testWidgets('people who approve no devices see their own: My devices', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'))
          ..devices = <DeviceRecord>[
            deviceRecord(
              id: thisDevice,
              ownerId: 'u1',
              ownerName: 'Tania Rahman',
              kind: PersonKind.staff,
              role: 'supervisor',
              label: 'Web browser (Chrome on Windows)',
              platform: DevicePlatform.web,
              status: DeviceStatus.active,
              expires: DateTime(2027, 11, 6),
            ),
            deviceRecord(
              id: 'd10',
              ownerId: 'u1',
              ownerName: 'Tania Rahman',
              kind: PersonKind.staff,
              role: 'supervisor',
              label: 'Mac',
              platform: DevicePlatform.macos,
              status: DeviceStatus.active,
              expires: DateTime(2027, 3, 1),
              keys: 10,
            ),
          ];
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.bySemanticsLabel(l10n.navDevices), findsNothing);
        expect(find.text(l10n.devicesSummaryMine), findsOneWidget);
        expect(find.text(l10n.devicesTabOthers), findsNothing);
        expect(row(thisDevice), findsOneWidget);
        expect(row('d10'), findsOneWidget);
        expect(approveButton('d10'), findsNothing);
        expect(switchOffButton('d10'), findsOneWidget);

        await tapAndSettle(tester, switchOffButton('d10'));
        expect(find.text(l10n.switchOffMine('Mac')), findsOneWidget);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('switch-off-confirm')),
        );
        expect(api.revocations, <String>['d10']);
        expect(find.byType(DevicesScreen), findsOneWidget);
      });

      testWidgets('a list that cannot load offers to try again', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff(orgAdminRole))
          ..devices = adminDevices()
          ..failWith = const AppProblem(ProblemKind.offline);
        await openDevices(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(row('d1'), findsNothing);
        api.failWith = null;
        await tapAndSettle(tester, find.text(l10n.actionTryAgain).first);
        expect(row('d1'), findsOneWidget);
      });

      for (final size in <Size>[const Size(1280, 900), const Size(600, 900)]) {
        testWidgets('large text fits the list and the approve dialog at '
            '${size.width.toInt()} wide', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final api = FakeManagerApi(user: staff(orgAdminRole))
            ..devices = adminDevices();
          await openDevices(tester, api, lang: lang, size: size);
          final l10n = l10nOf(tester);
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(approveButton('d1')).height,
            greaterThanOrEqualTo(48),
          );
          expect(
            tester.getSize(switchOffButton('d1')).height,
            greaterThanOrEqualTo(48),
          );
          await tapAndSettle(tester, approveButton('d4'));
          expect(tester.takeException(), isNull);
          await typeCode(tester, fakeCode(3));
          await confirmApprove(tester);
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const ValueKey('approve-done'))).height,
            greaterThanOrEqualTo(48),
          );
          await tapAndSettle(
            tester,
            find.byKey(const ValueKey('approve-done')),
          );
          await tapAndSettle(tester, switchOffButton('d3'));
          expect(tester.takeException(), isNull);
          expect(find.text(l10n.switchOffTitle), findsOneWidget);
        });
      }
    });
  }

  test('the approve button follows the rules the server applies', () {
    final admin = staff(orgAdminRole);
    final branch = staff('branch_manager');
    final field = deviceRecord(id: 'a');
    final staffDevice = deviceRecord(
      id: 'b',
      ownerId: 'u5',
      kind: PersonKind.staff,
      role: 'supervisor',
    );
    final own = deviceRecord(id: 'c', ownerId: 'u1', kind: PersonKind.staff);
    final adminFirst = deviceRecord(
      id: 'd',
      ownerId: 'u7',
      kind: PersonKind.staff,
      role: orgAdminRole,
      firstApprovedBy: 'u1',
    );
    final approved = deviceRecord(
      id: 'e',
      status: DeviceStatus.active,
      expires: DateTime(2027),
    );
    final ranOut = deviceRecord(
      id: 'f',
      status: DeviceStatus.active,
      expires: DateTime(2026, 11, 6, 9),
    );
    final off = deviceRecord(id: 'g', status: DeviceStatus.revoked);

    expect(mayApproveDevice(admin, field, now), isTrue);
    expect(mayApproveDevice(admin, staffDevice, now), isTrue);
    expect(mayApproveDevice(admin, own, now), isFalse);
    expect(mayApproveDevice(admin, adminFirst, now), isFalse);
    expect(mayApproveDevice(admin, approved, now), isFalse);
    expect(mayApproveDevice(admin, ranOut, now), isTrue);
    expect(mayApproveDevice(admin, off, now), isFalse);
    expect(mayApproveDevice(branch, field, now), isTrue);
    expect(mayApproveDevice(branch, staffDevice, now), isFalse);
    expect(mayApproveDevice(staff('supervisor'), field, now), isFalse);
    expect(
      mayApproveDevice(admin.copyWith(mustChangePassword: true), field, now),
      isFalse,
    );

    expect(maySwitchOffDevice(staff('supervisor'), own), isTrue);
    expect(maySwitchOffDevice(staff('supervisor'), field), isFalse);
    expect(maySwitchOffDevice(branch, field), isTrue);
    expect(maySwitchOffDevice(branch, staffDevice), isFalse);
    expect(maySwitchOffDevice(admin, staffDevice), isTrue);
    expect(maySwitchOffDevice(admin, off), isFalse);
  });

  test('the typed numbers are compared with the keys, never shown', () {
    final device = deviceRecord(id: 'a');
    expect(checkTypedCode(device, vectorCode), CodeCheck.match);
    expect(checkTypedCode(device, vectorCodeBangla), CodeCheck.match);
    expect(checkTypedCode(device, '225-142-753-699-752-889'), CodeCheck.match);
    expect(checkTypedCode(device, '225 142 753'), CodeCheck.incomplete);
    expect(checkTypedCode(device, '${vectorCode}0'), CodeCheck.incomplete);
    expect(
      checkTypedCode(device, '225 142 753 699 752 888'),
      CodeCheck.mismatch,
    );
    const broken = DeviceRecord(
      id: 'b',
      ownerKind: PersonKind.field,
      ownerId: 'f1',
      ownerName: 'Rokeya Akter',
      ownerRole: fieldOfficerRole,
      label: 'Android phone',
      platform: DevicePlatform.android,
      status: DeviceStatus.pending,
      signPublicKey: 'not base64!',
      encPublicKey: '',
    );
    expect(broken.keysReadable, isFalse);
    expect(checkTypedCode(broken, vectorCode), CodeCheck.unreadableKeys);
  });
}
