import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:obhijatra_core/obhijatra_core.dart';

/// Opens the device database as an encrypted SQLite3MultipleCiphers file.
///
/// The key is set with `PRAGMA hexkey` as the very first statement, before
/// any query; the build is switched to SQLite3MultipleCiphers in the
/// workspace `pubspec.yaml` (`hooks: user_defines: sqlite3`).
final class MultipleCiphersOpener implements DeviceDatabaseOpener {
  /// Creates an opener for the database [file].
  MultipleCiphersOpener(this.file);

  /// The database file, inside the app's private storage.
  final File file;

  @override
  Future<bool> databaseExists() async => file.existsSync();

  @override
  QueryExecutor open(DatabaseKey key) {
    final hex = key.toHex();
    return NativeDatabase(
      file,
      setup: (db) {
        // Nothing may touch the file before the key is set.
        db.execute("PRAGMA hexkey = '$hex'");
        // Fail here, with "not a database", if the key is wrong.
        db.execute('SELECT count(*) FROM sqlite_master');
      },
    );
  }
}
