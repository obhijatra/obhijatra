// Runs in a real browser: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/device/device_http.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';
import 'package:obhijatra_manager/src/device/identity_store_web.dart';
import 'package:web/web.dart' as web;

// ADR 8's signature test vector: the all-zero Ed25519 seed signing
// Message("post", "/api/x?a=1", "1793836800", "AAAAAAAAAAAAAAAAAAAAAA", "{}").
const String _vectorSignature =
    'jd5i3Nw3804mIJ7v6JiJZiZL0-fApy9xIFWavKqJpDe7ZsVhMVdXvkYfyBnm2GlRzO-fV95bdXGvCeL1YG9PAg';

/// PKCS #8 wrapping of a 32-byte Ed25519 seed (RFC 8410).
Uint8List _pkcs8(List<int> seed) => Uint8List.fromList(<int>[
  0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, //
  0x70, 0x04, 0x22, 0x04, 0x20, ...seed,
]);

web.SubtleCrypto get _subtle => web.window.crypto.subtle;

JSObject _ed25519() => JSObject()..['name'] = 'Ed25519'.toJS;

/// Checks [signature] over [message] with [publicKey] using the browser's
/// own Ed25519, independent of the Dart code that signed.
Future<bool> _verify(
  Uint8List publicKey,
  Uint8List signature,
  Uint8List message,
) async {
  final key = await _subtle
      .importKey(
        'raw',
        publicKey.toJS,
        _ed25519(),
        true,
        <JSString>['verify'.toJS].toJS,
      )
      .toDart;
  final ok = await _subtle
      .verify(_ed25519(), key, signature.toJS, message.toJS)
      .toDart;
  return (ok! as JSBoolean).toDart;
}

/// Reads one stored value straight from IndexedDB, as any script in the
/// page could.
Future<JSObject?> _rawRecord(String database, String key) async {
  final open = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(database);
  request.onsuccess = ((web.Event _) {
    open.complete(request.result! as web.IDBDatabase);
  }).toJS;
  final db = await open.future;
  final get = db
      .transaction('identities'.toJS, 'readonly')
      .objectStore('identities')
      .get(key.toJS);
  final done = Completer<JSAny?>();
  get.onsuccess = ((web.Event _) {
    done.complete(get.result);
  }).toJS;
  final value = await done.future;
  db.close();
  return value as JSObject?;
}

int _databases = 0;
String _freshDatabase() =>
    'obhijatra-device-test-${DateTime.now().microsecondsSinceEpoch}-${_databases++}';

void main() {
  const server = 'https://data.example.org';

  test('this browser has Ed25519 and X25519 on a secure page', () async {
    expect(web.window.isSecureContext, isTrue);
    final store = WebCryptoIdentityStore(
      server,
      databaseName: _freshDatabase(),
    );
    expect(await store.support(), KeyStoreSupport.supported);
  });

  test(
    'signs exactly as the server and the other apps do (ADR 8 vector)',
    () async {
      final seed = List<int>.filled(32, 0);
      final reference = await SoftwareDeviceKeys.fromSeeds(
        seed,
        List<int>.filled(32, 1),
      );
      final key = await _subtle
          .importKey(
            'pkcs8',
            _pkcs8(seed).toJS,
            _ed25519(),
            false,
            <JSString>['sign'.toJS].toJS,
          )
          .toDart;
      final keys = WebCryptoDeviceKeys(
        key,
        reference.signPublicKey,
        reference.encPublicKey,
      );
      final message = requestMessage(
        method: 'post',
        target: '/api/x?a=1',
        unixTime: '1793836800',
        nonce: 'AAAAAAAAAAAAAAAAAAAAAA',
        body: utf8.encode('{}'),
      );
      expect(base64UrlNoPadding(await keys.sign(message)), _vectorSignature);
      expect('$keys', contains('redacted'));
    },
  );

  test('keeps non-extractable keys, which come back after a reload', () async {
    final database = _freshDatabase();
    final store = WebCryptoIdentityStore(server, databaseName: database);
    expect(await store.load('u1'), isNull);
    final made = await store.create('u1');
    expect(made.deviceId, isNull);
    expect(made.keys.signPublicKey, hasLength(32));
    expect(made.keys.encPublicKey, hasLength(32));

    // What sits in IndexedDB: key objects that cannot be read out, and the
    // public keys. No private key bytes at all.
    final raw = (await _rawRecord(database, 'identity\u0000$server\u0000u1'))!;
    final names = (globalContext['Object']! as JSObject)
        .callMethod<JSArray<JSString>>('keys'.toJS, raw)
        .toDart
        .map((name) => name.toDart)
        .toSet();
    expect(names, <String>{'sign', 'enc', 'signPublic', 'encPublic'});
    for (final name in <String>['sign', 'enc']) {
      final key = raw[name]! as web.CryptoKey;
      expect(key.type, 'private', reason: name);
      expect(key.extractable, isFalse, reason: name);
      await expectLater(
        _subtle.exportKey('pkcs8', key).toDart,
        throwsA(anything),
        reason: '$name must not be readable',
      );
    }
    expect(
      (raw['signPublic']! as JSUint8Array).toDart,
      made.keys.signPublicKey,
    );

    // A new store (a reload of the page) finds the same keys, and they
    // still sign.
    final again = WebCryptoIdentityStore(server, databaseName: database);
    final loaded = (await again.load('u1'))!;
    expect(loaded.keys.signPublicKey, made.keys.signPublicKey);
    expect(loaded.keys.encPublicKey, made.keys.encPublicKey);
    final message = Uint8List.fromList(utf8.encode('hello'));
    final signature = await loaded.keys.sign(message);
    expect(signature, hasLength(64));
    expect(await _verify(made.keys.signPublicKey, signature, message), isTrue);
    expect(
      await _verify(
        made.keys.signPublicKey,
        signature,
        Uint8List.fromList(utf8.encode('hellp')),
      ),
      isFalse,
    );
  });

  test('records the device id and the last person, per server', () async {
    final database = _freshDatabase();
    final store = WebCryptoIdentityStore(server, databaseName: database);
    final other = WebCryptoIdentityStore(
      'https://other.example.org',
      databaseName: database,
    );
    final made = await store.create('u1');
    final saved = await store.saveDeviceId('u1', 'thisdevice00001');
    expect(saved.deviceId, 'thisdevice00001');
    expect((await store.load('u1'))!.deviceId, 'thisdevice00001');
    expect(
      (await store.load('u1'))!.keys.signPublicKey,
      made.keys.signPublicKey,
    );
    await store.rememberLastAccount('u1');
    expect(await store.lastAccount(), 'u1');

    // Another server, or another person, has nothing here.
    expect(await other.load('u1'), isNull);
    expect(await other.lastAccount(), isNull);
    expect(await store.load('u2'), isNull);

    // Each person on a shared computer has their own keys.
    final second = await store.create('u2');
    expect(second.keys.signPublicKey, isNot(made.keys.signPublicKey));

    // A server that no longer knows the device: the id goes, the same
    // non-extractable keys stay, and they still sign.
    final kept = await store.forgetDeviceId('u1');
    expect(kept.deviceId, isNull);
    expect(kept.keys.signPublicKey, made.keys.signPublicKey);
    final reloaded = (await WebCryptoIdentityStore(
      server,
      databaseName: database,
    ).load('u1'))!;
    expect(reloaded.deviceId, isNull);
    expect(reloaded.keys.signPublicKey, made.keys.signPublicKey);
    expect(reloaded.keys.encPublicKey, made.keys.encPublicKey);
    final raw = (await _rawRecord(database, 'identity\u0000$server\u0000u1'))!;
    for (final name in <String>['sign', 'enc']) {
      expect((raw[name]! as web.CryptoKey).extractable, isFalse);
    }
    final hello = Uint8List.fromList(utf8.encode('hello'));
    expect(
      await _verify(
        made.keys.signPublicKey,
        await reloaded.keys.sign(hello),
        hello,
      ),
      isTrue,
    );

    await store.wipe('u1');
    expect(await store.load('u1'), isNull);
    expect(await store.load('u2'), isNotNull);
    expect('$store', contains('redacted'));
  });

  test(
    'requests signed in the browser check out with its own Ed25519',
    () async {
      final store = WebCryptoIdentityStore(
        server,
        databaseName: _freshDatabase(),
      );
      await store.create('u1');
      final identity = await store.saveDeviceId('u1', 'thisdevice00001');
      final signer = DeviceSigner()..use(identity);
      late http.Request seen;
      final client = DeviceHttpClient(
        MockClient((request) async {
          seen = request;
          return http.Response('{}', 200);
        }),
        signer: signer,
      );
      await client.post(
        Uri.parse("$server/api/collections/forms/records?filter=title='a b'"),
        body: '{"title":"খানা"}',
      );
      expect(seen.headers[DeviceHeaders.device], 'thisdevice00001');
      final message = requestMessage(
        method: seen.method,
        target: requestTarget(seen.url),
        unixTime: seen.headers[DeviceHeaders.time]!,
        nonce: seen.headers[DeviceHeaders.nonce]!,
        body: seen.bodyBytes,
      );
      final signature = base64Url.decode(
        '${seen.headers[DeviceHeaders.signature]!}==',
      );
      expect(
        await _verify(identity.keys.signPublicKey, signature, message),
        isTrue,
      );
    },
  );
}
