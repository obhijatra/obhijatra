import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// What came of asking the phone's own screen lock.
enum DeviceUnlockResult {
  /// The person unlocked.
  unlocked,

  /// The person closed the prompt, or it timed out or was interrupted.
  cancelled,

  /// The phone has no screen lock (any more).
  noScreenLock,

  /// The phone's lock is paused after too many wrong tries.
  lockedOut,

  /// Something else went wrong on the phone.
  failed,
}

/// The words of the phone's own unlock prompt, in the app's language.
class DevicePromptText {
  /// Creates the words.
  const DevicePromptText({
    required this.title,
    required this.reason,
    required this.cancel,
  });

  /// The prompt's title (Android).
  final String title;

  /// Why the app asks (shown under the title, and by iOS).
  final String reason;

  /// The cancel button.
  final String cancel;
}

/// The phone's own screen lock: PIN, pattern, password, fingerprint or face.
abstract interface class DeviceAuthenticator {
  /// Whether the phone has a screen lock set.
  Future<bool> hasScreenLock();

  /// Asks the person to unlock with the phone's screen lock (biometrics, with
  /// the phone's PIN, pattern or password as a fallback).
  Future<DeviceUnlockResult> unlock(DevicePromptText text);
}

/// [DeviceAuthenticator] through the `local_auth` plugin.
final class LocalAuthAuthenticator implements DeviceAuthenticator {
  /// Creates the authenticator. Pass [auth] only in tests.
  LocalAuthAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> hasScreenLock() async {
    try {
      // Android: a secure keyguard or enrolled biometrics (which need a
      // screen lock); iOS: a passcode is set.
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<DeviceUnlockResult> unlock(DevicePromptText text) async {
    try {
      final unlocked = await _auth.authenticate(
        localizedReason: text.reason,
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: text.title,
            cancelButton: text.cancel,
          ),
          IOSAuthMessages(cancelButton: text.cancel),
        ],
      );
      return unlocked
          ? DeviceUnlockResult.unlocked
          : DeviceUnlockResult.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet =>
          DeviceUnlockResult.noScreenLock,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => DeviceUnlockResult.lockedOut,
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.authInProgress ||
        LocalAuthExceptionCode.userRequestedFallback =>
          DeviceUnlockResult.cancelled,
        _ => DeviceUnlockResult.failed,
      };
    } on PlatformException {
      return DeviceUnlockResult.failed;
    }
  }
}
