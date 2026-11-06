/// This device's identity for device trust (docs/decisions/0008-device-trust.md):
/// its two key pairs, the id the server gave it at enrolment, the person it
/// was enrolled for and the last status the server reported.
///
/// The order the apps follow:
///
/// 1. [DeviceIdentity.open] once at start, before any sign-in: it reads the
///    keys of the person who signed in last from the app's
///    [DeviceKeyStore] (the platform's protected storage). Each person has
///    their own keys on the device.
/// 2. Every `ObhijatraServer` gets the identity as its signer. Before
///    enrolment nothing is signed; afterwards every request is, the
///    sign-in too, so a new session belongs to this device at once.
/// 3. Right after a sign-in, [DeviceIdentity.ensureEnrolled]: it switches to
///    that person's keys (made on their first enrolment here) and enrols
///    them if they are not enrolled yet. A person with a one-time password
///    enrols first, then chooses a new password from the waiting device.
/// 4. [DeviceIdentity.refresh] asks the server again (the waiting screen,
///    and sync while the device is not known to be approved);
///    [DeviceIdentity.recordProblem] keeps a refusal seen elsewhere.
///    When the server no longer knows the device (`device_unknown`, for
///    example after it was restored from an older backup), both forget the
///    device id, keep the keys and enrol again with them: a new device that
///    waits for approval ([DeviceIdentity.serverForgot]).
/// 5. [DeviceIdentity.reset] forgets the current person's keys and makes new
///    ones ("Set up this phone again").
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/server/obhijatra_server.dart';
import 'package:obhijatra_core/src/server/request_signer.dart';
import 'package:obhijatra_core/src/server/server_models.dart';

/// The secret seeds of a device's two key pairs (32 bytes each): Ed25519
/// for signing, X25519 for encryption.
///
/// Kept only in the platform's protected storage ([DeviceKeyStore]);
/// never logged, never sent. [toString] never shows them.
final class DeviceKeySeeds {
  /// Wraps the two 32-byte seeds (copied).
  DeviceKeySeeds(List<int> signSeed, List<int> encSeed)
    : _sign = Uint8List.fromList(signSeed),
      _enc = Uint8List.fromList(encSeed) {
    if (_sign.length != 32 || _enc.length != 32) {
      throw ArgumentError('Device key seeds are 32 bytes each');
    }
  }

  /// Reads seeds written by [toText] (128 hexadecimal digits); `null` when
  /// [text] is not that.
  static DeviceKeySeeds? fromText(String? text) {
    final clean = text?.trim().toLowerCase();
    if (clean == null || !RegExp(r'^[0-9a-f]{128}$').hasMatch(clean)) {
      return null;
    }
    final bytes = [
      for (var i = 0; i < clean.length; i += 2)
        int.parse(clean.substring(i, i + 2), radix: 16),
    ];
    return DeviceKeySeeds(bytes.sublist(0, 32), bytes.sublist(32));
  }

  final Uint8List _sign;
  final Uint8List _enc;

  /// A copy of the Ed25519 seed.
  Uint8List get signSeed => Uint8List.fromList(_sign);

  /// A copy of the X25519 seed.
  Uint8List get encSeed => Uint8List.fromList(_enc);

  /// Both seeds as 128 lower-case hexadecimal digits, for the protected
  /// storage only.
  String toText() => [
    ..._sign,
    ..._enc,
  ].map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  @override
  String toString() => 'DeviceKeySeeds(<redacted>)';
}

/// What the phone remembers about its enrolment: the [deviceId] the server
/// gave, the person ([userId]) it was enrolled for, the [label] and
/// [platform] it was enrolled under, and the last [status] the server
/// reported, with when ([checkedAt]). Nothing in it is secret.
///
/// Without a [deviceId], the server no longer knew the device
/// ([serverForgot]): it must be enrolled again, with the same keys, for the
/// same person.
final class DeviceEnrolment {
  /// Creates the record.
  const DeviceEnrolment({
    required this.deviceId,
    required this.userId,
    this.status,
    this.checkedAt,
    this.label = '',
    this.platform,
    this.serverForgot = false,
  });

  /// Reads what [encode] wrote; `null` when [text] is not that.
  static DeviceEnrolment? decode(String? text) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, Object?>) return null;
      final device = json['device'];
      final user = json['user'];
      if (user is! String || user.isEmpty) return null;
      if (device != null && (device is! String || device.isEmpty)) {
        return null;
      }
      final forgot = json['server_forgot'] == true;
      // A record without a device id is only ever written for that reason.
      if (device == null && !forgot) return null;
      final checked = json['checked_at'];
      final status = DeviceStatus.fromStored(json['status']);
      final label = json['label'];
      return DeviceEnrolment(
        deviceId: device as String?,
        userId: user,
        status: device != null && status?.id == device ? status : null,
        checkedAt: checked is String ? DateTime.tryParse(checked) : null,
        label: label is String ? label : '',
        platform: DevicePlatform.values
            .where((p) => p.name == json['platform'])
            .firstOrNull,
        serverForgot: forgot,
      );
    } on FormatException {
      return null;
    }
  }

  /// The id the server gave this device; `null` when the server no longer
  /// knew it and it is not enrolled again yet.
  final String? deviceId;

  /// The field user the device was enrolled for.
  final String userId;

  /// The last status the server reported, if any.
  final DeviceStatus? status;

  /// When [status] was last confirmed by the server (UTC).
  final DateTime? checkedAt;

  /// The label the device was enrolled under (empty when not known).
  final String label;

  /// The platform the device was enrolled as, if known.
  final DevicePlatform? platform;

  /// Whether the server no longer knew this device's earlier enrolment, so
  /// it is (being) enrolled again and waits for approval again. Cleared once
  /// it is approved.
  final bool serverForgot;

  /// The record as JSON text, for the protected storage.
  String encode() => jsonEncode({
    'device': ?deviceId,
    'user': userId,
    'status': ?status?.toStored(),
    'checked_at': ?checkedAt?.toUtc().toIso8601String(),
    if (label.isNotEmpty) 'label': label,
    'platform': ?platform?.name,
    if (serverForgot) 'server_forgot': true,
  });

  @override
  String toString() =>
      'DeviceEnrolment(${deviceId ?? 'forgotten by the server'}, '
      '${status?.state.name})';
}

/// Keeps device identities in the platform's protected storage (Android
/// Keystore, iOS Keychain; this device only, never in backups), one per
/// person (their field user id): their key seeds and their enrolment, and
/// which person signs now. Implemented by the app, for example with
/// `flutter_secure_storage`, next to the database key ([KeyStore]). The
/// seeds never leave it except to sign on this device.
///
/// A phone shared by several people keeps each person's keys, so switching
/// back to someone uses their approved device again.
abstract interface class DeviceKeyStore {
  /// The person whose keys sign now (the last one enrolled or signed in),
  /// or `null`.
  Future<String?> readCurrentAccount();

  /// Records [account] as the person whose keys sign now.
  Future<void> writeCurrentAccount(String account);

  /// [account]'s key seeds, or `null` when none have been made (or what is
  /// stored is unreadable).
  Future<DeviceKeySeeds?> readKeySeeds(String account);

  /// Stores [account]'s [seeds]. Called only after [clear] of that account,
  /// so it never replaces keys that are still enrolled.
  Future<void> writeKeySeeds(String account, DeviceKeySeeds seeds);

  /// [account]'s enrolment, or `null`.
  Future<DeviceEnrolment?> readEnrolment(String account);

  /// Stores [account]'s [enrolment], replacing the earlier one.
  Future<void> writeEnrolment(String account, DeviceEnrolment enrolment);

  /// Removes [account]'s seeds and enrolment; other people's stay.
  Future<void> clear(String account);

  /// Removes every person's seeds and enrolment, and the current person (a
  /// new installation).
  Future<void> clearAll();
}

/// This device's keys and enrolment for the person who signs now, and the
/// [RequestSigner] that signs with them (see the library documentation for
/// the order of use).
///
/// Each person has keys of their own on this device, made the first time
/// they enrol here and kept for them ([DeviceKeyStore]); signing in as
/// someone else switches to that person's keys ([ensureEnrolled]), so a
/// shared phone needs one approval per person, not one per switch.
///
/// One instance lives as long as the app; pass it as the signer of every
/// `ObhijatraServer`. After a switch or a [reset] it signs with the keys of
/// the moment, so the clients made before keep working.
final class DeviceIdentity implements RequestSigner {
  DeviceIdentity._(this._store, this._now, this._random);

  /// Reads the identity of the person who signed last from [store]. Keys
  /// are made only when a person first enrols on this device. A stored
  /// enrolment without its keys (or of someone else) is ignored.
  ///
  /// [now] is the clock signatures use (default: `clock.now()`); [random]
  /// makes keys and nonces (default: the platform's secure generator).
  static Future<DeviceIdentity> open(
    DeviceKeyStore store, {
    DateTime Function()? now,
    Random? random,
  }) async {
    final identity = DeviceIdentity._(
      store,
      now ?? _clockNow,
      random ?? Random.secure(),
    );
    final account = await store.readCurrentAccount();
    if (account != null) await identity._load(account);
    return identity;
  }

  static DateTime _clockNow() => clock.now();

  final DeviceKeyStore _store;
  final DateTime Function() _now;
  final Random _random;
  String? _account;
  SoftwareDeviceKeys? _keys;
  DeviceRequestSigner? _signer;
  DeviceEnrolment? _enrolment;
  ({String account, Future<DeviceStatus> future})? _enrolling;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// The 18-digit check code of the current person's keys
  /// ([deviceCheckCode]), or `null` before they have keys here. It is not
  /// secret: the approver compares it with the code their own app works out
  /// from the keys the server holds.
  String? get checkCode {
    final keys = _keys;
    return keys == null
        ? null
        : deviceCheckCode(keys.signPublicKey, keys.encPublicKey);
  }

  /// The person whose keys sign now (the last one enrolled or signed in),
  /// or `null`.
  String? get userId => _account;

  /// The id the server gave the current person's device, or `null` before
  /// enrolment (and after the server no longer knew it, until it is
  /// enrolled again).
  String? get deviceId => _enrolment?.deviceId;

  /// The last status the server reported, or `null`.
  DeviceStatus? get status => _enrolment?.status;

  /// When the server last confirmed [status].
  DateTime? get checkedAt => _enrolment?.checkedAt;

  /// Whether this device is enrolled for the field user [userId] and signs
  /// for them now (with an id the server knows, as far as the phone can
  /// tell).
  bool isEnrolledFor(String userId) =>
      _account == userId && _enrolment?.deviceId != null;

  /// Whether the server no longer knew this device's earlier enrolment (for
  /// example after it was restored from an older backup), so it is set up
  /// again with the same keys and must be approved again. `false` again
  /// once it is approved.
  bool get serverForgot => _enrolment?.serverForgot ?? false;

  /// Why, as far as the phone knows, this device may not get or send data
  /// for [userId] now; `null` when it is approved. Nothing is asked of the
  /// server (see [refresh]).
  ProblemCode? knownBlocker(String userId) {
    if (!isEnrolledFor(userId)) return ProblemCode.deviceNotEnrolled;
    final known = status;
    if (known == null) return ProblemCode.deviceNotApproved;
    return known.blockerAt(_now());
  }

  /// Fires after every change of the person, the keys, the enrolment or the
  /// status.
  Stream<void> get changes => _changes.stream;

  @override
  Future<Map<String, String>> signatureHeaders(SignableRequest request) =>
      _signer?.signatureHeaders(request) ??
      Future<Map<String, String>>.value(const {});

  /// Makes sure this device is enrolled for the person signed in on
  /// [server], enrolling it under [label] and [platform] when it is not;
  /// returns its status. When it is enrolled for them already, returns the
  /// status the phone knows without asking the server.
  ///
  /// First switches to that person's own keys (making them if this is their
  /// first time on this device); every later request is signed with them.
  /// Someone who used this device before gets their own device again, as
  /// approved as it was. When the server says the keys are in use
  /// ([ProblemCode.deviceKeyInUse]: switched off, or someone else's), new
  /// keys are made for this person and enrolled once more.
  ///
  /// Throws an [ObhijatraException] (see `ObhijatraServer.enrolDevice`);
  /// [ProblemCode.signInRequired] when nobody is signed in. Calls for the
  /// same person made while one runs share it.
  Future<DeviceStatus> ensureEnrolled(
    ObhijatraServer server, {
    required String label,
    required DevicePlatform platform,
  }) {
    final user = server.currentUser;
    if (user == null || !server.hasValidSession) {
      return Future<DeviceStatus>.error(
        const ObhijatraException(ProblemCode.signInRequired),
      );
    }
    final running = _enrolling;
    if (running != null && running.account == user.id) return running.future;
    final future = _ensureEnrolled(server, user.id, label, platform);
    final entry = (account: user.id, future: future);
    _enrolling = entry;
    return future.whenComplete(() {
      if (identical(_enrolling, entry)) _enrolling = null;
    });
  }

  Future<DeviceStatus> _ensureEnrolled(
    ObhijatraServer server,
    String account,
    String label,
    DevicePlatform platform,
  ) async {
    await _use(account);
    var current = _enrolment;
    if (current != null && current.deviceId != null) {
      final known = current.status;
      if (known != null) return known;
      try {
        return await _refresh(server, enrolAgain: false);
      } on ObhijatraException catch (e) {
        if (e.code != ProblemCode.deviceUnknown) rethrow;
        current = _enrolment; // forgotten: enrolled again below
      }
    }
    // The server no longer knew this person's device: the same keys again.
    final again = current?.serverForgot ?? false;
    try {
      return await _enrol(server, account, label, platform, again: again);
    } on ObhijatraException catch (e) {
      if (e.code != ProblemCode.deviceKeyInUse || _account != account) {
        rethrow;
      }
      await _newKeys(account);
      return _enrol(server, account, label, platform, again: again);
    }
  }

  Future<DeviceStatus> _enrol(
    ObhijatraServer server,
    String account,
    String label,
    DevicePlatform platform, {
    required bool again,
  }) async {
    final keys = _keys;
    if (keys == null || _account != account) {
      throw const ObhijatraException(ProblemCode.deviceNotEnrolled);
    }
    final status = await server.enrolDevice(
      keys: keys,
      label: label,
      platform: platform,
    );
    await _save(
      account,
      DeviceEnrolment(
        deviceId: status.id,
        userId: account,
        status: status,
        checkedAt: _now().toUtc(),
        label: label.trim(),
        platform: platform,
        serverForgot: again && status.state == DeviceState.pending,
      ),
    );
    return status;
  }

  /// Asks the server where the current person's device stands, keeps the
  /// answer and returns it. A device that was switched off returns a
  /// [DeviceState.revoked] status. A device the server no longer knows
  /// ([ProblemCode.deviceUnknown]) is enrolled again with the same keys
  /// (see [recordProblem]), and its new status is returned.
  ///
  /// Throws [ProblemCode.deviceNotEnrolled] without asking when the device
  /// has no id yet, or [server] is signed in as someone else, and otherwise
  /// what `ObhijatraServer.deviceStatus` (or, for a device the server no
  /// longer knows, `enrolDevice`) throws, for example
  /// [ProblemCode.offline] or [ProblemCode.sessionEnded]; the kept status
  /// is then unchanged.
  Future<DeviceStatus> refresh(ObhijatraServer server) =>
      _refresh(server, enrolAgain: true);

  /// [refresh]; without [enrolAgain], a device the server no longer knows
  /// is only forgotten, and [ProblemCode.deviceUnknown] thrown (for
  /// [ensureEnrolled], which then enrols it again itself).
  Future<DeviceStatus> _refresh(
    ObhijatraServer server, {
    required bool enrolAgain,
  }) async {
    final account = _account;
    final current = _enrolment;
    final id = current?.deviceId;
    if (account == null ||
        current == null ||
        id == null ||
        server.currentUser?.id != account) {
      throw const ObhijatraException(ProblemCode.deviceNotEnrolled);
    }
    DeviceStatus status;
    try {
      status = await server.deviceStatus();
    } on ObhijatraException catch (e) {
      if (e.code == ProblemCode.deviceUnknown) {
        if (enrolAgain) return _enrolAgain(server, current);
        await _forget(current);
        rethrow;
      }
      if (e.code != ProblemCode.deviceRevoked) rethrow;
      status = _statusIn(current, DeviceState.revoked);
    }
    if (status.id != id) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    // The enrolment may have changed meanwhile (for example a reset).
    if (!identical(_enrolment, current)) return status;
    await _save(account, _withStatus(current, status, _now().toUtc()));
    return status;
  }

  /// Keeps what a refusal seen elsewhere (a submission, a form download, a
  /// password change) says about the current person's device:
  /// [ProblemCode.deviceNotApproved], [ProblemCode.deviceApprovalExpired]
  /// or [ProblemCode.deviceRevoked].
  ///
  /// [ProblemCode.deviceUnknown]: the server no longer knows this device.
  /// Its id is forgotten (the keys stay) and, with [server], it is enrolled
  /// again at once with the same keys: a new device that waits for approval
  /// ([serverForgot]). If that does not work now (no connection, for
  /// example), [ensureEnrolled] does it later. Unsent work is never touched.
  ///
  /// Any other code changes nothing, and so does a refusal on a [server]
  /// signed in as someone else. Never throws an [ObhijatraException].
  Future<void> recordProblem(
    ProblemCode code, {
    ObhijatraServer? server,
  }) async {
    final account = _account;
    final current = _enrolment;
    if (account == null || current == null) return;
    if (server != null && server.currentUser?.id != account) return;
    if (code == ProblemCode.deviceUnknown) {
      try {
        await _enrolAgain(server, current);
      } on ObhijatraException {
        // Not enrolled now; enrolled again later (see ensureEnrolled).
      }
      return;
    }
    final state = switch (code) {
      ProblemCode.deviceNotApproved => DeviceState.pending,
      ProblemCode.deviceApprovalExpired => DeviceState.expired,
      ProblemCode.deviceRevoked => DeviceState.revoked,
      _ => null,
    };
    if (state == null ||
        current.deviceId == null ||
        current.status?.state == state) {
      return;
    }
    await _save(
      account,
      _withStatus(current, _statusIn(current, state), current.checkedAt),
    );
  }

  /// The server no longer knows the device of [forgotten]: forgets its id
  /// (keeping the keys, the person, the label and the platform) and, with
  /// [server], enrols again with the same keys. Returns the new status;
  /// throws [ProblemCode.deviceUnknown] when it cannot enrol now for lack of
  /// a [server] or of the label and platform, and otherwise what
  /// [ensureEnrolled] throws.
  Future<DeviceStatus> _enrolAgain(
    ObhijatraServer? server,
    DeviceEnrolment forgotten,
  ) async {
    await _forget(forgotten);
    final now = _enrolment;
    final platform = now?.platform;
    if (server == null ||
        now == null ||
        platform == null ||
        now.label.isEmpty) {
      throw const ObhijatraException(ProblemCode.deviceUnknown);
    }
    return ensureEnrolled(server, label: now.label, platform: platform);
  }

  /// Forgets the current person's device on this phone: removes their keys
  /// and enrolment from the store and makes new keys, which must be
  /// enrolled and approved again ("Set up this phone again"). Other
  /// people's keys stay. The old device stays on the server until someone
  /// switches it off; without its keys it can never be used again.
  Future<void> reset() async {
    final account = _account;
    if (account != null) await _newKeys(account);
  }

  /// Stops [changes].
  Future<void> close() => _changes.close();

  /// Makes [account] the person who signs now, with their own keys (made
  /// now if they have none on this device).
  Future<void> _use(String account) async {
    if (_account != account) {
      await _store.writeCurrentAccount(account);
      await _load(account);
      _changed();
    }
    if (_keys == null && _account == account) await _newKeys(account);
  }

  /// Reads [account]'s keys and enrolment into this identity.
  Future<void> _load(String account) async {
    final seeds = await _store.readKeySeeds(account);
    final keys = seeds == null
        ? null
        : await SoftwareDeviceKeys.fromSeeds(seeds.signSeed, seeds.encSeed);
    final stored = keys == null ? null : await _store.readEnrolment(account);
    final enrolment = stored?.userId == account ? stored : null;
    _account = account;
    _keys = keys;
    _enrolment = enrolment;
    _signer = keys == null
        ? null
        : DeviceRequestSigner(
            keys,
            deviceId: enrolment?.deviceId,
            now: _now,
            random: _random,
          );
  }

  /// Replaces [account]'s keys (and forgets their enrolment) with new ones.
  Future<void> _newKeys(String account) async {
    await _store.clear(account);
    final keys = await SoftwareDeviceKeys.generate(_random);
    await _store.writeKeySeeds(
      account,
      DeviceKeySeeds(keys.signSeed, keys.encSeed),
    );
    if (_account != account) return;
    _keys = keys;
    _signer = DeviceRequestSigner(keys, now: _now, random: _random);
    _enrolment = null;
    _changed();
  }

  /// Forgets the device id of [forgotten] (if it is still the current
  /// enrolment), keeping the person, label and platform, and noting that
  /// the server no longer knew the device. The keys stay.
  Future<void> _forget(DeviceEnrolment forgotten) async {
    final account = _account;
    if (account == null ||
        !identical(_enrolment, forgotten) ||
        forgotten.deviceId == null) {
      return;
    }
    await _save(
      account,
      DeviceEnrolment(
        deviceId: null,
        userId: forgotten.userId,
        label: forgotten.label,
        platform: forgotten.platform,
        serverForgot: true,
      ),
    );
  }

  static DeviceStatus _statusIn(DeviceEnrolment current, DeviceState state) =>
      (current.status ?? DeviceStatus(id: current.deviceId!, state: state))
          .withState(state);

  /// [current] with [status], as confirmed at [checkedAt]. The note that
  /// the server had forgotten the device stays until it is approved.
  static DeviceEnrolment _withStatus(
    DeviceEnrolment current,
    DeviceStatus status,
    DateTime? checkedAt,
  ) => DeviceEnrolment(
    deviceId: current.deviceId,
    userId: current.userId,
    status: status,
    checkedAt: checkedAt,
    label: current.label,
    platform: current.platform,
    serverForgot: current.serverForgot && status.state == DeviceState.pending,
  );

  /// Stores [enrolment] for [account]; it becomes this identity's only if
  /// [account] still signs now (someone else may have signed in meanwhile).
  Future<void> _save(String account, DeviceEnrolment enrolment) async {
    await _store.writeEnrolment(account, enrolment);
    if (_account != account) return;
    _enrolment = enrolment;
    _signer?.deviceId = enrolment.deviceId;
    _changed();
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  String toString() => 'DeviceIdentity(${deviceId ?? 'not enrolled'})';
}
