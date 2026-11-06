import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/platform/file_attachment_store.dart';
import 'package:obhijatra_field/src/platform/multiple_ciphers_opener.dart';
import 'package:obhijatra_field/src/platform/secure_storage_key_store.dart';
import 'package:sqlite3/sqlite3.dart';

final Matcher _missing = throwsA(
  isA<ObhijatraException>().having(
    (e) => e.code,
    'code',
    ProblemCode.attachmentMissing,
  ),
);

/// A plain SQLite, as far as the opener can tell: it ignores pragmas it does
/// not know (`hexkey`, `cipher`) and so would write a readable file.
class _PlainSqlite implements Database {
  final List<String> statements = <String>[];

  @override
  void execute(String sql, [List<Object?> parameters = const <Object?>[]]) =>
      statements.add(sql);

  @override
  ResultSet select(String sql, [List<Object?> parameters = const <Object?>[]]) {
    statements.add(sql);
    return ResultSet(<String>[], null, <List<Object?>>[]);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} on a plain SQLite');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageDeviceKeyStore', () {
    final seeds = DeviceKeySeeds(
      List<int>.filled(32, 1),
      List<int>.filled(32, 2),
    ).toText();
    final enrolment = const DeviceEnrolment(
      deviceId: 'device000000001',
      userId: 'fielduser1abcde',
    ).encode();

    test("an earlier version's single identity becomes the identity of the "
        'person it was enrolled for', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        SecureStorageDeviceKeyStore.legacySeedsEntry: seeds,
        SecureStorageDeviceKeyStore.legacyEnrolmentEntry: enrolment,
        SecureStorageKeyStore.entryName: 'the database key stays',
      });
      final store = SecureStorageDeviceKeyStore();
      final identity = await DeviceIdentity.open(store);
      addTearDown(identity.close);
      expect(identity.userId, 'fielduser1abcde');
      expect(identity.deviceId, 'device000000001');
      expect((await store.readKeySeeds('fielduser1abcde'))!.toText(), seeds);
      final all = await const FlutterSecureStorage().readAll();
      expect(
        all.containsKey(SecureStorageDeviceKeyStore.legacySeedsEntry),
        isFalse,
      );
      expect(
        all.containsKey(SecureStorageDeviceKeyStore.legacyEnrolmentEntry),
        isFalse,
      );
      expect(all[SecureStorageKeyStore.entryName], 'the database key stays');
      // Moved once: a new store finds the same.
      expect(
        await SecureStorageDeviceKeyStore().readCurrentAccount(),
        'fielduser1abcde',
      );
    });

    test(
      'seeds an earlier version never enrolled belong to nobody and go',
      () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{
          SecureStorageDeviceKeyStore.legacySeedsEntry: seeds,
        });
        final store = SecureStorageDeviceKeyStore();
        expect(await store.readCurrentAccount(), isNull);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      },
    );

    test(
      'each person keeps their own; clearing all keeps everything else',
      () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{
          SecureStorageKeyStore.entryName: 'the database key stays',
        });
        final store = SecureStorageDeviceKeyStore();
        final one = DeviceKeySeeds.fromText(seeds)!;
        final two = DeviceKeySeeds(
          List<int>.filled(32, 3),
          List<int>.filled(32, 4),
        );
        await store.writeKeySeeds('fielduser1abcde', one);
        await store.writeKeySeeds('fielduser2abcde', two);
        await store.writeCurrentAccount('fielduser2abcde');
        expect(await store.readCurrentAccount(), 'fielduser2abcde');
        expect(
          (await store.readKeySeeds('fielduser1abcde'))!.toText(),
          one.toText(),
        );
        await store.clear('fielduser2abcde');
        expect(await store.readKeySeeds('fielduser2abcde'), isNull);
        expect(await store.readKeySeeds('fielduser1abcde'), isNotNull);
        await store.clearAll();
        expect(await store.readCurrentAccount(), isNull);
        expect(await store.readKeySeeds('fielduser1abcde'), isNull);
        expect(await const FlutterSecureStorage().readAll(), <String, String>{
          SecureStorageKeyStore.entryName: 'the database key stays',
        });
      },
    );
  });

  group('SecureStorageKeyStore', () {
    test('creates a key once and reads the same key back', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final store = SecureStorageKeyStore();
      expect(await store.readDatabaseKey(), isNull);
      final created = await store.createDatabaseKey();
      final read = await store.readDatabaseKey();
      expect(read, isNotNull);
      expect(read!.toHex(), created.toHex());
      expect(created.toHex(), hasLength(64));
    });

    test('the app lock keeps its values in the same storage', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final values = SecureStorageValues();
      expect(await values.read('a'), isNull);
      await values.write('a', '1');
      expect(await const FlutterSecureStorage().read(key: 'a'), '1');
      await values.delete('a');
      expect(await values.read('a'), isNull);
    });

    test('a stored value that is not a key counts as no key', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        SecureStorageKeyStore.entryName: 'not a key',
      });
      expect(await SecureStorageKeyStore().readDatabaseKey(), isNull);
    });
  });

  group('FileAttachmentStore', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('obhijatra_att_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('reads a file by relative or absolute path', () async {
      File('${root.path}/photo.jpg').writeAsBytesSync(<int>[1, 2, 3]);
      final store = FileAttachmentStore(root);
      expect(await store.read('photo.jpg'), <int>[1, 2, 3]);
      expect(await store.read('${root.path}/photo.jpg'), <int>[1, 2, 3]);
    });

    test('a missing file is attachmentMissing', () async {
      final store = FileAttachmentStore(root);
      await expectLater(
        store.read('gone.jpg'),
        throwsA(
          isA<ObhijatraException>().having(
            (e) => e.code,
            'code',
            ProblemCode.attachmentMissing,
          ),
        ),
      );
    });

    test('a path outside the folder is refused', () async {
      final outside = File('${Directory.systemTemp.path}/obhijatra_outside.txt')
        ..writeAsStringSync('secret');
      addTearDown(outside.deleteSync);
      final store = FileAttachmentStore(root);
      for (final path in <String>[outside.path, '../obhijatra_outside.txt']) {
        await expectLater(store.read(path), _missing, reason: path);
      }
    });

    test(
      'a folder whose name only starts like the root is outside it',
      () async {
        // root: /tmp/obhijatra_att_X; sibling: /tmp/obhijatra_att_X-evil
        final sibling = Directory('${root.path}-evil')..createSync();
        addTearDown(() => sibling.deleteSync(recursive: true));
        final secret = File('${sibling.path}/secret.jpg')
          ..writeAsBytesSync(<int>[9]);
        final store = FileAttachmentStore(root);
        final name = sibling.path.split(Platform.pathSeparator).last;
        for (final path in <String>[secret.path, '../$name/secret.jpg']) {
          await expectLater(store.read(path), _missing, reason: path);
          await store.delete(path);
          expect(secret.existsSync(), isTrue, reason: path);
        }
      },
    );

    test('a symbolic link out of the folder is refused', () async {
      final outside = Directory.systemTemp.createTempSync('obhijatra_out_');
      addTearDown(() => outside.deleteSync(recursive: true));
      final secret = File('${outside.path}/secret.jpg')
        ..writeAsBytesSync(<int>[9]);
      Link('${root.path}/photo.jpg').createSync(secret.path);
      Link('${root.path}/media').createSync(outside.path);
      final store = FileAttachmentStore(root);
      for (final path in <String>[
        'photo.jpg',
        '${root.path}/photo.jpg',
        'media/secret.jpg',
      ]) {
        await expectLater(store.read(path), _missing, reason: path);
        await store.delete(path);
        expect(secret.existsSync(), isTrue, reason: path);
      }
    });

    test('a symbolic link that stays inside the folder is followed', () async {
      Directory('${root.path}/2026').createSync();
      File('${root.path}/2026/photo.jpg').writeAsBytesSync(<int>[1]);
      Link('${root.path}/latest.jpg').createSync('${root.path}/2026/photo.jpg');
      final store = FileAttachmentStore(root);
      expect(await store.read('latest.jpg'), <int>[1]);
      expect(await store.read('2026/../2026/photo.jpg'), <int>[1]);
    });

    test('the folder itself and folders in it are not files', () async {
      Directory('${root.path}/sub').createSync();
      final store = FileAttachmentStore(root);
      for (final path in <String>['', '.', 'sub', root.path]) {
        await expectLater(store.read(path), _missing, reason: '"$path"');
      }
    });

    test('a root reached through a symbolic link still works', () async {
      final parent = Directory.systemTemp.createTempSync('obhijatra_lnk_');
      addTearDown(() => parent.deleteSync(recursive: true));
      final linked = Link('${parent.path}/attachments')..createSync(root.path);
      File('${root.path}/photo.jpg').writeAsBytesSync(<int>[5]);
      final store = FileAttachmentStore(Directory(linked.path));
      expect(await store.read('photo.jpg'), <int>[5]);
      expect(await store.read('${linked.path}/photo.jpg'), <int>[5]);
    });

    test(
      'removes a sent file inside the folder; a gone file is fine',
      () async {
        final photo = File('${root.path}/photo.jpg')
          ..writeAsBytesSync(<int>[1]);
        final store = FileAttachmentStore(root);
        await store.delete('photo.jpg');
        expect(photo.existsSync(), isFalse);
        await store.delete('photo.jpg');
        await store.delete('never-there.jpg');
      },
    );
  });

  group('MultipleCiphersOpener', () {
    late Directory dir;
    late File file;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('obhijatra_db_');
      file = File('${dir.path}/obhijatra.db');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'the database file is encrypted and opens only with its key',
      () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final keys = SecureStorageKeyStore();
        final opener = MultipleCiphersOpener(file);
        expect(await opener.databaseExists(), isFalse);

        final db = await openDeviceDatabase(keyStore: keys, opener: opener);
        await SettingsRepository(db).write('probe', 'hello');
        await db.close();
        expect(await opener.databaseExists(), isTrue);

        // The file does not start with SQLite's plain-text header.
        final header = file.readAsBytesSync().take(16).toList();
        expect(
          String.fromCharCodes(header),
          isNot(startsWith('SQLite format 3')),
        );

        // The right key opens it again, with the data.
        final again = await openDeviceDatabase(keyStore: keys, opener: opener);
        expect(await SettingsRepository(again).read('probe'), 'hello');
        await again.close();

        // The wrong key is refused, and the file is left alone.
        FlutterSecureStorage.setMockInitialValues(<String, String>{
          SecureStorageKeyStore.entryName: DatabaseKey.generate().toHex(),
        });
        await expectLater(
          openDeviceDatabase(keyStore: SecureStorageKeyStore(), opener: opener),
          throwsA(
            isA<ObhijatraException>().having(
              (e) => e.code,
              'code',
              ProblemCode.databaseKeyRejected,
            ),
          ),
        );
        expect(file.existsSync(), isTrue);
      },
    );

    test('the bundled SQLite is SQLite3MultipleCiphers', () {
      // Fails if the workspace build hook (hooks: user_defines: sqlite3:
      // source: sqlite3mc) ever falls back to a plain SQLite.
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      final version = db.select('SELECT sqlite3mc_version() AS v');
      expect(version.single['v'], startsWith('SQLite3 Multiple Ciphers'));
      expect(db.select('PRAGMA cipher'), isNotEmpty);
      expect(
        () => MultipleCiphersOpener.requireMultipleCiphers(db),
        returnsNormally,
      );
    });

    test('a plain SQLite build fails closed before the file is used', () {
      final plain = _PlainSqlite();
      expect(
        () => MultipleCiphersOpener.unlock(plain, 'ab' * 32, file),
        throwsA(
          isA<ObhijatraException>().having(
            (e) => e.code,
            'code',
            ProblemCode.databaseUnavailable,
          ),
        ),
      );
      // The key was set, the cipher asked for, and nothing else ran.
      expect(plain.statements, <String>[
        "PRAGMA hexkey = '${'ab' * 32}'",
        'PRAGMA cipher',
      ]);
      expect(file.existsSync(), isFalse);
    });

    test('an unencrypted database file is refused and left alone', () async {
      final plain = sqlite3.open(file.path)
        ..execute('CREATE TABLE answers (text TEXT)')
        ..execute("INSERT INTO answers VALUES ('Rahima Begum')");
      plain.close();
      final before = file.readAsBytesSync();
      expect(String.fromCharCodes(before.take(15)), 'SQLite format 3');

      FlutterSecureStorage.setMockInitialValues(<String, String>{
        SecureStorageKeyStore.entryName: DatabaseKey.generate().toHex(),
      });
      await expectLater(
        openDeviceDatabase(
          keyStore: SecureStorageKeyStore(),
          opener: MultipleCiphersOpener(file),
        ),
        throwsA(
          isA<ObhijatraException>().having(
            (e) => e.code,
            'code',
            ProblemCode.databaseUnavailable,
          ),
        ),
      );
      expect(file.readAsBytesSync(), before);
      expect(
        () => MultipleCiphersOpener.requireEncryptedFile(file),
        throwsA(isA<ObhijatraException>()),
      );
    });

    test('a new file is checked as soon as it exists; temporary data stays '
        'in memory', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final db = await openDeviceDatabase(
        keyStore: SecureStorageKeyStore(),
        opener: MultipleCiphersOpener(file),
      );
      addTearDown(db.close);
      final tempStore = await db.customSelect('PRAGMA temp_store').getSingle();
      expect(tempStore.data.values.single, 2, reason: '2 is MEMORY');
      final cipher = await db.customSelect('PRAGMA cipher').get();
      expect(cipher, isNotEmpty);
      expect(file.lengthSync(), greaterThan(0));
      expect(
        () => MultipleCiphersOpener.requireEncryptedFile(file),
        returnsNormally,
      );
    });

    test(
      'an existing database without its key is never given a new key',
      () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final opener = MultipleCiphersOpener(file);
        final db = await openDeviceDatabase(
          keyStore: SecureStorageKeyStore(),
          opener: opener,
        );
        await db.close();
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        await expectLater(
          openDeviceDatabase(keyStore: SecureStorageKeyStore(), opener: opener),
          throwsA(
            isA<ObhijatraException>().having(
              (e) => e.code,
              'code',
              ProblemCode.databaseKeyMissing,
            ),
          ),
        );
      },
    );
  });
}
