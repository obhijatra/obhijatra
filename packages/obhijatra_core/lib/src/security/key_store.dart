import 'dart:math';

import 'package:drift/drift.dart';
import 'package:obhijatra_core/src/db/device_database.dart';
import 'package:obhijatra_core/src/problem.dart';

/// The secret that unlocks the device database.
///
/// The core only carries it from the [KeyStore] to the [DeviceDatabaseOpener]; it
/// never logs, stores or inspects it. [toString] never shows the bytes.
final class DatabaseKey {
  /// Wraps [bytes], which must be exactly [length] bytes.
  DatabaseKey(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    if (_bytes.length != length) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'A database key must be $length bytes',
      );
    }
  }

  /// A new random key from the platform's secure random generator.
  factory DatabaseKey.generate([Random? random]) {
    final source = random ?? Random.secure();
    return DatabaseKey(List<int>.generate(length, (_) => source.nextInt(256)));
  }

  /// Reads a key written by [toHex].
  factory DatabaseKey.fromHex(String hex) {
    final clean = hex.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(clean)) {
      throw const FormatException('A database key is 64 hexadecimal digits');
    }
    return DatabaseKey([
      for (var i = 0; i < clean.length; i += 2)
        int.parse(clean.substring(i, i + 2), radix: 16),
    ]);
  }

  /// The key length in bytes (256 bits).
  static const int length = 32;

  final Uint8List _bytes;

  /// A copy of the key bytes, for the [DeviceDatabaseOpener] and [KeyStore] only.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// The key as 64 lower-case hexadecimal digits, for the [DeviceDatabaseOpener]
  /// (`PRAGMA hexkey`) and [KeyStore] only.
  String toHex() =>
      _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Overwrites the key bytes in memory once they are no longer needed.
  void destroy() => _bytes.fillRange(0, _bytes.length, 0);

  @override
  String toString() => 'DatabaseKey(<redacted>)';
}

/// Keeps the database key in the operating system's protected storage
/// (Android Keystore, iOS/macOS Keychain, Windows DPAPI), implemented by
/// the app, for example with `flutter_secure_storage`.
abstract interface class KeyStore {
  /// Returns the stored database key, or `null` if none has been created.
  Future<DatabaseKey?> readDatabaseKey();

  /// Creates, stores and returns a new database key. Called only when no
  /// key exists and no database exists, so it never replaces a key.
  Future<DatabaseKey> createDatabaseKey();
}

/// Opens the encrypted SQLite file, implemented by the app with
/// SQLite3MultipleCiphers (for example drift's `NativeDatabase` running
/// `PRAGMA hexkey` in its setup callback).
abstract interface class DeviceDatabaseOpener {
  /// Whether the database file already exists.
  Future<bool> databaseExists();

  /// Returns an executor for the database file, unlocked with [key].
  QueryExecutor open(DatabaseKey key);
}

/// Opens the device database with the key from [keyStore], creating a key
/// only for a brand-new database.
///
/// Never creates a new key for an existing database (that would make its
/// data unreadable) and never deletes the file: on any problem it throws an
/// [ObhijatraException] with [ProblemCode.databaseKeyMissing],
/// [ProblemCode.databaseKeyRejected], [ProblemCode.databaseFromNewerApp] or
/// [ProblemCode.databaseUnavailable] and leaves everything as it was.
Future<DeviceDatabase> openDeviceDatabase({
  required KeyStore keyStore,
  required DeviceDatabaseOpener opener,
}) async {
  var key = await keyStore.readDatabaseKey();
  if (key == null) {
    if (await opener.databaseExists()) {
      throw const ObhijatraException(ProblemCode.databaseKeyMissing);
    }
    key = await keyStore.createDatabaseKey();
  }

  final db = DeviceDatabase(opener.open(key));
  try {
    // The first statement opens the file (running the opener's setup with
    // the key), checks the key and migrates.
    await db.customSelect('SELECT count(*) FROM sqlite_master').get();
    return db;
  } on ObhijatraException {
    await db.close();
    rethrow;
  } on Object catch (error) {
    await db.close();
    final text = error.toString().toLowerCase();
    if (text.contains('not a database') || text.contains('file is encrypted')) {
      throw ObhijatraException(ProblemCode.databaseKeyRejected, cause: error);
    }
    throw ObhijatraException(ProblemCode.databaseUnavailable, cause: error);
  } finally {
    // The file is open (or failed to open); the key is no longer needed.
    key.destroy();
  }
}
