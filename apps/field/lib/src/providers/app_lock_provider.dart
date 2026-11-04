import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/platform/device_authenticator.dart';
import 'package:obhijatra_field/src/platform/secure_storage_key_store.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';

/// Where the app lock keeps its values (next to the database key).
final secureValuesProvider = Provider<SecureValueStore>(
  (ref) => SecureStorageValues(),
);

/// The phone's own screen lock.
final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalAuthAuthenticator(),
);

/// Runs PIN hashing off the screen's thread; tests run it in place.
final pinComputeProvider = Provider<ComputeRunner>((ref) => runInBackground);

/// Runs [work] on a short-lived background isolate.
Future<R> runInBackground<R>(R Function() work) => Isolate.run(work);

/// The app lock's rules and stored values.
final appLockStoreProvider = Provider<AppLock>(
  (ref) => AppLock(
    ref.watch(secureValuesProvider),
    compute: ref.watch(pinComputeProvider),
    now: ref.watch(nowProvider),
  ),
);

/// How the person opens the data on a phone that has been used before.
enum UnlockMethod {
  /// The phone's own screen lock.
  device,

  /// The app PIN (the phone has no screen lock).
  pin,
}

/// Why the person must sign in with the server before the data opens.
enum OnlineSignInReason {
  /// More than 30 days since the last online sign-in, or the phone's clock
  /// went back before it.
  expired,

  /// The phone has no screen lock and no app PIN.
  noUnlockMethod,

  /// The person forgot the app PIN.
  forgotPin,
}

/// What stands between the person and the data.
@immutable
sealed class AppLockState {
  const AppLockState();

  /// Whether the device database may be open in this state.
  bool get opensData;
}

/// First use (no online sign-in recorded): the database opens, but nothing
/// of it is shown before the person connects and signs in.
final class LockFresh extends AppLockState {
  /// Creates the state.
  const LockFresh();

  @override
  bool get opensData => true;
}

/// Unlocked: the app works as usual.
final class LockOpen extends AppLockState {
  /// Creates the state.
  const LockOpen();

  @override
  bool get opensData => true;
}

/// Locked; [method] opens it.
final class LockLocked extends AppLockState {
  /// Creates the state.
  const LockLocked(this.method);

  /// How to unlock.
  final UnlockMethod method;

  @override
  bool get opensData => false;
}

/// An online sign-in (same account as before) is needed first.
final class LockNeedsSignIn extends AppLockState {
  /// Creates the state.
  const LockNeedsSignIn(this.reason);

  /// Why.
  final OnlineSignInReason reason;

  @override
  bool get opensData => false;
}

/// The phone has no screen lock: the person must choose an app PIN.
final class LockNeedsPin extends AppLockState {
  /// Creates the state.
  const LockNeedsPin();

  @override
  bool get opensData => false;
}

/// Somebody else's account signed in where only the account that last used
/// this phone may.
class WrongAccount implements Exception {
  /// Creates the exception.
  const WrongAccount();
}

/// The app lock: decides at start and on return from the background what
/// the person must do before the device database opens.
final appLockProvider = AsyncNotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

/// Runs the app lock (see [AppLockState]).
class AppLockController extends AsyncNotifier<AppLockState> {
  DateTime? _backgroundedAt;
  String? _pendingSession;

  AppLock get _lock => ref.read(appLockStoreProvider);

  DateTime _now() => ref.read(nowProvider)();

  @override
  Future<AppLockState> build() async {
    final listener = AppLifecycleListener(
      onHide: _wentToBackground,
      onPause: _wentToBackground,
      onResume: _cameBack,
    );
    ref.onDispose(listener.dispose);

    final opener = await ref.read(databaseOpenerProvider.future);
    if (!await opener.databaseExists()) {
      // A new install: entries that survived an earlier one (an iOS
      // Keychain outlives the app) must not lock an empty database.
      await _lock.reset();
      return const LockFresh();
    }
    return _evaluate();
  }

  /// What the person must do now, the database being closed.
  Future<AppLockState> _evaluate() async {
    final last = await _lock.lastOnlineSignIn();
    // No online sign-in yet: the database holds no field data, and the
    // fresh path shows none before an online sign-in.
    if (last == null) return const LockFresh();
    if (_lock.mustSignInOnline(last)) {
      return const LockNeedsSignIn(OnlineSignInReason.expired);
    }
    final method = await _unlockMethod();
    return method == null
        ? const LockNeedsSignIn(OnlineSignInReason.noUnlockMethod)
        : LockLocked(method);
  }

  Future<UnlockMethod?> _unlockMethod() async {
    if (await ref.read(deviceAuthenticatorProvider).hasScreenLock()) {
      return UnlockMethod.device;
    }
    return await _lock.hasPin() ? UnlockMethod.pin : null;
  }

  /// Opens the data after an unlock, unless the offline limit has passed
  /// meanwhile.
  Future<void> _unlocked() async {
    final last = await _lock.lastOnlineSignIn();
    state = AsyncData<AppLockState>(
      _lock.mustSignInOnline(last)
          ? const LockNeedsSignIn(OnlineSignInReason.expired)
          : const LockOpen(),
    );
  }

  /// Asks the phone's screen lock; opens the data when it unlocks.
  Future<DeviceUnlockResult> unlockWithDevice(DevicePromptText text) async {
    final result = await ref.read(deviceAuthenticatorProvider).unlock(text);
    switch (result) {
      case DeviceUnlockResult.unlocked:
        await _unlocked();
      case DeviceUnlockResult.noScreenLock:
        // The screen lock was removed: fall back to the PIN, or sign in.
        state = AsyncData<AppLockState>(await _evaluate());
      case DeviceUnlockResult.cancelled ||
          DeviceUnlockResult.lockedOut ||
          DeviceUnlockResult.failed:
        break;
    }
    return result;
  }

  /// Checks the app PIN; opens the data when it is right.
  Future<PinCheck> unlockWithPin(String pin) async {
    final result = await _lock.checkPin(pin);
    if (result is PinAccepted) await _unlocked();
    return result;
  }

  /// When the next PIN try is allowed, while a wait runs.
  Future<DateTime?> pinWaitUntil() => _lock.pinWaitUntil();

  /// The person forgot the app PIN: an online sign-in replaces it.
  void forgotPin() => state = const AsyncData<AppLockState>(
    LockNeedsSignIn(OnlineSignInReason.forgotPin),
  );

  /// Back from "forgot PIN" to the PIN.
  void backToPin() =>
      state = const AsyncData<AppLockState>(LockLocked(UnlockMethod.pin));

  /// Stores [pin] as the app PIN and opens the data.
  Future<void> choosePin(String pin) async {
    await _lock.setPin(pin);
    state = const AsyncData<AppLockState>(LockOpen());
  }

  /// The server address for an online sign-in before the database opens.
  Future<Uri?> serverAddress() => _lock.serverAddress();

  /// Remembers [address] for an online sign-in before the database opens.
  Future<void> rememberServerAddress(Uri address) =>
      _lock.rememberServerAddress(address);

  /// Records that [user] signed in with the server through the app's own
  /// sign-in screen (the database is open), and asks for an app PIN if the
  /// phone has no screen lock and no PIN yet.
  Future<void> signedInOnline(SignedInUser user) async {
    await _lock.recordOnlineSignIn(user.id);
    state = AsyncData<AppLockState>(await _afterOnlineSignIn(newPin: false));
  }

  /// Signs in with the server while the database is still closed (see
  /// [OnlineSignInReason]). Only the account that last signed in on this
  /// phone is accepted ([WrongAccount] otherwise); failures throw an
  /// [ObhijatraException]. The new session is saved into the database once
  /// it opens.
  Future<void> signInOnline({
    required String email,
    required String password,
  }) async {
    final reason = switch (state.value) {
      LockNeedsSignIn(:final reason) => reason,
      _ => null,
    };
    final address = await _lock.serverAddress();
    if (reason == null || address == null) {
      // Not expected: without a remembered address the first-use path,
      // which shows nothing before an online sign-in, takes over.
      state = const AsyncData<AppLockState>(LockFresh());
      return;
    }
    String? session;
    final server = ObhijatraServer(
      baseUrl: address,
      appVersion: appReleaseVersion,
      authStore: SettingsRepository.detachedAuthStore((data) => session = data),
      httpClientFactory: ref.read(httpClientFactoryProvider),
    );
    try {
      final user = await server.signIn(email: email, password: password);
      final last = await _lock.lastOnlineSignIn();
      if (last != null && last.userId != user.id) {
        server.signOut();
        throw const WrongAccount();
      }
      _pendingSession = session;
      await _lock.recordOnlineSignIn(user.id);
      state = AsyncData<AppLockState>(
        await _afterOnlineSignIn(
          newPin: reason == OnlineSignInReason.forgotPin,
        ),
      );
    } finally {
      server.close();
    }
  }

  /// The session of an online sign-in made while the database was closed,
  /// once; the database provider saves it.
  String? takePendingSession() {
    final session = _pendingSession;
    _pendingSession = null;
    return session;
  }

  Future<AppLockState> _afterOnlineSignIn({required bool newPin}) async {
    if (await ref.read(deviceAuthenticatorProvider).hasScreenLock()) {
      return const LockOpen();
    }
    return newPin || !await _lock.hasPin()
        ? const LockNeedsPin()
        : const LockOpen();
  }

  void _wentToBackground() {
    if (state.value is LockOpen) _backgroundedAt ??= _now();
  }

  void _cameBack() {
    final away = _backgroundedAt;
    _backgroundedAt = null;
    if (away == null || state.value is! LockOpen) return;
    if (AppLock.relockDue(away, _now())) unawaited(_relock());
  }

  Future<void> _relock() async {
    state = AsyncData<AppLockState>(await _evaluate());
  }
}
