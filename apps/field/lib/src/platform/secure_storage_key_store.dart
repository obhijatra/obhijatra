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
