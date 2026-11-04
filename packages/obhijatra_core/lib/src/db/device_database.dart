import 'dart:convert';

import 'package:crypto/crypto.dart';
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

  /// The schema version this build writes. Version 1: Phase 1. Version 2:
  /// `outbox.plaintext_sha256`, and sent submissions keep only a receipt.
  static const int currentSchemaVersion = 2;

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
      if (from < 2) {
        await m.addColumn(outbox, outbox.plaintextSha256);
        // Version 1 stored the finalised XML unchanged (no field protection
        // existed), so the stored XML is the plaintext.
        final rows = await customSelect(
          'SELECT instance_id, instance_xml FROM outbox',
        ).get();
        for (final row in rows) {
          await customUpdate(
            'UPDATE outbox SET plaintext_sha256 = ? WHERE instance_id = ?',
            variables: [
              Variable.withString(
                sha256
                    .convert(utf8.encode(row.read<String>('instance_xml')))
                    .toString(),
              ),
              Variable.withString(row.read<String>('instance_id')),
            ],
          );
        }
        // Submissions the server already holds keep only their receipt.
        // (The Phase 1 app wrote no attachment files, so none are left.)
        await customStatement(
          "UPDATE outbox SET instance_xml = '', attachments = '[]', "
          'last_error_message = NULL '
          "WHERE state = 'sent'",
        );
      }
      // Later versions add one step per version here, for example:
      // if (from < 3) await m.addColumn(outbox, outbox.someNewColumn);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
