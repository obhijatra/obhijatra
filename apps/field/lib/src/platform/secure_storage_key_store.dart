import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:obhijatra_core/obhijatra_core.dart';

/// Keeps the database key in the operating system's protected storage:
/// the Android Keystore or the iOS Keychain (this device only, never in
/// backups).
final class SecureStorageKeyStore implements KeyStore {
  /// Creates the key store. Pass [storage] only in tests.
  SecureStorageKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

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
