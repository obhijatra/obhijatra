import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens the device database as an encrypted SQLite3MultipleCiphers file,
/// and proves at run time that it is one.
///
/// The build is switched to SQLite3MultipleCiphers in the workspace
/// `pubspec.yaml` (`hooks: user_defines: sqlite3`). A plain SQLite would
/// silently ignore the key and write readable files, so [unlock] fails
/// closed with [ProblemCode.databaseUnavailable] unless the library is
/// SQLite3MultipleCiphers and the file on disk does not start with SQLite's
/// plain-text header.
final class MultipleCiphersOpener implements DeviceDatabaseOpener {
  /// Creates an opener for the database [file].
  MultipleCiphersOpener(this.file);

  /// The database file, inside the app's private storage.
  final File file;

  /// The first 16 bytes of every unencrypted SQLite file.
  static const List<int> plainTextHeader = <int>[
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, // "SQLite f"
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, // "ormat 3\0"
  ];

  @override
  Future<bool> databaseExists() async => file.existsSync();

  @override
  QueryExecutor open(DatabaseKey key) {
    final hex = key.toHex();
    return NativeDatabase(file, setup: (db) => unlock(db, hex, file));
  }

  /// Prepares the raw connection [db] to [file] before anything else uses
  /// it: sets the key, checks the cipher library, keeps temporary data in
  /// memory, checks the key, and checks that the file is encrypted.
  static void unlock(Database db, String hexKey, File file) {
    // Nothing may touch the file before the key is set.
    db.execute("PRAGMA hexkey = '$hexKey'");
    requireMultipleCiphers(db);
    // Sorting and temporary tables never spill unencrypted data to disk.
    db.execute('PRAGMA temp_store = MEMORY');
    final isNew = !file.existsSync() || file.lengthSync() == 0;
    if (!isNew) requireEncryptedFile(file);
    // Fail here, with "not a database", if the key is wrong.
    db.execute('SELECT count(*) FROM sqlite_master');
    if (isNew) {
      // Write the first page now (version 0 is what a new file has anyway),
      // so the header on disk can be checked before any data goes in.
      db.execute('PRAGMA user_version = 0');
      requireEncryptedFile(file);
    }
  }

  /// Throws [ProblemCode.databaseUnavailable] unless [db] runs on
  /// SQLite3MultipleCiphers with a cipher configured.
  ///
  /// `PRAGMA cipher` names the cipher on SQLite3MultipleCiphers; a plain
  /// SQLite ignores the unknown pragma and returns nothing. (It does not
  /// read the file, so a wrong key is still reported as a wrong key by the
  /// first real query.)
  static void requireMultipleCiphers(Database db) {
    try {
      final cipher = db.select('PRAGMA cipher');
      final name = cipher.isEmpty ? null : cipher.first.values.first;
      if (name is! String || name.isEmpty) {
        throw const ObhijatraException(ProblemCode.databaseUnavailable);
      }
    } on ObhijatraException {
      rethrow;
    } on Object catch (e) {
      throw ObhijatraException(ProblemCode.databaseUnavailable, cause: e);
    }
  }

  /// Throws [ProblemCode.databaseUnavailable] if [file] starts with SQLite's
  /// plain-text header (an unencrypted database).
  static void requireEncryptedFile(File file) {
    final RandomAccessFile handle;
    try {
      handle = file.openSync();
    } on FileSystemException catch (e) {
      throw ObhijatraException(ProblemCode.databaseUnavailable, cause: e);
    }
    try {
      final head = handle.readSync(plainTextHeader.length);
      var plain = head.length == plainTextHeader.length;
      for (var i = 0; plain && i < head.length; i++) {
        plain = head[i] == plainTextHeader[i];
      }
      if (plain) {
        throw const ObhijatraException(ProblemCode.databaseUnavailable);
      }
    } finally {
      handle.closeSync();
    }
  }
}
