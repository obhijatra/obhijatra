import 'package:drift/drift.dart';
import 'package:obhijatra_core/src/db/tables.dart';
import 'package:obhijatra_core/src/problem.dart';

export 'package:obhijatra_core/src/db/tables.dart';

part 'device_database.g.dart';

/// The encrypted SQLite database on the phone or desktop.
///
/// The app supplies the [QueryExecutor] (SQLite3MultipleCiphers with the key
/// from the OS key store); see `openDeviceDatabase`. Every schema change
/// bumps [schemaVersion], adds a step to [migration], is exported with
/// `drift_dev schema dump` and is tested from version 1 upwards.
@DriftDatabase(
  tables: [CachedForms, CachedFormVersions, Drafts, Outbox, DeviceSettings],
)
class DeviceDatabase extends _$DeviceDatabase {
  /// Opens the database on [executor].
  DeviceDatabase(super.executor);

  /// The schema version this build writes. Version 1: Phase 1.
  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from > to) {
        // Opening a newer app's database with an older app: refuse, and
        // leave every row as it is.
        throw const ObhijatraException(ProblemCode.databaseFromNewerApp);
      }
      // Later versions add one step per version here, for example:
      // if (from < 2) await m.addColumn(outbox, outbox.someNewColumn);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
