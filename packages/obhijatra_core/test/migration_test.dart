// Migration harness for the device database.
//
// Every schema version is exported to drift_schemas/ with
//   dart run drift_dev schema dump lib/src/db/device_database.dart drift_schemas/
// and turned into test helpers with
//   dart run drift_dev schema generate --data-classes --companions \
//     drift_schemas/ test/generated_migrations/
// The tests below then migrate a database created at each exported version
// (starting at 1) to the current version and compare the result with the
// schema the code expects, so a release can never strand a phone's data.
@TestOn('vm')
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'support/test_support.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every schema version up to the current one is exported', () {
    expect(GeneratedHelper.versions, [
      for (var v = 1; v <= DeviceDatabase.currentSchemaVersion; v++) v,
    ]);
  });

  test('a new database has exactly the schema the code expects', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    await db.validateDatabaseSchema();
  });

  for (final from in GeneratedHelper.versions) {
    test('migrates from v$from to the current version', () async {
      final db = DeviceDatabase(await verifier.startAt(from));
      addTearDown(db.close);
      await verifier.migrateAndValidate(
        db,
        DeviceDatabase.currentSchemaVersion,
      );
    });
  }

  test(
    'submissions and drafts written at v1 survive every migration',
    () async {
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      const created = '2026-11-04T08:00:00.000Z';
      await old
          .into(old.outbox)
          .insert(
            v1.OutboxCompanion.insert(
              instanceId: 'uuid:11111111-2222-4333-8444-555555555555',
              formId: 'household_visit',
              formVersion: '2026110401',
              instanceXml: '<data id="household_visit"/>',
              state: 'queued',
              createdAt: created,
              updatedAt: created,
            ),
          );
      await old
          .into(old.drafts)
          .insert(
            v1.DraftsCompanion.insert(
              instanceId: 'uuid:aaaaaaaa-2222-4333-8444-555555555555',
              formId: 'household_visit',
              formVersion: '2026110401',
              instanceXml: '<data id="household_visit"/>',
              createdAt: created,
              updatedAt: created,
            ),
          );
      await old.close();

      final db = DeviceDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(
        db,
        DeviceDatabase.currentSchemaVersion,
      );

      final entry = await OutboxRepository(db)
          .find('uuid:11111111-2222-4333-8444-555555555555');
      expect(entry!.state, OutboxState.queued);
      expect(entry.createdAt, DateTime.utc(2026, 11, 4, 8));
      expect(entry.attachments, '[]');
      expect(
        await DraftRepository(db)
            .find('uuid:aaaaaaaa-2222-4333-8444-555555555555'),
        isNotNull,
      );
    },
  );
}
