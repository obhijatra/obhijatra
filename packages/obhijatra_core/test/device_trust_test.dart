// Device trust (docs/decisions/0008-device-trust.md): the phone's keys and
// enrolment, signed requests checked by the fake server with the real
// Ed25519 algorithm, every refusal turned into its own plain problem, and a
// sync engine that never sends without an approved device and never marks
// a submission as failed because of one.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/src/testing/ed25519_check.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_device/obhijatra_device.dart' show toBanglaDigits;
import 'package:pocketbase/pocketbase.dart' show AuthStore;
import 'package:test/test.dart';

import 'support/test_support.dart';

const String _label = 'Field app, Android';
const String _secondEmail = 'field2@example.org';

List<int> _hex(String text) => [
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
];

Matcher _problem(ProblemCode code) =>
    throwsA(isA<ObhijatraException>().having((e) => e.code, 'code', code));

/// A phone: its identity (kept in [store]), its session ([auth]) and a
/// client that signs with the identity.
final class _Phone {
  _Phone._(this.store, this.identity, this.auth, this.server);

  static Future<_Phone> open(
    FakeObhijatraServer fake, {
    MemoryDeviceKeyStore? store,
    AuthStore? auth,
  }) async {
    final keep = store ?? MemoryDeviceKeyStore();
    final identity = await DeviceIdentity.open(keep);
    final session = auth ?? AuthStore();
    return _Phone._(
      keep,
      identity,
      session,
      ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: session,
        signer: identity,
        httpClientFactory: fake.client,
      ),
    );
  }

  final MemoryDeviceKeyStore store;
  final DeviceIdentity identity;
  final AuthStore auth;
  final ObhijatraServer server;

  Future<SignedInUser> signIn([String email = fakeEmail]) =>
      server.signIn(email: email, password: fakePassword);

  Future<DeviceStatus> enrol() => identity.ensureEnrolled(
    server,
    label: _label,
    platform: DevicePlatform.android,
  );

  Future<void> close() async {
    server.close();
    await identity.close();
  }
}

void main() {
  group("the fake's Ed25519 check", () {
    test('accepts the RFC 8032 test vectors and the decision vector', () async {
      expect(
        ed25519SignatureValid(
          _hex(
            'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
          ),
          const [],
          _hex(
            'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555'
            'fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
          ),
        ),
        isTrue,
      );
      final pk = _hex(
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      );
      final sig = _hex(
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da'
        '085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      );
      expect(ed25519SignatureValid(pk, const [0x72], sig), isTrue);
      expect(ed25519SignatureValid(pk, const [0x73], sig), isFalse);

      // The decision record's signature vector, made by the apps' signer.
      final keys = await SoftwareDeviceKeys.fromSeeds(
        List<int>.filled(32, 0),
        List<int>.filled(32, 1),
      );
      final message = requestMessage(
        method: 'post',
        target: '/api/x?a=1',
        unixTime: '1793836800',
        nonce: 'AAAAAAAAAAAAAAAAAAAAAA',
        body: utf8.encode('{}'),
      );
      final signature = await keys.sign(message);
      expect(
        base64UrlNoPadding(signature),
        'jd5i3Nw3804mIJ7v6JiJZiZL0-fApy9xIFWavKqJpDe7ZsVhMVdXvkYfyBnm2GlRzO-'
        'fV95bdXGvCeL1YG9PAg',
      );
      expect(
        ed25519SignatureValid(keys.signPublicKey, message, signature),
        isTrue,
      );
    });

    test("agrees with the apps' signer and refuses any change", () async {
      final random = Random(5);
      for (var i = 0; i < 6; i++) {
        final keys = await SoftwareDeviceKeys.generate(random);
        final message = Uint8List.fromList(
          List<int>.generate(i * 13, (_) => random.nextInt(256)),
        );
        final good = await keys.sign(message);
        expect(ed25519KeyUsable(keys.signPublicKey), isTrue);
        expect(
          ed25519SignatureValid(keys.signPublicKey, message, good),
          isTrue,
        );
        final bent = Uint8List.fromList(good)..[i] ^= 0x01;
        expect(
          ed25519SignatureValid(keys.signPublicKey, message, bent),
          isFalse,
        );
        expect(
          ed25519SignatureValid(keys.signPublicKey, [...message, 0], good),
          isFalse,
        );
      }
      // The neutral point has small order: as a key it would accept one
      // fixed signature for every message.
      expect(ed25519KeyUsable([1, ...List<int>.filled(31, 0)]), isFalse);
    });
  });

  group('the identity', () {
    test('makes its keys once and keeps them in the store', () async {
      final store = MemoryDeviceKeyStore();
      final first = await DeviceIdentity.open(store);
      final again = await DeviceIdentity.open(store);
      expect(store.seedWrites, 1);
      expect(store.seedsText, matches(RegExp(r'^[0-9a-f]{128}$')));
      expect(again.checkCode, first.checkCode);
      expect(first.checkCode, matches(RegExp(r'^\d{18}$')));
      expect(
        first.checkCode,
        deviceCheckCode(first.signPublicKey, first.encPublicKey),
      );
      expect(first.deviceId, isNull);
      await first.close();
      await again.close();
    });

    test('never shows its secrets in text', () async {
      final store = MemoryDeviceKeyStore();
      final identity = await DeviceIdentity.open(store);
      addTearDown(identity.close);
      final seeds = (await store.readKeySeeds())!;
      final secret = store.seedsText!;
      for (final text in [
        '$seeds',
        '$identity',
        '${await store.readEnrolment()}',
      ]) {
        expect(text, isNot(contains(secret.substring(0, 16))));
        expect(text, isNot(contains(secret.substring(64, 80))));
      }
      expect('$seeds', 'DeviceKeySeeds(<redacted>)');
    });

    test('unreadable seeds count as none: new keys, and the enrolment of '
        'the old keys is forgotten', () async {
      final store = MemoryDeviceKeyStore()
        ..seedsText = 'not seeds'
        ..enrolmentText = const DeviceEnrolment(
          deviceId: 'device000000001',
          userId: 'fielduser1abcde',
        ).encode();
      final identity = await DeviceIdentity.open(store);
      addTearDown(identity.close);
      expect(identity.deviceId, isNull);
      expect(store.enrolmentText, isNull);
      expect(store.seedsText, matches(RegExp(r'^[0-9a-f]{128}$')));
    });
  });

  group('enrolment and signed requests', () {
    late FakeObhijatraServer fake;
    final phones = <_Phone>[];

    Future<_Phone> phone({MemoryDeviceKeyStore? store, AuthStore? auth}) async {
      final p = await _Phone.open(fake, store: store, auth: auth);
      phones.add(p);
      return p;
    }

    setUp(() {
      fake = FakeObhijatraServer(
        xform: householdVisitXForm,
        requireDevices: true,
      );
    });

    tearDown(() async {
      for (final p in phones) {
        await p.close();
      }
      phones.clear();
    });

    test('an unsigned request of a signed-in person is refused', () async {
      final p = await phone();
      await p.signIn();
      // Nothing is signed before enrolment.
      await expectLater(
        p.server.listPublishedFormVersions(),
        _problem(ProblemCode.deviceNotEnrolled),
      );
      expect(fake.lastHeaders.containsKey(DeviceHeaders.signature), isFalse);
    });

    test('a new phone enrols right after sign-in, waits, and works once '
        'approved', () async {
      final p = await phone();
      await p.signIn();
      final status = await p.enrol();
      expect(status.state, DeviceState.pending);
      expect(status.label, _label);
      expect(p.identity.deviceId, status.id);
      expect(p.identity.isEnrolledFor('fielduser1abcde'), isTrue);
      // The session became this device's.
      expect(fake.deviceOfSession(p.auth.token), status.id);
      // The approver's code is the phone's code.
      final device = fake.devices[status.id]!;
      expect(device.checkCode, p.identity.checkCode);
      expect(device.platform, 'android');

      // Waiting: only its status.
      await expectLater(
        p.server.listPublishedFormVersions(),
        _problem(ProblemCode.deviceNotApproved),
      );
      expect((await p.server.deviceStatus()).state, DeviceState.pending);

      fake.approveDevice(
        status.id,
        toBanglaDigits(groupCheckCode(p.identity.checkCode)),
      );
      final approved = await p.identity.refresh(p.server);
      expect(approved.state, DeviceState.active);
      expect(approved.expires, isNotNull);
      expect(p.identity.status!.state, DeviceState.active);
      expect(await p.server.listPublishedFormVersions(), hasLength(1));
      expect(fake.lastHeaders[DeviceHeaders.device], status.id);

      // A form download goes with a file token, and the device too.
      final formsDb = memoryDatabase();
      addTearDown(formsDb.close);
      final forms = await FormRepository(formsDb).refreshFromServer(p.server);
      expect(forms.added, hasLength(1));
    });

    test('what the phone knows survives a restart', () async {
      final store = MemoryDeviceKeyStore();
      final auth = AuthStore();
      final p = await phone(store: store, auth: auth);
      await p.signIn();
      final status = await p.enrol();
      fake.approveDevice(status.id, p.identity.checkCode);
      await p.identity.refresh(p.server);

      final later = await phone(store: store, auth: auth);
      expect(later.identity.deviceId, status.id);
      expect(later.identity.checkCode, p.identity.checkCode);
      expect(later.identity.status!.state, DeviceState.active);
      expect(later.identity.knownBlocker('fielduser1abcde'), isNull);
      expect(await later.server.listPublishedFormVersions(), hasLength(1));
    });

    test('enrolling again changes nothing and asks nothing', () async {
      final p = await phone();
      await p.signIn();
      final first = await p.enrol();
      fake.log.clear();
      final again = await p.enrol();
      expect(again.id, first.id);
      expect(fake.log, isEmpty);
      // The server, asked directly with the same keys, gives the same
      // device.
      final direct = await p.server.enrolDevice(
        keys: await SoftwareDeviceKeys.fromSeeds(
          (await p.store.readKeySeeds())!.signSeed,
          (await p.store.readKeySeeds())!.encSeed,
        ),
        label: _label,
        platform: DevicePlatform.android,
      );
      expect(direct.id, first.id);
      expect(fake.devices, hasLength(1));
    });

    test(
      'a sign-in signed by the enrolled device belongs to it at once',
      () async {
        final p = await phone();
        await p.signIn();
        final status = await p.enrol();
        p.server.signOut();
        await p.signIn();
        expect(fake.deviceOfSession(p.auth.token), status.id);
        expect(fake.lastHeaders[DeviceHeaders.device], status.id);
      },
    );

    test('switched off: every request is refused, the status says so and '
        'the phone remembers', () async {
      final p = await phone();
      await p.signIn();
      final status = await p.enrol();
      fake
        ..approveDevice(status.id, p.identity.checkCode)
        ..revokeDevice(status.id);
      await expectLater(
        p.server.listPublishedFormVersions(),
        _problem(ProblemCode.deviceRevoked),
      );
      final known = await p.identity.refresh(p.server);
      expect(known.state, DeviceState.revoked);
      expect(
        p.identity.knownBlocker('fielduser1abcde'),
        ProblemCode.deviceRevoked,
      );
      expect(
        DeviceEnrolment.decode(p.store.enrolmentText)!.status!.state,
        DeviceState.revoked,
      );
    });

    test('an approval that ran out: refused until approved again with the '
        'same code', () async {
      final p = await phone();
      await p.signIn();
      final status = await p.enrol();
      fake.approveDevice(status.id, p.identity.checkCode);
      await p.identity.refresh(p.server);
      fake.expireDevice(status.id);
      await expectLater(
        p.server.listPublishedFormVersions(),
        _problem(ProblemCode.deviceApprovalExpired),
      );
      expect((await p.identity.refresh(p.server)).state, DeviceState.expired);
      fake.approveDevice(status.id, p.identity.checkCode);
      expect((await p.identity.refresh(p.server)).state, DeviceState.active);
    });

    test('a phone clock more than 5 minutes out is refused', () async {
      final p = await phone();
      await p.signIn();
      await p.enrol();
      fake.clockOffset = const Duration(minutes: 6);
      await expectLater(
        p.server.deviceStatus(),
        _problem(ProblemCode.deviceClockWrong),
      );
      fake.clockOffset = const Duration(minutes: -4);
      expect((await p.server.deviceStatus()).state, DeviceState.pending);
    });

    test('an ended session: refused, and signing in again works', () async {
      final p = await phone();
      await p.signIn();
      final status = await p.enrol();
      fake.endSessionsOf(fakeEmail);
      await expectLater(
        p.server.deviceStatus(),
        _problem(ProblemCode.sessionEnded),
      );
      // The ended session is not sent with the sign-in.
      await p.signIn();
      expect(fake.deviceOfSession(p.auth.token), status.id);
      expect((await p.server.deviceStatus()).state, DeviceState.pending);
    });

    test("another device's session is refused", () async {
      final a = await phone();
      await a.signIn();
      await a.enrol();
      final b = await phone();
      await b.signIn();
      await b.enrol();
      // Phone B tries to use phone A's session.
      final thief = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: AuthStore()..save(a.auth.token, a.auth.record),
        signer: b.identity,
        httpClientFactory: fake.client,
      );
      addTearDown(thief.close);
      await expectLater(
        thief.deviceStatus(),
        _problem(ProblemCode.sessionOnOtherDevice),
      );
    });

    test('a signature by other keys, or a request sent twice, does not '
        'check out', () async {
      final p = await phone();
      await p.signIn();
      final status = await p.enrol();
      final other = await SoftwareDeviceKeys.generate();
      final forger = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: p.auth,
        signer: DeviceRequestSigner(other, deviceId: status.id),
        httpClientFactory: fake.client,
      );
      addTearDown(forger.close);
      await expectLater(
        forger.deviceStatus(),
        _problem(ProblemCode.deviceSignatureInvalid),
      );

      final replay = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: p.auth,
        signer: _Replay(p.identity),
        httpClientFactory: fake.client,
      );
      addTearDown(replay.close);
      expect((await replay.deviceStatus()).id, status.id);
      await expectLater(
        replay.deviceStatus(),
        _problem(ProblemCode.deviceSignatureInvalid),
      );
      expect(ProblemCode.deviceSignatureInvalid.isTransient, isTrue);
    });

    test('a file link works only with an approved device', () async {
      final p = await phone();
      await p.signIn();
      final status = await p.enrol();
      fake.approveDevice(status.id, p.identity.checkCode);
      final version = (await p.server.listPublishedFormVersions()).single;
      expect(await p.server.downloadXForm(version), contains('<h:html'));

      // The same kind of link, leaked and opened without the device, is
      // refused.
      final token = fake.issueFileToken('fielduser1abcde');
      final client = fake.client();
      addTearDown(client.close);
      final download = await client.get(
        FakeObhijatraServer.baseUrl.resolve(
          '/api/files/form_versions/${version.serverId}/'
          '${version.xformFileName}?token=$token',
        ),
      );
      expect(download.statusCode, 403);
      expect(download.body, contains(DeviceReason.signatureRequired));
    });

    test('keys already in use (switched off) are replaced once, by '
        'themselves', () async {
      final p = await phone();
      await p.signIn();
      final first = await p.enrol();
      fake.revokeDevice(first.id);
      // The phone lost its record of the enrolment, not its keys.
      p.store.enrolmentText = null;
      final later = await phone(store: p.store);
      await later.signIn();
      expect(later.identity.deviceId, isNull);
      final code = later.identity.checkCode;
      final status = await later.enrol();
      expect(status.id, isNot(first.id));
      expect(status.state, DeviceState.pending);
      expect(later.identity.checkCode, isNot(code));
      expect(fake.devices, hasLength(2));
    });

    test('at most 3 devices wait per person', () async {
      for (var i = 0; i < 3; i++) {
        final p = await phone();
        await p.signIn();
        await p.enrol();
      }
      final fourth = await phone();
      await fourth.signIn();
      await expectLater(
        fourth.enrol(),
        _problem(ProblemCode.tooManyDevicesWaiting),
      );
      expect(fourth.identity.deviceId, isNull);
    });

    test('a device the server no longer knows enrols again with the same '
        'keys, waits, and is noted until approved', () async {
      final p = await phone();
      final user = await p.signIn();
      final first = await p.enrol();
      fake.approveDevice(first.id, p.identity.checkCode);
      await p.identity.refresh(p.server);
      final code = p.identity.checkCode;
      final seeds = p.store.seedsText;
      expect(p.identity.serverForgot, isFalse);

      // The server was restored from a backup older than the enrolment.
      fake.forgetDevice(first.id);
      await expectLater(
        p.server.listPublishedFormVersions(),
        _problem(ProblemCode.deviceUnknown),
      );
      final again = await p.identity.refresh(p.server);
      expect(again.id, isNot(first.id));
      expect(again.state, DeviceState.pending);
      expect(p.identity.deviceId, again.id);
      expect(p.identity.serverForgot, isTrue);
      expect(p.identity.knownBlocker(user.id), ProblemCode.deviceNotApproved);
      // The same keys, so the same numbers for the approver.
      expect(p.store.seedsText, seeds);
      expect(p.identity.checkCode, code);
      expect(fake.devices[again.id]!.checkCode, code);
      expect(fake.devices[again.id]!.label, _label);
      expect(fake.devices[again.id]!.platform, 'android');

      // Kept across a restart; gone once approved.
      final later = await phone(store: p.store, auth: p.auth);
      expect(later.identity.deviceId, again.id);
      expect(later.identity.serverForgot, isTrue);
      fake.approveDevice(again.id, code);
      expect(
        (await later.identity.refresh(later.server)).state,
        DeviceState.active,
      );
      expect(later.identity.serverForgot, isFalse);
      expect(await later.server.listPublishedFormVersions(), hasLength(1));
    });

    test('a refusal seen elsewhere forgets the device id at once (the keys '
        'stay); enrolling again happens with a server at hand', () async {
      final p = await phone();
      final user = await p.signIn();
      final first = await p.enrol();
      fake.approveDevice(first.id, p.identity.checkCode);
      await p.identity.refresh(p.server);
      final code = p.identity.checkCode;
      fake.forgetDevice(first.id);

      // Without a server (and not enrolled again yet), nothing is signed
      // with the forgotten id; the phone knows it must be set up again.
      await p.identity.recordProblem(ProblemCode.deviceUnknown);
      expect(p.identity.deviceId, isNull);
      expect(p.identity.isEnrolledFor(user.id), isFalse);
      expect(p.identity.serverForgot, isTrue);
      expect(p.identity.knownBlocker(user.id), ProblemCode.deviceNotEnrolled);
      expect(p.identity.checkCode, code);

      // Kept across a restart, then enrolled again after the sign-in.
      final later = await phone(store: p.store, auth: p.auth);
      expect(later.identity.deviceId, isNull);
      expect(later.identity.serverForgot, isTrue);
      final again = await later.enrol();
      expect(again.state, DeviceState.pending);
      expect(later.identity.checkCode, code);
      expect(later.identity.serverForgot, isTrue);
      expect(fake.devices.keys, [again.id]);

      // With a server, a refusal enrols again at once.
      fake.forgetDevice(again.id);
      await later.identity.recordProblem(
        ProblemCode.deviceUnknown,
        server: later.server,
      );
      final third = later.identity.status!;
      expect(third.id, isNot(again.id));
      expect(third.state, DeviceState.pending);
      expect(later.identity.checkCode, code);
    });

    test(
      'another person after the server forgot the device gets new keys',
      () async {
        fake.users[_secondEmail] = const FakeFieldUser(id: 'fielduser2abcde');
        final p = await phone();
        await p.signIn();
        final first = await p.enrol();
        final firstCode = p.identity.checkCode;
        fake.forgetDevice(first.id);
        await p.identity.recordProblem(ProblemCode.deviceUnknown);
        p.server.signOut();
        await p.signIn(_secondEmail);
        final second = await p.enrol();
        expect(p.identity.checkCode, isNot(firstCode));
        expect(p.identity.serverForgot, isFalse);
        expect(fake.devices[second.id]!.userId, 'fielduser2abcde');
      },
    );

    test('another person on the same phone gets new keys', () async {
      fake.users[_secondEmail] = const FakeFieldUser(id: 'fielduser2abcde');
      final p = await phone();
      await p.signIn();
      final first = await p.enrol();
      final firstCode = p.identity.checkCode;
      p.server.signOut();
      await p.signIn(_secondEmail);
      final second = await p.enrol();
      expect(second.id, isNot(first.id));
      expect(p.identity.isEnrolledFor('fielduser2abcde'), isTrue);
      expect(p.identity.checkCode, isNot(firstCode));
      expect(fake.devices[second.id]!.userId, 'fielduser2abcde');
    });

    test('a one-time password: enrol, choose the new password from the '
        'waiting phone, then wait for approval', () async {
      const oneTime = 'kfmw-tqzp-hrvx';
      const own = 'river tea mango kite';
      fake.giveOneTimePassword(fakeEmail, oneTime);
      final p = await phone();
      final user = await p.server.signIn(email: fakeEmail, password: oneTime);
      expect(user.mustChangePassword, isTrue);
      final status = await p.enrol();
      expect(status.state, DeviceState.pending);

      final changed = await p.server.changePassword(
        currentPassword: oneTime,
        newPassword: own,
      );
      expect(changed.mustChangePassword, isFalse);
      expect(fake.mustChangePassword(fakeEmail), isFalse);
      // The sign-in with the new password is the device's at once.
      expect(fake.deviceOfSession(p.auth.token), status.id);
      await expectLater(
        p.server.listPublishedFormVersions(),
        _problem(ProblemCode.deviceNotApproved),
      );
      fake.approveDevice(status.id, p.identity.checkCode);
      await p.identity.refresh(p.server);
      expect(await p.server.listPublishedFormVersions(), hasLength(1));
    });

    test('a waiting phone cannot change the password of a person who need '
        'not', () async {
      final p = await phone();
      await p.signIn();
      await p.enrol();
      await expectLater(
        p.server.changePassword(
          currentPassword: fakePassword,
          newPassword: 'chosen by a thief 1',
        ),
        _problem(ProblemCode.deviceNotApproved),
      );
      expect(fake.passwordOf(fakeEmail), fakePassword);
    });

    test(
      '"Set up this phone again" forgets everything and makes new keys',
      () async {
        final p = await phone();
        await p.signIn();
        final first = await p.enrol();
        final code = p.identity.checkCode;
        final changes = <void>[];
        final listening = p.identity.changes.listen(changes.add);
        addTearDown(listening.cancel);
        await p.identity.reset();
        await pumpEventQueue();
        expect(changes, isNotEmpty);
        expect(p.identity.deviceId, isNull);
        expect(p.identity.status, isNull);
        expect(p.identity.checkCode, isNot(code));
        expect(p.store.enrolmentText, isNull);
        // Nothing is signed until the new keys are enrolled.
        await expectLater(
          p.server.listPublishedFormVersions(),
          _problem(ProblemCode.deviceNotEnrolled),
        );
        // A new sign-in, then a new device.
        p.server.signOut();
        await p.signIn();
        final second = await p.enrol();
        expect(second.id, isNot(first.id));
      },
    );

    test('the label is checked before anything is sent', () async {
      final p = await phone();
      await p.signIn();
      final keys = await SoftwareDeviceKeys.generate();
      fake.log.clear();
      for (final label in ['', ' ', 'a' * 101, 'two\nlines']) {
        await expectLater(
          p.server.enrolDevice(
            keys: keys,
            label: label,
            platform: DevicePlatform.ios,
          ),
          throwsArgumentError,
        );
      }
      expect(fake.log, isEmpty);
    });

    test('without a session nothing is enrolled or asked', () async {
      final p = await phone();
      await expectLater(p.enrol(), _problem(ProblemCode.signInRequired));
      await expectLater(
        p.identity.refresh(p.server),
        _problem(ProblemCode.deviceNotEnrolled),
      );
      expect(fake.log, isEmpty);
    });
  });

  group('the status', () {
    test('reads the server view, an approval that ran out included', () {
      final active = DeviceStatus.fromJson({
        'id': 'device000000001',
        'status': 'active',
        'label': _label,
        'platform': 'android',
        'expires': '2027-11-06 05:24:35.123Z',
        'approved_at': '2026-11-06 05:24:35.123Z',
        'needs_second_approval': false,
        'approval_expired': false,
      });
      expect(active.state, DeviceState.active);
      expect(active.expires, DateTime.utc(2027, 11, 6, 5, 24, 35, 123));
      expect(active.usableAt(DateTime.utc(2027, 11, 6)), isTrue);
      expect(
        active.blockerAt(DateTime.utc(2027, 11, 7)),
        ProblemCode.deviceApprovalExpired,
      );
      final ran = DeviceStatus.fromJson({
        'id': 'device000000001',
        'status': 'active',
        'expires': '2026-01-01 00:00:00.000Z',
        'approval_expired': true,
      });
      expect(ran.state, DeviceState.expired);
      final waiting = DeviceStatus.fromJson({
        'id': 'device000000001',
        'status': 'pending',
        'expires': '',
        'approved_at': '',
      });
      expect(waiting.expires, isNull);
      expect(waiting.blockerAt(DateTime.now()), ProblemCode.deviceNotApproved);
      expect(
        () => DeviceStatus.fromJson({'id': 'x', 'status': 'lost'}),
        _problem(ProblemCode.unexpectedResponse),
      );
      // Kept and read back as it was.
      final back = DeviceStatus.fromStored(active.toStored())!;
      expect(back.state, active.state);
      expect(back.expires, active.expires);
      expect(back.label, _label);
    });

    test('every device refusal has its own problem, and none of them is a '
        'fault of the data', () {
      const codes = [
        ProblemCode.deviceNotEnrolled,
        ProblemCode.deviceSignatureInvalid,
        ProblemCode.deviceUnknown,
        ProblemCode.deviceClockWrong,
        ProblemCode.deviceNotApproved,
        ProblemCode.deviceApprovalExpired,
        ProblemCode.deviceRevoked,
        ProblemCode.sessionEnded,
        ProblemCode.sessionOnOtherDevice,
      ];
      for (final code in codes) {
        expect(code.isDeviceProblem, isTrue, reason: code.name);
        expect(code.blocksSync || code.isTransient, isTrue, reason: code.name);
      }
      expect(ProblemCode.sessionEnded.needsSignInAgain, isTrue);
      expect(ProblemCode.sessionOnOtherDevice.needsSignInAgain, isTrue);
      expect(ProblemCode.deviceKeyInUse.isDeviceProblem, isFalse);
    });
  });

  group('sync', () {
    late FakeObhijatraServer fake;
    late DeviceDatabase db;
    late OutboxRepository outbox;
    late _Phone p;
    late SyncEngine sync;

    Future<String> queueOne() async =>
        (await outbox.enqueue(await fillHouseholdVisit())).instanceId;

    setUp(() async {
      fake = FakeObhijatraServer(
        xform: householdVisitXForm,
        requireDevices: true,
      );
      db = memoryDatabase();
      outbox = OutboxRepository(db);
      p = await _Phone.open(fake);
      await p.signIn();
      sync = SyncEngine(
        database: db,
        server: p.server,
        attachments: MemoryAttachments(),
        device: p.identity,
        random: Random(42),
        autoRetry: false,
      );
      await sync.start();
    });

    tearDown(() async {
      await sync.dispose();
      await p.close();
      await db.close();
    });

    Future<void> expectKept(String id) async {
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);
      expect(fake.submissions, isEmpty);
    }

    test('a phone that is not enrolled sends nothing', () async {
      final id = await queueOne();
      final report = await sync.syncNow();
      expect(report.stoppedBy, ProblemCode.deviceNotEnrolled);
      expect(sync.status.blockedBy, ProblemCode.deviceNotEnrolled);
      await expectKept(id);
      expect(fake.log.where((l) => l.contains('submissions')), isEmpty);
    });

    test('a waiting phone sends nothing, and sends at once after its '
        'approval', () async {
      final status = await p.enrol();
      final id = await queueOne();
      final report = await sync.syncNow();
      expect(report.stoppedBy, ProblemCode.deviceNotApproved);
      expect(sync.status.blockedBy, ProblemCode.deviceNotApproved);
      await expectKept(id);
      expect(fake.log.where((l) => l.contains('submissions')), isEmpty);

      fake.approveDevice(status.id, p.identity.checkCode);
      // The next run asks the server, which now says yes.
      final after = await sync.syncNow();
      expect(after.sent, 1, reason: '${after.stoppedBy}');
      expect((await outbox.find(id))!.state, OutboxState.sent);
      expect(sync.status.blockedBy, isNull);
      expect(p.identity.status!.state, DeviceState.active);
    });

    test(
      'an approved phone is not asked about again before each run',
      () async {
        final status = await p.enrol();
        fake.approveDevice(status.id, p.identity.checkCode);
        await p.identity.refresh(p.server);
        await queueOne();
        fake.log.clear();
        expect((await sync.syncNow()).sent, 1);
        expect(fake.log, isNot(contains('GET $deviceMePath')));
      },
    );

    test('a device the server no longer knows: forms stay queued, the phone '
        'enrols again with the same keys, and sends once approved', () async {
      final status = await p.enrol();
      fake.approveDevice(status.id, p.identity.checkCode);
      await p.identity.refresh(p.server);
      final code = p.identity.checkCode;
      final id = await queueOne();
      fake.forgetDevice(status.id);

      final report = await sync.syncNow();
      expect(report.stoppedBy, ProblemCode.deviceUnknown);
      await expectKept(id);
      expect(
        (await outbox.find(id))!.lastError,
        ProblemCode.deviceUnknown.name,
      );
      final again = p.identity.status!;
      expect(again.id, isNot(status.id));
      expect(again.state, DeviceState.pending);
      expect(p.identity.checkCode, code);
      expect(p.identity.serverForgot, isTrue);

      expect((await sync.syncNow()).stoppedBy, ProblemCode.deviceNotApproved);
      await expectKept(id);
      fake.approveDevice(again.id, code);
      final after = await sync.syncNow();
      expect(after.sent, 1, reason: '${after.stoppedBy}');
      expect((await outbox.find(id))!.state, OutboxState.sent);
    });

    test('switched off while forms wait: they stay queued and the phone '
        'remembers', () async {
      final status = await p.enrol();
      fake.approveDevice(status.id, p.identity.checkCode);
      await p.identity.refresh(p.server);
      final a = await queueOne();
      final b = await queueOne();
      fake.revokeDevice(status.id);
      final report = await sync.syncNow();
      expect(report.stoppedBy, ProblemCode.deviceRevoked);
      expect(sync.status.blockedBy, ProblemCode.deviceRevoked);
      await expectKept(a);
      await expectKept(b);
      expect(p.identity.status!.state, DeviceState.revoked);
    });

    test('a refusal of a submission keeps it as it was', () async {
      final status = await p.enrol();
      fake.approveDevice(status.id, p.identity.checkCode);
      await p.identity.refresh(p.server);
      final id = await queueOne();
      for (final (refusal, code) in [
        (
          const DeviceRefusal(403, DeviceReason.expired),
          ProblemCode.deviceApprovalExpired,
        ),
        (
          const DeviceRefusal(401, DeviceReason.sessionRevoked),
          ProblemCode.sessionEnded,
        ),
        (
          const DeviceRefusal(403, DeviceReason.clock),
          ProblemCode.deviceClockWrong,
        ),
      ]) {
        fake.submissionGlitches.add(refusal);
        // Approved again as far as the phone knows.
        await p.identity.refresh(p.server);
        final report = await sync.syncNow();
        expect(report.stoppedBy, code);
        expect(report.problems, 0);
        expect(sync.status.blockedBy, code);
        await expectKept(id);
      }
      // A signature that did not check out: tried again later by itself,
      // not counted against the submission.
      fake.submissionGlitches.add(
        const DeviceRefusal(403, DeviceReason.signatureInvalid),
      );
      final report = await sync.syncNow();
      expect(report.stoppedBy, ProblemCode.deviceSignatureInvalid);
      expect(sync.status.blockedBy, isNull);
      await expectKept(id);
      expect((await sync.syncNow()).sent, 1);
    });

    test('an unknown answer about the phone stops the run without '
        'blocking it', () async {
      await p.enrol();
      final id = await queueOne();
      fake.deviceGlitches.add(const NoConnection());
      final report = await sync.syncNow();
      expect(report.stoppedBy, ProblemCode.offline);
      expect(sync.status.isOffline, isTrue);
      expect(sync.status.blockedBy, isNull);
      await expectKept(id);
    });
  });
}

/// Signs the first request with [inner], then sends the same headers again
/// (a replay).
final class _Replay implements RequestSigner {
  _Replay(this.inner);

  final RequestSigner inner;
  Map<String, String>? _first;

  @override
  Future<Map<String, String>> signatureHeaders(SignableRequest request) async =>
      _first ??= await inner.signatureHeaders(request);
}
