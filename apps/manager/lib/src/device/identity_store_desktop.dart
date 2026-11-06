import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';

/// The identity store of the desktop builds: the two key seeds in the
/// operating system's protected storage.
DeviceIdentityStore platformIdentityStore(String server) =>
    SecureStorageIdentityStore(server);

/// The browser's description of itself; there is none on the desktop.
String platformUserAgent() => '';

/// Keeps each person's two 32-byte seeds in the operating system's
/// protected storage through `flutter_secure_storage`:
///
/// - Windows: encrypted with DPAPI for the signed-in Windows user;
/// - macOS: the login Keychain, kept on this Mac only (never synchronised
///   to iCloud).
///
/// On macOS the login ("file-based") Keychain is used rather than the data
/// protection Keychain, which needs the Keychain Sharing entitlement and a
/// provisioning profile, so an unsigned or ad-hoc signed build could not
/// keep keys at all.
class SecureStorageIdentityStore implements DeviceIdentityStore {
  /// Creates the store for [server]. [storage] is for tests.
  SecureStorageIdentityStore(String server, {FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage,
      _prefix =
          'obhijatra.device.v1.'
          '${base64Url.encode(utf8.encode(server)).replaceAll('=', '')}';

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  final FlutterSecureStorage _storage;
  final String _prefix;

  String _accountKey(String account) => '$_prefix.account.$account';
  String get _lastKey => '$_prefix.last';

  @override
  Future<KeyStoreSupport> support() async => KeyStoreSupport.supported;

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object {
      throw const DeviceKeysUnavailable();
    }
  }

  Future<void> _write(String key, String? value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object {
      throw const DeviceKeysUnavailable();
    }
  }

  @override
  Future<DeviceIdentity?> load(String account) async {
    final stored = await _read(_accountKey(account));
    if (stored == null) return null;
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      final keys = await SoftwareDeviceKeys.fromSeeds(
        base64.decode(json['sign'] as String),
        base64.decode(json['enc'] as String),
      );
      final device = json['device'];
      return DeviceIdentity(
        keys: keys,
        deviceId: device is String && device.isNotEmpty ? device : null,
      );
    } on Object {
      // Unreadable: treated as no keys, so the device is set up afresh.
      return null;
    }
  }

  Future<void> _save(
    String account,
    SoftwareDeviceKeys keys,
    String? deviceId,
  ) => _write(
    _accountKey(account),
    jsonEncode(<String, Object?>{
      'sign': base64.encode(keys.signSeed),
      'enc': base64.encode(keys.encSeed),
      'device': ?deviceId,
    }),
  );

  @override
  Future<DeviceIdentity> create(String account) async {
    final keys = await SoftwareDeviceKeys.generate();
    await _save(account, keys, null);
    return DeviceIdentity(keys: keys);
  }

  @override
  Future<DeviceIdentity> saveDeviceId(String account, String deviceId) async {
    final current = await load(account);
    final keys = current?.keys;
    if (keys is! SoftwareDeviceKeys) throw const DeviceKeysUnavailable();
    await _save(account, keys, deviceId);
    return current!.withDeviceId(deviceId);
  }

  @override
  Future<DeviceIdentity> forgetDeviceId(String account) async {
    final keys = (await load(account))?.keys;
    if (keys is! SoftwareDeviceKeys) throw const DeviceKeysUnavailable();
    await _save(account, keys, null);
    return DeviceIdentity(keys: keys);
  }

  @override
  Future<void> wipe(String account) => _write(_accountKey(account), null);

  @override
  Future<String?> lastAccount() => _read(_lastKey);

  @override
  Future<void> rememberLastAccount(String account) => _write(_lastKey, account);

  @override
  String toString() => 'SecureStorageIdentityStore(<redacted>)';
}
