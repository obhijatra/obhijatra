import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/platform/device_authenticator.dart';
import 'package:obhijatra_field/src/platform/secure_storage_key_store.dart';
import 'package:obhijatra_field/src/platform/sign_in_browser.dart';
import 'package:obhijatra_field/src/providers/device_providers.dart';
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

/// Only email and password may sign in now (see
/// [AppLockController.passwordOnly]); an SMS code or Google was refused
/// before anything was sent.
class PasswordRequired implements Exception {
  /// Creates the exception for [reason].
  const PasswordRequired(this.reason);

  /// Why the person is signing in.
  final OnlineSignInReason? reason;
}

/// The sign-in worked, but [user] signed in with a one-time password from an
/// organisation admin: they must choose their own password (see
/// `SessionNotifier.changePassword` and
/// [AppLockController.changePasswordOnline]) before anything opens. Nothing
/// is recorded until they have.
class PasswordChangeNeeded implements Exception {
  /// Creates the exception for [user].
  const PasswordChangeNeeded(this.user);

  /// Who signed in.
  final SignedInUser user;
}

/// A one-time-password sign-in from a lock screen, waiting for the person to
/// choose their own password.
final class _PendingPasswordChange {
  const _PendingPasswordChange({
    required this.address,
    required this.session,
    required this.byPassword,
  });

  /// The server it was made with.
  final Uri address;

  /// The one-time session (it may only change the password).
  final String session;

  /// Whether the person signed in with email and password (not an SMS code
  /// or Google); the app lock carries on as that sign-in would have.
  final bool byPassword;
}

/// A way to sign in with the server from a lock screen. The app lock runs it
/// itself ([AppLockController.signInOnlineWith]), so it always knows which
/// way was used: an SMS code or Google only shows that someone holds this
/// phone (the code arrives on it; the Google account may be signed in on
/// it), while a password is something the person knows.
sealed class OnlineSignIn {
  const OnlineSignIn();

  Future<SignedInUser> _signIn(ObhijatraServer server);
}

/// Email address and password.
final class PasswordSignIn extends OnlineSignIn {
  /// Creates the sign-in.
  const PasswordSignIn({required this.email, required this.password});

  /// The email address.
  final String email;

  /// The password.
  final String password;

  @override
  Future<SignedInUser> _signIn(ObhijatraServer server) =>
      server.signIn(email: email, password: password);
}

/// The code from the SMS of [request].
final class PhoneCodeSignIn extends OnlineSignIn {
  /// Creates the sign-in.
  const PhoneCodeSignIn(this.request, this.code);

  /// The code request the SMS answered.
  final PhoneCodeRequest request;

  /// The code typed.
  final String code;

  @override
  Future<SignedInUser> _signIn(ObhijatraServer server) =>
      server.signInWithPhoneCode(codeId: request.codeId, code: code);
}

/// Google, in [browser], until [cancellation].
final class GoogleBrowserSignIn extends OnlineSignIn {
  /// Creates the sign-in.
  const GoogleBrowserSignIn(this.browser, this.cancellation);

  /// The browser tab for Google's page.
  final SignInBrowser browser;

  /// Stops waiting for Google.
  final SignInCancellation cancellation;

  @override
  Future<SignedInUser> _signIn(ObhijatraServer server) =>
      signInWithGoogleIn(server, browser, cancellation);
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
  _PendingPasswordChange? _pendingChange;

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
      // Keychain outlives the app) must not lock an empty database, and its
      // device keys are not this installation's: it makes its own.
      await _lock.reset();
      await ref.read(deviceKeyStoreProvider).clearAll();
      // Anything opened from the old keys reopens with new ones.
      ref.invalidate(deviceIdentityProvider);
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
  void backToPin() {
    _pendingChange = null;
    state = const AsyncData<AppLockState>(LockLocked(UnlockMethod.pin));
  }

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

  /// Signs in with [email] and [password] while the database is still
  /// closed (see [signInOnlineWith]).
  Future<void> signInOnline({
    required String email,
    required String password,
  }) => signInOnlineWith(PasswordSignIn(email: email, password: password));

  /// Whether only email and password may sign in now, because the phone's
  /// existing unlock cannot be checked afterwards: the PIN is forgotten, or
  /// the phone has no screen lock and no app PIN. An SMS code (which
  /// arrives on this phone) or Google (whose account may be signed in on
  /// it) would then open the data to anyone holding the phone.
  Future<bool> passwordOnly() async => switch (state.value) {
    LockNeedsSignIn(reason: OnlineSignInReason.expired) =>
      await _unlockMethod() == null,
    _ => true,
  };

  /// Runs [body] with a connection to the remembered server that holds no
  /// session, for what comes before a sign-in (which ways to sign in, an
  /// SMS code), while the database is still closed.
  Future<T> withServer<T>(
    Future<T> Function(ObhijatraServer server) body,
  ) async {
    final address = await _lock.serverAddress();
    if (address == null) {
      throw const ObhijatraException(ProblemCode.unknown);
    }
    final server = ObhijatraServer(
      baseUrl: address,
      appVersion: appReleaseVersion,
      signer: await readDeviceIdentity(ref),
      httpClientFactory: ref.read(httpClientFactoryProvider),
    );
    try {
      return await body(server);
    } finally {
      server.close();
    }
  }

  /// Signs in by [signIn] (email and password, SMS code or Google) with
  /// the server while the database is still closed (see
  /// [OnlineSignInReason]). Only the account that last signed in on this
  /// phone is accepted ([WrongAccount] otherwise); failures throw an
  /// [ObhijatraException]. The new session is saved into the database once
  /// it opens.
  ///
  /// An SMS code or Google never opens the data by itself: it is refused
  /// with [PasswordRequired] when [passwordOnly], and otherwise (after 30
  /// days offline) the phone's screen lock or the app PIN must still unlock
  /// the data afterwards. Email and password work as before.
  ///
  /// An account with a one-time password throws [PasswordChangeNeeded]
  /// (after the same-account check) and records nothing: the person chooses
  /// their own password with [changePasswordOnline] first.
  Future<void> signInOnlineWith(OnlineSignIn signIn) async {
    _pendingChange = null;
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
    final byPassword = signIn is PasswordSignIn;
    if (!byPassword && await passwordOnly()) throw PasswordRequired(reason);
    String? session;
    final server = ObhijatraServer(
      baseUrl: address,
      appVersion: appReleaseVersion,
      authStore: SettingsRepository.detachedAuthStore((data) => session = data),
      // Signed once the phone is enrolled: the session is this phone's.
      signer: await readDeviceIdentity(ref),
      httpClientFactory: ref.read(httpClientFactoryProvider),
    );
    try {
      final user = await signIn._signIn(server);
      await _finishOnlineSignIn(
        server,
        user,
        () => session,
        address: address,
        reason: reason,
        byPassword: byPassword,
      );
    } finally {
      server.close();
    }
  }

  /// Chooses the person's own password in place of the one-time password
  /// of the sign-in that threw [PasswordChangeNeeded], then carries on
  /// exactly as that sign-in would have: same account only, the online
  /// sign-in recorded, and after an SMS code or Google the phone's screen
  /// lock or the app PIN still opens the data. Failures throw an
  /// [ObhijatraException]; after [ProblemCode.passwordChangedSignInAgain]
  /// or [ProblemCode.signInRequired] the person signs in again from the
  /// start.
  Future<void> changePasswordOnline({
    required String currentPassword,
    required String newPassword,
  }) async {
    final pending = _pendingChange;
    final reason = switch (state.value) {
      LockNeedsSignIn(:final reason) => reason,
      _ => null,
    };
    if (pending == null || reason == null) {
      throw const ObhijatraException(ProblemCode.signInRequired);
    }
    String? session = pending.session;
    final server = ObhijatraServer(
      baseUrl: pending.address,
      appVersion: appReleaseVersion,
      authStore: SettingsRepository.detachedAuthStore(
        (data) => session = data,
        initial: pending.session,
      ),
      signer: await readDeviceIdentity(ref),
      httpClientFactory: ref.read(httpClientFactoryProvider),
    );
    try {
      final SignedInUser user;
      try {
        // The new password is chosen from an enrolled phone (it may still
        // wait for approval).
        await enrolThisPhone(ref, server);
        user = await server.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      } on ObhijatraException catch (e) {
        if (e.code == ProblemCode.passwordChangedSignInAgain ||
            e.code == ProblemCode.signInRequired) {
          _pendingChange = null; // The one-time session has ended.
        }
        // For example, a phone the server no longer knows enrols again, so
        // trying again works.
        await recordDeviceProblem(ref, e, server);
        rethrow;
      }
      _pendingChange = null;
      await _finishOnlineSignIn(
        server,
        user,
        () => session,
        address: pending.address,
        reason: reason,
        byPassword: pending.byPassword,
      );
    } finally {
      server.close();
    }
  }

  /// Gives up the one-time-password sign-in waiting for a new password.
  void cancelPasswordChange() => _pendingChange = null;

  /// The end of every online sign-in from a lock screen: only the account
  /// that last used this phone, nothing before a one-time password is
  /// replaced, then the sign-in is recorded and the lock moves on.
  Future<void> _finishOnlineSignIn(
    ObhijatraServer server,
    SignedInUser user,
    String? Function() session, {
    required Uri address,
    required OnlineSignInReason reason,
    required bool byPassword,
  }) async {
    final last = await _lock.lastOnlineSignIn();
    if (last != null && last.userId != user.id) {
      server.signOut();
      throw const WrongAccount();
    }
    // Enrol now if this phone is not enrolled yet (for example after an
    // update from before device trust). A failure is not a sign-in failure:
    // the device screen tries again once the data is open.
    try {
      await enrolThisPhone(ref, server);
    } on ObhijatraException {
      // Shown and retried by the device screen.
    }
    final saved = session();
    if (user.mustChangePassword) {
      if (saved == null) {
        throw const ObhijatraException(ProblemCode.unexpectedResponse);
      }
      _pendingChange = _PendingPasswordChange(
        address: address,
        session: saved,
        byPassword: byPassword,
      );
      throw PasswordChangeNeeded(user);
    }
    _pendingSession = saved;
    await _lock.recordOnlineSignIn(user.id);
    state = AsyncData<AppLockState>(
      byPassword
          ? await _afterOnlineSignIn(
              newPin: reason == OnlineSignInReason.forgotPin,
            )
          // Holding the phone is not enough: its screen lock or the app
          // PIN opens the data, as on any other day.
          : await _evaluate(),
    );
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
