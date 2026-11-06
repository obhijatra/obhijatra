import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:obhijatra_core/obhijatra_core.dart';

/// The operating system's protected storage as the app uses it: the
/// Android Keystore or the iOS Keychain (this device only, never in
/// backups).
const FlutterSecureStorage protectedStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// Keeps the database key in the operating system's protected storage:
/// the Android Keystore or the iOS Keychain (this device only, never in
/// backups).
final class SecureStorageKeyStore implements KeyStore {
  /// Creates the key store. Pass [storage] only in tests.
  SecureStorageKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? protectedStorage;

  final FlutterSecureStorage _storage;

  /// The storage entry that holds the key (64 hexadecimal digits).
  static const String entryName = 'obhijatra.database_key.v1';

  @override
  Future<DatabaseKey?> readDatabaseKey() async {
    final hex = await _storage.read(key: entryName);
    if (hex == null) return null;
    try {
      return DatabaseKey.fromHex(hex);
    } on FormatException {
      // A stored key that is not a key is as good as none: the core then
      // refuses to open an existing database instead of replacing the key.
      return null;
    }
  }

  @override
  Future<DatabaseKey> createDatabaseKey() async {
    final key = DatabaseKey.generate();
    await _storage.write(key: entryName, value: key.toHex());
    return key;
  }
}

/// Keeps this phone's device identities (docs/decisions/0008-device-trust.md)
/// in the same protected storage as the database key, one per person (a
/// shared phone keeps each person's): the secret seeds of their two key
/// pairs and their enrolment (device id, last status; nothing secret), and
/// which person signs now. Read before the database opens, so a sign-in from
/// a lock screen is signed too.
///
/// The single identity an earlier version kept becomes the identity of the
/// person it was enrolled for, the first time the store is used.
final class SecureStorageDeviceKeyStore implements DeviceKeyStore {
  /// Creates the store. Pass [storage] only in tests.
  SecureStorageDeviceKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? protectedStorage;

  final FlutterSecureStorage _storage;
  Future<void>? _moved;

  /// The start of every entry this store keeps.
  static const String prefix = 'obhijatra.device_identity.v2.';

  /// The entry naming the person who signs now.
  static const String currentEntry = '${prefix}current';

  /// The entry that holds [account]'s key seeds (128 hexadecimal digits).
  static String seedsEntry(String account) =>
      '${prefix}keys.${Uri.encodeComponent(account)}';

  /// The entry that holds [account]'s enrolment (JSON).
  static String enrolmentEntry(String account) =>
      '${prefix}enrolment.${Uri.encodeComponent(account)}';

  /// Where an earlier version kept its one set of seeds.
  static const String legacySeedsEntry = 'obhijatra.device_keys.v1';

  /// Where an earlier version kept its one enrolment.
  static const String legacyEnrolmentEntry = 'obhijatra.device_enrolment.v1';

  @override
  Future<String?> readCurrentAccount() async {
    await _moveLegacy();
    return _storage.read(key: currentEntry);
  }

  @override
  Future<void> writeCurrentAccount(String account) async {
    await _moveLegacy();
    await _storage.write(key: currentEntry, value: account);
  }

  @override
  Future<DeviceKeySeeds?> readKeySeeds(String account) async {
    await _moveLegacy();
    // Unreadable seeds are as good as none: the core then makes new keys,
    // which must be enrolled and approved again.
    return DeviceKeySeeds.fromText(
      await _storage.read(key: seedsEntry(account)),
    );
  }

  @override
  Future<void> writeKeySeeds(String account, DeviceKeySeeds seeds) async {
    await _moveLegacy();
    await _storage.write(key: seedsEntry(account), value: seeds.toText());
  }

  @override
  Future<DeviceEnrolment?> readEnrolment(String account) async {
    await _moveLegacy();
    return DeviceEnrolment.decode(
      await _storage.read(key: enrolmentEntry(account)),
    );
  }

  @override
  Future<void> writeEnrolment(String account, DeviceEnrolment enrolment) async {
    await _moveLegacy();
    await _storage.write(
      key: enrolmentEntry(account),
      value: enrolment.encode(),
    );
  }

  @override
  Future<void> clear(String account) async {
    await _moveLegacy();
    await _storage.delete(key: enrolmentEntry(account));
    await _storage.delete(key: seedsEntry(account));
  }

  @override
  Future<void> clearAll() async {
    await _moveLegacy();
    final names = (await _storage.readAll()).keys.where(
      (name) => name.startsWith(prefix),
    );
    for (final name in names.toList()) {
      await _storage.delete(key: name);
    }
  }

  /// Moves an earlier version's single identity, once: its seeds and
  /// enrolment become the identity of the person it was enrolled for, who
  /// signs now. Never replaces other keys that person has here. Seeds that
  /// were never enrolled belong to nobody and are dropped. Written before
  /// the old entries go, so a stop half-way loses nothing.
  Future<void> _moveLegacy() => _moved ??= () async {
    final seeds = await _storage.read(key: legacySeedsEntry);
    final text = await _storage.read(key: legacyEnrolmentEntry);
    if (seeds == null && text == null) return;
    final account = DeviceEnrolment.decode(text)?.userId;
    if (account != null &&
        text != null &&
        DeviceKeySeeds.fromText(seeds) != null) {
      final existing = await _storage.read(key: seedsEntry(account));
      if (existing == null || existing == seeds) {
        await _storage.write(key: seedsEntry(account), value: seeds!);
        await _storage.write(key: enrolmentEntry(account), value: text);
        await _storage.write(key: currentEntry, value: account);
      }
    }
    await _storage.delete(key: legacyEnrolmentEntry);
    await _storage.delete(key: legacySeedsEntry);
  }();
}

/// Keeps the app lock's small values (the app PIN's hash, wrong-PIN count,
/// last online sign-in, server address) in the same protected storage as
/// the database key, so they can be read before the database is opened.
final class SecureStorageValues implements SecureValueStore {
  /// Creates the store. Pass [storage] only in tests.
  SecureStorageValues({FlutterSecureStorage? storage})
    : _storage = storage ?? protectedStorage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}
