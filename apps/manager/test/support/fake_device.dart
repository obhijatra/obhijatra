import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';

/// The public keys of ADR 8's check-code test vector (bytes 00..1f and
/// 20..3f), and the code they give.
final Uint8List vectorSignKey = Uint8List.fromList(
  List<int>.generate(32, (i) => i),
);
final Uint8List vectorEncKey = Uint8List.fromList(
  List<int>.generate(32, (i) => 32 + i),
);
const String vectorCode = '225142753699752889';
const String vectorCodeBangla = '২২৫ ১৪২ ৭৫৩ ৬৯৯ ৭৫২ ৮৮৯';

/// Keys for widget tests: fixed public keys and a signature of zeros (the
/// fake API never checks it). [index] 0 gives the test vector's keys.
class FakeDeviceKeys implements DeviceKeys {
  FakeDeviceKeys([int index = 0])
    : signPublicKey = Uint8List.fromList(
        List<int>.generate(32, (i) => (i + 64 * index) % 256),
      ),
      encPublicKey = Uint8List.fromList(
        List<int>.generate(32, (i) => (32 + i + 64 * index) % 256),
      );

  @override
  final Uint8List signPublicKey;

  @override
  final Uint8List encPublicKey;

  @override
  Future<Uint8List> sign(Uint8List message) async => Uint8List(64);
}

/// An identity store in memory, for widget tests.
class MemoryIdentityStore implements DeviceIdentityStore {
  /// What [support] answers.
  KeyStoreSupport supportAnswer = KeyStoreSupport.supported;

  /// Keys by account.
  final Map<String, DeviceIdentity> identities = <String, DeviceIdentity>{};

  /// Who last used the device.
  String? last;

  /// How many key sets were made.
  int created = 0;

  /// Accounts whose keys were wiped, in order.
  final List<String> wiped = <String>[];

  /// Set to make every call fail.
  bool broken = false;

  void _check() {
    if (broken) throw const DeviceKeysUnavailable();
  }

  @override
  Future<KeyStoreSupport> support() async => supportAnswer;

  @override
  Future<DeviceIdentity?> load(String account) async {
    _check();
    return identities[account];
  }

  /// When set, the next [create] waits for it (once).
  Completer<void>? createGate;

  @override
  Future<DeviceIdentity> create(String account) async {
    _check();
    final wait = createGate;
    createGate = null;
    if (wait != null) await wait.future;
    final identity = DeviceIdentity(keys: FakeDeviceKeys(created++));
    identities[account] = identity;
    return identity;
  }

  @override
  Future<DeviceIdentity> saveDeviceId(String account, String deviceId) async {
    _check();
    final identity = identities[account]!.withDeviceId(deviceId);
    identities[account] = identity;
    return identity;
  }

  /// Accounts whose device id was forgotten, in order.
  final List<String> forgotten = <String>[];

  @override
  Future<DeviceIdentity> forgetDeviceId(String account) async {
    _check();
    forgotten.add(account);
    final identity = DeviceIdentity(keys: identities[account]!.keys);
    identities[account] = identity;
    return identity;
  }

  @override
  Future<void> wipe(String account) async {
    _check();
    wiped.add(account);
    identities.remove(account);
  }

  @override
  Future<String?> lastAccount() async => last;

  @override
  Future<void> rememberLastAccount(String account) async => last = account;
}

/// A device in an approver's list. [keys] 0 has the test vector's code.
DeviceRecord deviceRecord({
  required String id,
  String ownerId = 'f1',
  String ownerName = 'Rokeya Akter',
  String ownerContact = '+8801700000001',
  PersonKind kind = PersonKind.field,
  String role = fieldOfficerRole,
  String label = 'Android phone',
  String platform = DevicePlatform.android,
  DeviceStatus status = DeviceStatus.pending,
  DateTime? expires,
  DateTime? created,
  String firstApprovedBy = '',
  int keys = 0,
}) {
  final fake = FakeDeviceKeys(keys);
  return DeviceRecord(
    id: id,
    ownerKind: kind,
    ownerId: ownerId,
    ownerName: ownerName,
    ownerContact: ownerContact,
    ownerRole: role,
    label: label,
    platform: platform,
    status: status,
    signPublicKey: base64.encode(fake.signPublicKey),
    encPublicKey: base64.encode(fake.encPublicKey),
    expires: expires,
    created: created ?? DateTime(2026, 11, 6, 9),
    firstApprovedBy: firstApprovedBy,
  );
}

/// The check code of [deviceRecord]'s keys number [keys].
String fakeCode([int keys = 0]) {
  final fake = FakeDeviceKeys(keys);
  return deviceCheckCode(fake.signPublicKey, fake.encPublicKey);
}
