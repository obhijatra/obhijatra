import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/platform/secure_storage_key_store.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';

// Device trust (docs/decisions/0008-device-trust.md) in the field app.
//
// The order:
//
// 1. Start: [deviceIdentityProvider] reads this phone's keys, or makes
//    them: once per installation (a new installation starts without the
//    keys an earlier one left behind), before the first sign-in. Every
//    server connection signs with them.
// 2. Sign-in: right after it, the phone enrols if it is not enrolled for
//    this person ([enrolThisPhone]). A person with a one-time password
//    enrols, then chooses the new password from the waiting phone. If
//    enrolment does not work (no signal, for example), the person is still
//    signed in and the device screen ([DeviceTrustNotifier.check]) retries.
// 3. [DeviceGate] shows the app once the phone is approved; until then the
//    waiting screen, which checks every 15 seconds. The last answer is kept
//    on the phone, so offline the app knows where it stands. When there are
//    forms on the phone, the person may fill them in meanwhile; nothing is
//    sent before the approval (the sync engine checks).
// 4. "Set up this phone again" (switched off) forgets the keys, the
//    enrolment and the session; the person signs in and enrols anew.
//
// The session and the app lock read the identity, never the other way
// round: [deviceIdentityProvider] depends on nothing but its store, and
// [deviceTrustProvider] (which watches the session) is read only by
// screens. Riverpod treats reading a provider that depends on you as a
// circular dependency.

/// Where this phone's device identity is kept.
final deviceKeyStoreProvider = Provider<DeviceKeyStore>(
  (ref) => SecureStorageDeviceKeyStore(),
);

/// This phone's device identity: its keys (made on first use), enrolment
/// and request signer. Lives as long as the app.
///
/// It depends on nothing but its store: the app lock and the session read
/// it, never the other way round. On a new installation the app lock clears
/// what an earlier one left in the store (an iOS Keychain outlives the app)
/// and invalidates this provider, so the identity then opened has keys of
/// its own.
final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  final identity = await DeviceIdentity.open(ref.watch(deviceKeyStoreProvider));
  if (!ref.mounted) {
    // Invalidated while opening: this one is never used.
    unawaited(identity.close());
    return identity;
  }
  ref.onDispose(() => unawaited(identity.close()));
  return identity;
});

/// This phone's device identity, at once when it is open (as it nearly
/// always is), otherwise once it has opened. For code that only uses it,
/// such as signing in; providers built on it watch [deviceIdentityProvider].
Future<DeviceIdentity> readDeviceIdentity(Ref ref) async =>
    ref.read(deviceIdentityProvider).value ??
    await ref.read(deviceIdentityProvider.future);

/// Keeps what the device-trust refusal [error] says on this phone's
/// identity (see [DeviceIdentity.recordProblem]): for example, a phone the
/// server no longer knows forgets its device id and enrols again at once on
/// [server], with the same keys. Other problems change nothing.
Future<void> recordDeviceProblem(
  Ref ref,
  ObhijatraException error,
  ObhijatraServer server,
) async {
  if (!error.code.isDeviceProblem) return;
  final identity = await readDeviceIdentity(ref);
  await identity.recordProblem(error.code, server: server);
}

/// Enrols this phone for the person signed in on [server], unless it is
/// enrolled for them already (see [DeviceIdentity.ensureEnrolled]).
/// After the server forgot the phone, it enrols again with the same keys.
Future<DeviceStatus> enrolThisPhone(Ref ref, ObhijatraServer server) async {
  final identity = await readDeviceIdentity(ref);
  final platform = ref.read(devicePlatformProvider);
  return identity.ensureEnrolled(
    server,
    label: deviceLabelFor(platform),
    platform: platform,
  );
}

/// The kind of phone, as the server records it.
final devicePlatformProvider = Provider<DevicePlatform>(
  (ref) => Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android,
);

/// The name an approver sees for this phone (with the person's name and
/// the platform beside it).
String deviceLabelFor(DevicePlatform platform) =>
    platform == DevicePlatform.ios ? 'Field app, iPhone' : 'Field app, Android';

/// Where this phone stands, as the screens show it.
enum DevicePhase {
  /// Approved: the app works as usual.
  approved,

  /// Not enrolled for the signed-in person yet: the phone sets itself up.
  settingUp,

  /// Enrolled and waiting for approval.
  waiting,

  /// The approval has run out; it must be approved again.
  renewal,

  /// Switched off; it must be set up again.
  switchedOff,
}

/// What the device screens show.
@immutable
class DeviceTrustState {
  /// Creates the state.
  const DeviceTrustState({
    required this.phase,
    required this.code,
    this.status,
    this.checkedAt,
    this.problem,
    this.checking = false,
    this.deferred = false,
    this.serverForgot = false,
  });

  /// Where the phone stands.
  final DevicePhase phase;

  /// The phone's 18-digit check code.
  final String code;

  /// The last status the server reported, if any.
  final DeviceStatus? status;

  /// When the server last confirmed [status].
  final DateTime? checkedAt;

  /// Why the last check or enrolment did not work, if it did not.
  final ProblemCode? problem;

  /// Whether a check or enrolment the person asked for is running (the
  /// automatic checks run quietly, so nothing on screen flickers).
  final bool checking;

  /// Whether the person chose to fill in forms on the phone before it is
  /// approved.
  final bool deferred;

  /// Whether the server no longer knew this phone, so it is set up again
  /// with the same numbers and needs approval again.
  final bool serverForgot;
}

/// This phone's place in device trust, kept up to date.
final deviceTrustProvider =
    AsyncNotifierProvider<DeviceTrustNotifier, DeviceTrustState>(
      DeviceTrustNotifier.new,
    );

/// Enrols and checks this phone, and says where it stands.
class DeviceTrustNotifier extends AsyncNotifier<DeviceTrustState> {
  ProblemCode? _problem;
  bool _checking = false;
  bool _showChecking = false;
  bool _deferred = false;
  DeviceIdentity? _identity;

  @override
  Future<DeviceTrustState> build() async {
    final identity = await ref.watch(deviceIdentityProvider.future);
    ref.watch(sessionProvider.select((user) => user?.id));
    _identity = identity;
    _problem = null;
    _checking = false;
    _showChecking = false;
    _deferred = false;
    final changes = identity.changes.listen((_) => _publish());
    ref.onDispose(changes.cancel);
    return _stateOf(identity);
  }

  DeviceTrustState _stateOf(DeviceIdentity identity) {
    final user = ref.read(sessionProvider);
    return DeviceTrustState(
      phase: _phaseOf(identity, user),
      code: identity.checkCode,
      status: identity.status,
      checkedAt: identity.checkedAt,
      problem: _problem,
      checking: _showChecking,
      deferred: _deferred,
      serverForgot: identity.serverForgot,
    );
  }

  DevicePhase _phaseOf(DeviceIdentity identity, SignedInUser? user) {
    if (user == null || !identity.isEnrolledFor(user.id)) {
      return DevicePhase.settingUp;
    }
    final status = identity.status;
    return switch (status?.state) {
      null || DeviceState.pending => DevicePhase.waiting,
      DeviceState.expired => DevicePhase.renewal,
      DeviceState.revoked => DevicePhase.switchedOff,
      DeviceState.active =>
        status!.usableAt(ref.read(nowProvider)())
            ? DevicePhase.approved
            : DevicePhase.renewal,
    };
  }

  void _publish() {
    final identity = _identity;
    if (identity == null || !ref.mounted) return;
    final before = state.value?.phase;
    var next = _stateOf(identity);
    if (_deferred &&
        next.phase == DevicePhase.switchedOff &&
        before != DevicePhase.switchedOff) {
      // Switched off: the screen that says so takes over from the forms.
      _deferred = false;
      next = _stateOf(identity);
    }
    state = AsyncData<DeviceTrustState>(next);
    if (before != null &&
        before != DevicePhase.approved &&
        next.phase == DevicePhase.approved) {
      // Approved: send what waits and get the forms at once.
      unawaited(_syncAndRefresh());
    }
  }

  Future<void> _syncAndRefresh() async {
    try {
      final engine = await ref.read(syncEngineProvider.future);
      unawaited(engine?.syncNow(ignoreBackoff: true));
      await ref.read(formsRefreshProvider.notifier).refresh();
    } on Object {
      // Sync never throws; the app may be closing.
    }
  }

  /// Asks the server again where this phone stands; enrols it first when
  /// it is not enrolled for the signed-in person. Never throws: a problem
  /// is shown on the device screen. [quietly] for the automatic checks: the
  /// screen shows no "Checking…" for them. One check runs at a time.
  Future<void> check({bool quietly = false}) async {
    final identity = _identity;
    final user = ref.read(sessionProvider);
    final server = ref.read(serverProvider).value?.server;
    if (identity == null || user == null || server == null || _checking) {
      return;
    }
    _checking = true;
    _showChecking = !quietly;
    if (!quietly) _publish();
    try {
      if (identity.isEnrolledFor(user.id)) {
        await identity.refresh(server);
      } else {
        await enrolThisPhone(ref, server);
      }
      _problem = null;
    } on ObhijatraException catch (e) {
      _problem = e.code;
    } on Object {
      _problem = ProblemCode.unknown;
    } finally {
      _checking = false;
      _showChecking = false;
      _publish();
    }
  }

  /// The person chose to fill in forms before the phone is approved.
  void fillInFormsMeanwhile() {
    _deferred = true;
    _publish();
  }

  /// "Set up this phone again": forgets this phone's keys, enrolment and
  /// session, and makes new keys. The person then signs in, and the phone
  /// enrols as a new device. Unsent forms and drafts stay.
  Future<void> setUpAgain() async {
    final identity = await readDeviceIdentity(ref);
    await identity.reset();
    ref.read(sessionProvider.notifier).signOut();
  }
}
