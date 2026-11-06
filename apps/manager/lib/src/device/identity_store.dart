import 'package:obhijatra_device/obhijatra_device.dart';

/// One person's keys on this device, and the id the server gave the device
/// when it was enrolled (null until then).
///
/// Keys belong to one person: the server ties a device to the person who
/// enrolled it, so on a shared computer each person has their own.
class DeviceIdentity {
  /// Creates the identity.
  const DeviceIdentity({required this.keys, this.deviceId});

  /// The device's keys. The private keys never leave the platform's
  /// protected storage.
  final DeviceKeys keys;

  /// The server's id for this device, or null before enrolment.
  final String? deviceId;

  /// The same keys with the server's [id].
  DeviceIdentity withDeviceId(String id) =>
      DeviceIdentity(keys: keys, deviceId: id);

  @override
  String toString() => 'DeviceIdentity(<redacted>)';
}

/// Whether this platform can keep device keys safely.
enum KeyStoreSupport {
  /// Yes.
  supported,

  /// The browser has no Ed25519 or X25519 in its Web Cryptography API
  /// (Chrome and Edge before 137, Firefox before 130, Safari before 17).
  updateBrowser,

  /// The page was not opened at a secure (https) address, where browsers
  /// switch their cryptography off.
  secureAddressNeeded,
}

/// The device's keys could not be made or kept: protected storage refused
/// (for example a private browser window that keeps no data).
class DeviceKeysUnavailable implements Exception {
  /// Creates the exception.
  const DeviceKeysUnavailable();

  @override
  String toString() => 'DeviceKeysUnavailable';
}

/// Keeps device keys and device ids, one set per person, for one server.
///
/// - Windows and macOS: the seeds in the operating system's protected
///   storage (DPAPI, the Keychain), through `flutter_secure_storage`.
/// - Web: non-extractable WebCrypto keys in the browser's IndexedDB. The
///   private keys cannot be read out, even by the app itself.
///
/// Every method throws [DeviceKeysUnavailable] when the storage fails.
abstract interface class DeviceIdentityStore {
  /// Whether keys can be made and kept here. Asked before anything else.
  Future<KeyStoreSupport> support();

  /// [account]'s identity, or null when there is none.
  Future<DeviceIdentity?> load(String account);

  /// Makes new keys for [account], keeps them (without a device id) and
  /// returns them, replacing any it had.
  Future<DeviceIdentity> create(String account);

  /// Records the server's [deviceId] for [account]'s keys.
  Future<DeviceIdentity> saveDeviceId(String account, String deviceId);

  /// Forgets the server's device id for [account] and keeps the same keys,
  /// so they can be enrolled again (when the server no longer knows the
  /// device). Throws [DeviceKeysUnavailable] when there are no keys.
  Future<DeviceIdentity> forgetDeviceId(String account);

  /// Forgets [account]'s keys and device id for good.
  Future<void> wipe(String account);

  /// The person who last used this device with this server, or null. Their
  /// keys sign the next sign-in, so the new session is tied to the device
  /// at once.
  Future<String?> lastAccount();

  /// Records [account] as the last to use this device with this server.
  Future<void> rememberLastAccount(String account);
}
