import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show GeneratedDatabase, Table, TableInfo;
import 'package:drift/native.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

import 'support/test_support.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('obhijatra_db_');
    file = File('${dir.path}/device.sqlite');
  });
  tearDown(() => dir.delete(recursive: true));

  Matcher problem(ProblemCode code) =>
      throwsA(isA<ObhijatraException>().having((e) => e.code, 'code', code));

  test('a new database gets a new key and is encrypted on disk', () async {
    final keys = MemoryKeyStore();
    final db = await openDeviceDatabase(
      keyStore: keys,
      opener: FileDatabaseOpener(file),
    );
    await OutboxRepository(db).enqueue(await fillHouseholdVisit());
    await db.close();

    expect(keys.created, 1);
    final header = (await file.readAsBytes()).take(16).toList();
    expect(latin1.decode(header), isNot(startsWith('SQLite format 3')));
    expect(
      latin1.decode(await file.readAsBytes()),
      isNot(contains('Rahima Begum')),
    );
  });

  test('the same key reopens the database with its data', () async {
    final keys = MemoryKeyStore();
    var db = await openDeviceDatabase(
      keyStore: keys,
      opener: FileDatabaseOpener(file),
    );
    final id = (await OutboxRepository(db).enqueue(await fillHouseholdVisit()))
        .instanceId;
    await db.close();

    db = await openDeviceDatabase(
      keyStore: keys,
      opener: FileDatabaseOpener(file),
    );
    addTearDown(db.close);
    expect(keys.created, 1);
    expect(await OutboxRepository(db).find(id), isNotNull);
  });

  test('a wrong key is refused and the file is left alone', () async {
    final db = await openDeviceDatabase(
      keyStore: MemoryKeyStore(),
      opener: FileDatabaseOpener(file),
    );
    await db.close();
    final before = await file.readAsBytes();

    await expectLater(
      openDeviceDatabase(
        keyStore: MemoryKeyStore(DatabaseKey.generate().toHex()),
        opener: FileDatabaseOpener(file),
      ),
      problem(ProblemCode.databaseKeyRejected),
    );
    expect(await file.readAsBytes(), before);
  });

  test('a lost key never leads to a new key over existing data', () async {
    final db = await openDeviceDatabase(
      keyStore: MemoryKeyStore(),
      opener: FileDatabaseOpener(file),
    );
    await db.close();

    final empty = MemoryKeyStore();
    await expectLater(
      openDeviceDatabase(keyStore: empty, opener: FileDatabaseOpener(file)),
      problem(ProblemCode.databaseKeyMissing),
    );
    expect(empty.created, 0);
    expect(file.existsSync(), isTrue);
  });

  test('a database from a newer app is refused, not changed', () async {
    final keys = MemoryKeyStore();
    final db = await openDeviceDatabase(
      keyStore: keys,
      opener: FileDatabaseOpener(file),
    );
    await db.customStatement('PRAGMA user_version = 99');
    await db.close();

    await expectLater(
      openDeviceDatabase(keyStore: keys, opener: FileDatabaseOpener(file)),
      problem(ProblemCode.databaseFromNewerApp),
    );
    final raw = NativeDatabase(
      file,
      setup: (d) => d.execute("PRAGMA hexkey = '${keys.hex}'"),
    );
    final check = _RawDb(raw);
    addTearDown(check.close);
    final version = await check.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 99);
  });

  test('database keys are 256 bits and never printed', () {
    final key = DatabaseKey.generate();
    expect(key.bytes, hasLength(32));
    expect(DatabaseKey.fromHex(key.toHex()).toHex(), key.toHex());
    expect(key.toString(), isNot(contains(key.toHex())));
    expect(() => DatabaseKey([1, 2, 3]), throwsArgumentError);
    expect(() => DatabaseKey.fromHex('xyz'), throwsFormatException);
    key.destroy();
    expect(key.bytes.every((b) => b == 0), isTrue);
  });

  test('settings are a simple key-value store', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final settings = SettingsRepository(db);
    expect(await settings.read('a'), isNull);
    await settings.write('a', '1');
    await settings.write('a', '2');
    expect(await settings.read('a'), '2');
    await settings.delete('a');
    expect(await settings.read('a'), isNull);
  });
}

/// A bare database to inspect a file without the app's migrations.
final class _RawDb extends GeneratedDatabase {
  _RawDb(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 99;
}
