import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_device/obhijatra_device.dart' show deviceCheckCode;
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/device/device_label.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';
import 'package:obhijatra_manager/src/device/platform.dart';
import 'package:obhijatra_manager/src/state/providers.dart';

/// Where this device stands for the person signed in.
enum DeviceStage {
  /// Approved: the app can be used.
  ready,

  /// Enrolled and waiting for approval (or for a second org admin).
  waiting,

  /// Approved before, but the approval has run out.
  expired,

  /// Switched off: it must be set up again as a new device.
  revoked,

  /// The server does not recognise the device's keys (for example after
  /// the server was set up again).
  notRecognised,

  /// The computer's clock is more than 5 minutes from the server's.
  clockWrong,

  /// The browser cannot keep device keys: it must be updated.
  updateBrowser,

  /// The page was opened at a plain `http` address, where browsers keep no
  /// keys.
  secureAddressNeeded,

  /// The check met a problem that no earlier answer may hide
  /// ([DeviceGate.problem]): the session ended or belongs to another
  /// device, too many devices wait, or the check had already changed this
  /// device (its signature or its id) when it failed.
  problem,
}

/// The device check's answer for one person.
@immutable
class DeviceGate {
  /// Creates the answer.
  const DeviceGate({
    required this.userId,
    required this.stage,
    this.deviceId,
    this.checkCode = '',
    this.label = '',
    this.needsSecondApproval = false,
    this.checkedAt,
    this.serverForgot = false,
    this.problem,
  });

  /// Nobody is signed in.
  const DeviceGate.signedOut()
    : userId = null,
      stage = DeviceStage.ready,
      deviceId = null,
      checkCode = '',
      label = '',
      needsSecondApproval = false,
      checkedAt = null,
      serverForgot = false,
      problem = null;

  /// Whose device check this is.
  final String? userId;

  /// What the app shows.
  final DeviceStage stage;

  /// The server's id for this device, once enrolled.
  final String? deviceId;

  /// This device's own 18-digit check code, for the person to read out to
  /// an approver. Empty when there are no keys.
  final String checkCode;

  /// The device's name.
  final String label;

  /// An org admin's device approved once, waiting for a second.
  final bool needsSecondApproval;

  /// When the server last answered about this device.
  final DateTime? checkedAt;

  /// The server no longer knew this device (for example, it was restored
  /// from an older backup), so the same keys were enrolled again and wait
  /// for approval again.
  final bool serverForgot;

  /// What went wrong, for [DeviceStage.problem].
  final AppProblem? problem;

  @override
  String toString() => 'DeviceGate($stage)';
}

/// Checks this device with the server whenever someone signs in, and again
/// when asked (Check again, every 15 seconds while waiting, or after the
/// server refused a request because of the device).
///
/// With no keys for the person, it makes them and enrols the device. It
/// then signs every request with them.
class DeviceGateNotifier extends AsyncNotifier<DeviceGate> {
  @override
  Future<DeviceGate> build() async {
    ref.watch(deviceRecheckProvider);
    final userId = ref.watch(sessionProvider.select((user) => user?.id));
    if (userId == null) return const DeviceGate.signedOut();
    try {
      return await _check(userId);
    } on _Superseded {
      // Someone else signed in, or a newer check runs: this answer is about
      // nobody signed in now, so it opens nothing.
      return const DeviceGate.signedOut();
    }
  }

  Future<DeviceGate> _check(String userId) async {
    final store = ref.read(deviceIdentityStoreProvider);
    final signer = ref.read(deviceSignerProvider);
    final api = ref.read(apiProvider);
    final reEnrolment = ref.read(reEnrolmentProvider);

    /// Stops this check once it no longer matters: a newer check runs, or
    /// someone else has signed in meanwhile. Called after every wait and
    /// before anything changes, so a stale check never signs, enrols or
    /// stores anything for the wrong person.
    void stillCurrent() {
      if (!ref.mounted || ref.read(sessionProvider)?.id != userId) {
        throw const _Superseded();
      }
    }

    final support = await store.support();
    stillCurrent();
    switch (support) {
      case KeyStoreSupport.updateBrowser:
        signer.clear();
        return DeviceGate(userId: userId, stage: DeviceStage.updateBrowser);
      case KeyStoreSupport.secureAddressNeeded:
        signer.clear();
        return DeviceGate(
          userId: userId,
          stage: DeviceStage.secureAddressNeeded,
        );
      case KeyStoreSupport.supported:
        break;
    }

    final stored = await store.load(userId);
    stillCurrent();
    var identity = stored ?? await store.create(userId);
    stillCurrent();
    try {
      // Written only when it changes: this runs every 15 seconds while the
      // device waits.
      if (await store.lastAccount() != userId) {
        stillCurrent();
        await store.rememberLastAccount(userId);
      }
    } on _Superseded {
      rethrow;
    } on Object {
      // Only the next sign-in's signature depends on it.
    }
    stillCurrent();
    final platform = currentDevicePlatform();
    final label = deviceLabel(platform, userAgent: platformUserAgent());

    DeviceGate gate(
      DeviceStage stage, {
      DeviceView? view,
      AppProblem? problem,
    }) => DeviceGate(
      userId: userId,
      stage: stage,
      deviceId: identity.deviceId,
      checkCode: deviceCheckCode(
        identity.keys.signPublicKey,
        identity.keys.encPublicKey,
      ),
      label: view?.label ?? label,
      needsSecondApproval: view?.needsSecondApproval ?? false,
      checkedAt: ref.read(deviceClockProvider)(),
      serverForgot: reEnrolment.devices.contains(identity.deviceId),
      problem: problem,
    );

    // Whether this check has changed the device (cleared its signature or
    // forgotten its id): an earlier answer then no longer holds.
    var changed = false;

    /// Enrols [identity]'s keys; nothing is signed as this device before
    /// the server knows it.
    Future<DeviceView> enrol() async {
      changed = true;
      signer.clear();
      final keys = identity.keys;
      final view = await trackedDeviceCheck(
        ref,
        () => api.enrolDevice(
          userId: userId,
          keys: keys,
          label: label,
          platform: platform,
        ),
      );
      stillCurrent();
      identity = await store.saveDeviceId(userId, view.id);
      stillCurrent();
      signer.use(identity);
      // Enrolled again because the server had forgotten the device (also
      // when that took a second try, or signing in again).
      if (reEnrolment.accounts.remove(userId)) {
        reEnrolment.devices.add(view.id);
      }
      return view;
    }

    try {
      DeviceView view;
      if (identity.deviceId == null) {
        view = await enrol();
      } else {
        signer.use(identity);
        try {
          view = await trackedDeviceCheck(ref, api.myDevice);
          stillCurrent();
        } on AppProblem catch (problem) {
          if (problem.kind != ProblemKind.deviceUnknown) rethrow;
          stillCurrent();
          // The server no longer knows this device (for example, it was
          // restored from an older backup). The same keys are enrolled
          // again, once, and wait for approval again.
          changed = true;
          signer.clear();
          reEnrolment.accounts.add(userId);
          identity = await store.forgetDeviceId(userId);
          stillCurrent();
          view = await enrol();
        }
      }
      return gate(switch (view.status) {
        DeviceStatus.active when !view.approvalExpired => DeviceStage.ready,
        DeviceStatus.active => DeviceStage.expired,
        DeviceStatus.pending => DeviceStage.waiting,
        DeviceStatus.revoked => DeviceStage.revoked,
        DeviceStatus.unknown => DeviceStage.notRecognised,
      }, view: view);
    } on _Superseded {
      rethrow;
    } on Object catch (error) {
      final problem = problemFrom(error);
      final stage = switch (problem.kind) {
        ProblemKind.deviceRevoked => DeviceStage.revoked,
        ProblemKind.deviceExpired => DeviceStage.expired,
        ProblemKind.deviceNotApproved => DeviceStage.waiting,
        ProblemKind.deviceClock => DeviceStage.clockWrong,
        ProblemKind.deviceCheckFailed ||
        ProblemKind.deviceNotSetUp ||
        ProblemKind.deviceUnknown ||
        ProblemKind.deviceKeyInUse => DeviceStage.notRecognised,
        _ => null,
      };
      if (stage != null) return gate(stage);
      // Shown as it is, never hidden behind an earlier answer such as
      // "ready": the session has ended or is another device's, too many
      // devices wait, or this check has already changed the device.
      if (changed ||
          problem.action == ProblemAction.signInAgain ||
          problem.kind == ProblemKind.tooManyWaitingDevices) {
        return gate(DeviceStage.problem, problem: problem);
      }
      // Nothing changed (for example, offline): the last answer stays on
      // screen with the problem beside it.
      rethrow;
    }
  }

  /// Asks the server about this device again.
  void checkAgain() => ref.invalidateSelf();

  /// Forgets the signed-in person's keys on this device, makes new ones and
  /// enrols the device afresh. It then waits for approval.
  Future<void> setUpAgain() async {
    final userId = ref.read(sessionProvider)?.id;
    if (userId == null) return;
    ref.read(deviceSignerProvider).clear();
    try {
      await ref.read(deviceIdentityStoreProvider).wipe(userId);
    } on Object catch (error, stack) {
      state = AsyncError<DeviceGate>(problemFrom(error), stack);
      return;
    }
    ref.invalidateSelf();
  }
}

/// What the device check remembers about devices the server no longer
/// knew, for the server in use, so the waiting screen can say why it waits
/// (also after a check every 15 seconds, a second try or signing in again).
class ReEnrolment {
  /// The people whose device id was forgotten and who are not enrolled
  /// again yet.
  final Set<String> accounts = <String>{};

  /// The ids the server gave those devices when they were enrolled again.
  final Set<String> devices = <String>{};
}

/// Holds the [ReEnrolment] for the server in use.
final reEnrolmentProvider = Provider<ReEnrolment>((ref) {
  ref.watch(serverUrlProvider);
  return ReEnrolment();
});

/// A device check that stopped because it no longer matters.
class _Superseded implements Exception {
  const _Superseded();
}

/// This device's standing for the person signed in.
final deviceGateProvider =
    AsyncNotifierProvider<DeviceGateNotifier, DeviceGate>(
      DeviceGateNotifier.new,
    );

/// The tabs of the Devices screen.
enum DevicesTab {
  /// The devices of other people (to approve or switch off).
  others,

  /// The signed-in person's own devices.
  mine,
}

/// The tab shown on the Devices screen. Starts again for each person who
/// signs in.
class DevicesTabNotifier extends Notifier<DevicesTab> {
  @override
  DevicesTab build() {
    ref.watch(sessionProvider.select((user) => user?.id));
    return DevicesTab.others;
  }

  /// Shows [tab].
  void show(DevicesTab tab) => state = tab;
}

/// Holds the tab shown on the Devices screen.
final devicesTabProvider = NotifierProvider<DevicesTabNotifier, DevicesTab>(
  DevicesTabNotifier.new,
);

/// Every device the signed-in person may see, newest first.
final devicesProvider = FutureProvider.autoDispose<List<DeviceRecord>>((ref) {
  ref.watch(sessionProvider.select((user) => user?.id));
  return tracked(ref, () => ref.read(apiProvider).listDevices());
});

/// When the Devices screen's lists were worked out, so "approval ran out"
/// is judged the same way for every row. Tests replace it.
final deviceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
