import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/platform/file_attachment_store.dart';
import 'package:obhijatra_field/src/platform/multiple_ciphers_opener.dart';
import 'package:obhijatra_field/src/platform/secure_storage_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        await expectLater(
          store.read(path),
          throwsA(
            isA<ObhijatraException>().having(
              (e) => e.code,
              'code',
              ProblemCode.attachmentMissing,
            ),
          ),
          reason: path,
        );
      }
    });
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
