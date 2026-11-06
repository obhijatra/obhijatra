import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';
import 'package:web/web.dart' as web;

/// The identity store of the web build: non-extractable WebCrypto keys in
/// the browser's IndexedDB.
DeviceIdentityStore platformIdentityStore(String server) =>
    WebCryptoIdentityStore(server);

/// The browser's description of itself, for the device's name.
String platformUserAgent() => web.window.navigator.userAgent;

/// `{name: …}`, a Web Cryptography algorithm.
extension type _Algorithm._(JSObject _) implements JSObject {
  external factory _Algorithm({String name});
}

/// What `generateKey` gives for Ed25519 and X25519.
extension type _KeyPair._(JSObject _) implements JSObject {
  external web.CryptoKey get publicKey;
  external web.CryptoKey get privateKey;
}

/// One person's keys as kept in IndexedDB. The browser copies the private
/// [web.CryptoKey]s in and out with their "cannot be read out" flag.
extension type _Stored._(JSObject _) implements JSObject {
  external factory _Stored({
    web.CryptoKey sign,
    web.CryptoKey enc,
    JSUint8Array signPublic,
    JSUint8Array encPublic,
  });

  /// The Ed25519 private key.
  external web.CryptoKey? get sign;

  /// The X25519 private key (for the end-to-end encryption to come).
  external web.CryptoKey? get enc;

  external JSUint8Array? get signPublic;
  external JSUint8Array? get encPublic;

  external String? get device;
  external set device(String? value);
}

final _ed25519 = _Algorithm(name: 'Ed25519');
final _x25519 = _Algorithm(name: 'X25519');

web.SubtleCrypto get _subtle => web.window.crypto.subtle;

/// A device's keys held by the browser: the private signing key is a
/// non-extractable [web.CryptoKey], so neither this app nor anything else
/// running in the page can read it out; it can only be asked to sign.
final class WebCryptoDeviceKeys implements DeviceKeys {
  /// Wraps a non-extractable private signing key made by the browser, with
  /// the two public keys. Made by [WebCryptoIdentityStore]; public for the
  /// browser tests.
  WebCryptoDeviceKeys(this._signKey, this.signPublicKey, this.encPublicKey);

  final web.CryptoKey _signKey;

  @override
  final Uint8List signPublicKey;

  @override
  final Uint8List encPublicKey;

  @override
  Future<Uint8List> sign(Uint8List message) async {
    final signature = await _subtle
        .sign(_ed25519, _signKey, message.toJS)
        .toDart;
    return (signature! as JSArrayBuffer).toDart.asUint8List();
  }

  @override
  String toString() => 'WebCryptoDeviceKeys(<redacted>)';
}

/// Keeps each person's keys in the browser: an Ed25519 and an X25519 key
/// pair made by the browser's Web Cryptography API as non-extractable, and
/// kept in IndexedDB, which stores the key objects themselves (never their
/// bytes). Only the public keys are ever exported.
///
/// Needs Ed25519 and X25519 in the Web Cryptography API: Chrome and Edge
/// 137, Firefox 130, Safari 17 or later, on a secure (https) page. There is
/// no weaker fallback: without them the app asks for a newer browser.
class WebCryptoIdentityStore implements DeviceIdentityStore {
  /// Creates the store for the server at `server`. `databaseName` is for
  /// tests.
  WebCryptoIdentityStore(
    this._server, {
    this._databaseName = 'obhijatra-device',
  });

  final String _server;
  final String _databaseName;

  static const String _objects = 'identities';

  Future<web.IDBDatabase>? _database;
  Future<KeyStoreSupport>? _support;

  String _accountKey(String account) => 'identity\u0000$_server\u0000$account';
  String get _lastKey => 'last\u0000$_server';

  @override
  Future<KeyStoreSupport> support() => _support ??= _probe();

  Future<KeyStoreSupport> _probe() async {
    try {
      if (!web.window.isSecureContext) {
        return KeyStoreSupport.secureAddressNeeded;
      }
      await _generate();
      return KeyStoreSupport.supported;
    } on Object {
      return KeyStoreSupport.updateBrowser;
    }
  }

  /// A new Ed25519 and X25519 key pair, both private keys non-extractable.
  static Future<(_KeyPair, _KeyPair)> _generate() async {
    final sign = await _subtle
        .generateKey(
          _ed25519,
          false,
          <JSString>['sign'.toJS, 'verify'.toJS].toJS,
        )
        .toDart;
    final enc = await _subtle
        .generateKey(_x25519, false, <JSString>['deriveBits'.toJS].toJS)
        .toDart;
    return (sign! as _KeyPair, enc! as _KeyPair);
  }

  static Future<Uint8List> _publicBytes(web.CryptoKey key) async {
    final raw = await _subtle.exportKey('raw', key).toDart;
    return (raw! as JSArrayBuffer).toDart.asUint8List();
  }

  // ------------------------------------------------------------ IndexedDB

  Future<web.IDBDatabase> _db() async {
    final opening = _database ??= _open();
    try {
      return await opening;
    } on Object {
      // A failed opening is tried again next time.
      if (identical(_database, opening)) _database = null;
      rethrow;
    }
  }

  Future<web.IDBDatabase> _open() {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, 1);
    request
      ..onupgradeneeded = ((web.Event _) {
        final db = request.result! as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_objects)) {
          db.createObjectStore(_objects);
        }
      }).toJS
      ..onsuccess = ((web.Event _) {
        if (!done.isCompleted) {
          done.complete(request.result! as web.IDBDatabase);
        }
      }).toJS
      ..onerror = ((web.Event _) {
        if (!done.isCompleted) {
          done.completeError(const DeviceKeysUnavailable());
        }
      }).toJS;
    return done.future;
  }

  Future<JSAny?> _get(String key) async {
    final store = (await _db())
        .transaction(_objects.toJS, 'readonly')
        .objectStore(_objects);
    final request = store.get(key.toJS);
    final done = Completer<JSAny?>();
    request
      ..onsuccess = ((web.Event _) {
        done.complete(request.result);
      }).toJS
      ..onerror = ((web.Event _) {
        done.completeError(const DeviceKeysUnavailable());
      }).toJS;
    return done.future;
  }

  /// Puts [value] under [key], or deletes [key] when [value] is null, and
  /// waits until the browser has written it.
  Future<void> _set(String key, JSAny? value) async {
    final transaction = (await _db()).transaction(_objects.toJS, 'readwrite');
    final store = transaction.objectStore(_objects);
    if (value == null) {
      store.delete(key.toJS);
    } else {
      store.put(value, key.toJS);
    }
    final done = Completer<void>();
    void failed(web.Event _) {
      if (!done.isCompleted) done.completeError(const DeviceKeysUnavailable());
    }

    transaction
      ..oncomplete = ((web.Event _) {
        if (!done.isCompleted) done.complete();
      }).toJS
      ..onerror = failed.toJS
      ..onabort = failed.toJS;
    return done.future;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DeviceKeysUnavailable {
      rethrow;
    } on Object {
      throw const DeviceKeysUnavailable();
    }
  }

  // ---------------------------------------------------------- the store

  @override
  Future<DeviceIdentity?> load(String account) => _guard(() async {
    final value = await _get(_accountKey(account));
    if (value == null) return null;
    final stored = value as _Stored;
    final sign = stored.sign;
    final signPublic = stored.signPublic?.toDart;
    final encPublic = stored.encPublic?.toDart;
    if (sign == null ||
        sign.extractable ||
        signPublic == null ||
        signPublic.length != 32 ||
        encPublic == null ||
        encPublic.length != 32) {
      // Not keys this store made: set the device up afresh.
      return null;
    }
    final device = stored.device;
    return DeviceIdentity(
      keys: WebCryptoDeviceKeys(sign, signPublic, encPublic),
      deviceId: device == null || device.isEmpty ? null : device,
    );
  });

  @override
  Future<DeviceIdentity> create(String account) => _guard(() async {
    final (sign, enc) = await _generate();
    final signPublic = await _publicBytes(sign.publicKey);
    final encPublic = await _publicBytes(enc.publicKey);
    await _set(
      _accountKey(account),
      _Stored(
        sign: sign.privateKey,
        enc: enc.privateKey,
        signPublic: signPublic.toJS,
        encPublic: encPublic.toJS,
      ),
    );
    return DeviceIdentity(
      keys: WebCryptoDeviceKeys(sign.privateKey, signPublic, encPublic),
    );
  });

  @override
  Future<DeviceIdentity> saveDeviceId(String account, String deviceId) =>
      _guard(() async {
        final value = await _get(_accountKey(account));
        final current = await load(account);
        if (value == null || current == null) {
          throw const DeviceKeysUnavailable();
        }
        final stored = value as _Stored;
        stored.device = deviceId;
        await _set(_accountKey(account), stored);
        return current.withDeviceId(deviceId);
      });

  @override
  Future<DeviceIdentity> forgetDeviceId(String account) => _guard(() async {
    final value = await _get(_accountKey(account));
    final current = await load(account);
    if (value == null || current == null) throw const DeviceKeysUnavailable();
    // The same key objects go back, still non-extractable; only the id goes.
    final stored = value as _Stored;
    stored.device = null;
    await _set(_accountKey(account), stored);
    return DeviceIdentity(keys: current.keys);
  });

  @override
  Future<void> wipe(String account) =>
      _guard(() => _set(_accountKey(account), null));

  @override
  Future<String?> lastAccount() => _guard(() async {
    final value = await _get(_lastKey);
    return value.isA<JSString>() ? (value! as JSString).toDart : null;
  });

  @override
  Future<void> rememberLastAccount(String account) =>
      _guard(() => _set(_lastKey, account.toJS));

  @override
  String toString() => 'WebCryptoIdentityStore(<redacted>)';
}
