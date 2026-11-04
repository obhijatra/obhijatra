/// The app lock: what must happen before the device database is opened.
///
/// - With a phone screen lock, the app asks for it (the app does this with
///   the platform's own prompt). Without one, a 6-digit app PIN set right
///   after an online sign-in is asked for instead. [AppLock] keeps the PIN
///   only as a PBKDF2-HMAC-SHA256 hash with its own random salt, in the
///   operating system's protected storage ([SecureValueStore]); after
///   [AppLock.triesBeforeWait] wrong tries each further try waits, starting
///   at [AppLock.firstWait] and doubling up to [AppLock.longestWait].
/// - The data opens only within [AppLock.offlineLimit] of the last online
///   sign-in ([AppLock.mustSignInOnline]).
/// - The app locks again after [AppLock.relockAfter] in the background
///   ([AppLock.relockDue]).
///
/// A 6-digit PIN has only a million values, so no hash makes a stolen hash
/// safe to guess against; what protects it is that the hash, like the
/// database key, never leaves the protected storage, and that guesses in the
/// app are slowed down. Waits and the offline limit use the phone's clock,
/// which its holder can change; a trusted time source is future work.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';

/// Small values kept in the operating system's protected storage next to the
/// database key (Android Keystore, iOS Keychain), readable before the device
/// database is open. Implemented by the app, for example with
/// `flutter_secure_storage`.
abstract interface class SecureValueStore {
  /// The value stored under [name], or `null`.
  Future<String?> read(String name);

  /// Stores [value] under [name], replacing any earlier value.
  Future<void> write(String name, String value);

  /// Removes [name]; removing a missing value is not an error.
  Future<void> delete(String name);
}

/// Runs a slow, self-contained computation (PIN hashing), for example on a
/// background isolate so the screen stays responsive. [work] captures only
/// plain values, so it can be sent to another isolate.
typedef ComputeRunner = Future<R> Function<R>(R Function() work);

/// A [ComputeRunner] that runs the work right here.
Future<R> runHere<R>(R Function() work) async => work();

/// The number of digits in an app PIN.
const int appPinLength = 6;

/// [input] as [appPinLength] ASCII digits, or `null` when it is not exactly
/// that many digits. Bangla digits (০ to ৯) count as the same digits, so the
/// PIN is the same whichever keyboard typed it.
String? normaliseAppPin(String input) {
  final digits = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      digits.writeCharCode(rune);
    } else if (rune >= 0x09E6 && rune <= 0x09EF) {
      digits.writeCharCode(0x30 + rune - 0x09E6);
    } else {
      return null;
    }
  }
  final text = digits.toString();
  return text.length == appPinLength ? text : null;
}

/// PBKDF2 with HMAC-SHA256 (RFC 8018), giving [length] bytes.
Uint8List pbkdf2HmacSha256(
  List<int> password,
  List<int> salt,
  int iterations, {
  int length = 32,
}) {
  if (iterations < 1) throw ArgumentError.value(iterations, 'iterations');
  final hmac = Hmac(sha256, password);
  final out = Uint8List(length);
  var offset = 0;
  for (var block = 1; offset < length; block++) {
    final first = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..buffer.asByteData().setUint32(salt.length, block);
    var u = hmac.convert(first).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    final take = min(t.length, length - offset);
    out.setRange(offset, offset + take, t);
    offset += take;
  }
  return out;
}

/// The stored form of an app PIN: its PBKDF2-HMAC-SHA256 hash, the random
/// salt and the iteration count. The PIN itself is never stored.
final class PinHash {
  PinHash._(this.iterations, this._salt, this._hash);

  /// Hashes [pin] (already normalised, see [normaliseAppPin]) with a new
  /// random salt.
  factory PinHash.create(
    String pin, {
    int iterations = defaultIterations,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(saltLength, (_) => source.nextInt(256)),
    );
    return PinHash._(
      iterations,
      salt,
      pbkdf2HmacSha256(utf8.encode(pin), salt, iterations),
    );
  }

  /// The scheme name written in front of every stored hash.
  static const String scheme = 'pbkdf2-sha256';

  /// The iteration count for new hashes: about a second on a low-cost
  /// phone, run off the screen's thread. Stored with each hash, so it can be
  /// raised later without breaking existing PINs.
  static const int defaultIterations = 100000;

  /// The salt length in bytes.
  static const int saltLength = 16;

  /// The hash length in bytes.
  static const int hashLength = 32;

  /// How many PBKDF2 iterations made this hash.
  final int iterations;

  final Uint8List _salt;
  final Uint8List _hash;

  /// Reads a hash written by [encode]; `null` if [stored] is not one.
  static PinHash? decode(String? stored) {
    final parts = stored?.split(r'$');
    if (parts == null || parts.length != 4 || parts[0] != scheme) return null;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1 || iterations > 10000000) {
      return null;
    }
    try {
      final salt = base64.decode(parts[2]);
      final hash = base64.decode(parts[3]);
      if (salt.length < saltLength || hash.length != hashLength) return null;
      return PinHash._(iterations, salt, hash);
    } on FormatException {
      return null;
    }
  }

  /// The text kept in the protected storage.
  String encode() =>
      '$scheme\$$iterations\$${base64.encode(_salt)}\$${base64.encode(_hash)}';

  /// Whether [pin] (normalised) is the PIN this hash was made from. Slow on
  /// purpose; compares in constant time.
  bool matches(String pin) {
    final candidate = pbkdf2HmacSha256(utf8.encode(pin), _salt, iterations);
    var difference = 0;
    for (var i = 0; i < hashLength; i++) {
      difference |= candidate[i] ^ _hash[i];
    }
    return difference == 0;
  }

  @override
  String toString() => 'PinHash(<redacted>)';
}

/// The outcome of [AppLock.checkPin].
sealed class PinCheck {
  const PinCheck();
}

/// The PIN was right.
final class PinAccepted extends PinCheck {
  /// Creates the result.
  const PinAccepted();
}

/// The PIN was wrong; [triesLeft] more wrong tries are allowed before a wait.
final class PinRejected extends PinCheck {
  /// Creates the result.
  const PinRejected(this.triesLeft);

  /// Wrong tries left before the person has to wait.
  final int triesLeft;
}

/// Too many wrong tries: no PIN is checked before [until].
final class PinWait extends PinCheck {
  /// Creates the result.
  const PinWait(this.until);

  /// When the next try is allowed.
  final DateTime until;
}

/// The last sign-in that the server confirmed on this phone.
final class OnlineSignIn {
  /// Creates the record.
  const OnlineSignIn({required this.userId, required this.at});

  /// The field user who signed in.
  final String userId;

  /// When (UTC).
  final DateTime at;
}

/// Keeps the app PIN, the wrong-PIN count and the last online sign-in in
/// the [SecureValueStore], and applies the lock rules described in this
/// library's documentation.
final class AppLock {
  /// Creates the lock on [store]. PIN hashing runs through [compute];
  /// [now] is the clock (tests fix it).
  AppLock(
    this._store, {
    this._compute = runHere,
    DateTime Function()? now,
    this.pinIterations = PinHash.defaultIterations,
  }) : _now = now ?? clock.now;

  final SecureValueStore _store;
  final ComputeRunner _compute;
  final DateTime Function() _now;

  /// The PBKDF2 iteration count for new PINs.
  final int pinIterations;

  /// How long the data opens without an online sign-in.
  static const Duration offlineLimit = Duration(days: 30);

  /// How long the app may stay in the background before it locks again.
  static const Duration relockAfter = Duration(minutes: 5);

  /// Wrong PINs allowed before each further try has to wait.
  static const int triesBeforeWait = 5;

  /// The wait after [triesBeforeWait] wrong PINs; it doubles with each
  /// further wrong PIN.
  static const Duration firstWait = Duration(seconds: 30);

  /// The longest wait between two PIN tries.
  static const Duration longestWait = Duration(hours: 1);

  /// How far the phone's clock may be behind the last sign-in before the
  /// time since it can no longer be trusted.
  static const Duration clockTolerance = Duration(minutes: 10);

  /// The stored PIN hash.
  static const String pinEntry = 'obhijatra.app_pin.v1';

  /// The wrong-PIN count and the end of the current wait (JSON).
  static const String failuresEntry = 'obhijatra.app_pin_failures.v1';

  /// The last online sign-in (JSON: user id and UTC time).
  static const String signInEntry = 'obhijatra.online_sign_in.v1';

  /// The organisation's server address, so an online sign-in can happen
  /// before the database (which also holds it) is opened.
  static const String serverEntry = 'obhijatra.server_address.v1';

  /// Every entry this class writes.
  static const List<String> entries = [
    pinEntry,
    failuresEntry,
    signInEntry,
    serverEntry,
  ];

  /// The wait after the [failures]-th wrong PIN in a row, if any.
  static Duration? waitAfter(int failures) {
    if (failures < triesBeforeWait) return null;
    final doublings = failures - triesBeforeWait;
    // 30 s doubled 7 times is more than an hour.
    if (doublings >= 7) return longestWait;
    final wait = firstWait * (1 << doublings);
    return wait > longestWait ? longestWait : wait;
  }

  /// Whether an app that went to the background at [backgroundedAt] must
  /// lock again at [now]: after [relockAfter], or when the clock went back.
  static bool relockDue(DateTime backgroundedAt, DateTime now) =>
      now.isBefore(backgroundedAt) ||
      now.difference(backgroundedAt) >= relockAfter;

  /// Whether a valid app PIN is stored.
  Future<bool> hasPin() async =>
      PinHash.decode(await _store.read(pinEntry)) != null;

  /// Stores [pin] (6 digits, see [normaliseAppPin]) as the app PIN, replacing
  /// any earlier one, and clears the wrong-PIN count.
  Future<void> setPin(String pin) async {
    final digits = normaliseAppPin(pin);
    if (digits == null) {
      throw ArgumentError('An app PIN is $appPinLength digits');
    }
    final hash = await _compute(_hashWork(digits, pinIterations));
    await _store.write(pinEntry, hash.encode());
    await _store.delete(failuresEntry);
  }

  /// Checks [pin] against the stored PIN, counting wrong tries and refusing
  /// to check while a wait runs. Throws a [StateError] if no PIN is stored.
  Future<PinCheck> checkPin(String pin) async {
    final waiting = await pinWaitUntil();
    if (waiting != null) return PinWait(waiting);
    final stored = PinHash.decode(await _store.read(pinEntry));
    if (stored == null) throw StateError('No app PIN is stored');
    final digits = normaliseAppPin(pin);
    final right = digits != null && await _compute(_matchWork(stored, digits));
    if (right) {
      await _store.delete(failuresEntry);
      return const PinAccepted();
    }
    final count = (await _failures()).count + 1;
    final wait = waitAfter(count);
    final until = wait == null ? null : _now().toUtc().add(wait);
    await _store.write(
      failuresEntry,
      jsonEncode({
        'count': count,
        if (until != null) 'until': until.toIso8601String(),
      }),
    );
    return until == null
        ? PinRejected(triesBeforeWait - count)
        : PinWait(until);
  }

  /// When the next PIN try is allowed, while a wait runs; otherwise `null`.
  /// A wait never runs longer than its length, even if the clock went back.
  Future<DateTime?> pinWaitUntil() async {
    final failures = await _failures();
    final until = failures.until;
    final wait = waitAfter(failures.count);
    if (until == null || wait == null) return null;
    final now = _now().toUtc();
    if (!now.isBefore(until)) return null;
    final latest = now.add(wait);
    return until.isAfter(latest) ? latest : until;
  }

  /// The last online sign-in recorded on this phone, if any.
  Future<OnlineSignIn?> lastOnlineSignIn() async {
    final stored = await _store.read(signInEntry);
    if (stored == null) return null;
    try {
      final json = jsonDecode(stored);
      if (json is! Map<String, Object?>) return null;
      final user = json['user'];
      final at = json['at'];
      if (user is! String || user.isEmpty || at is! String) return null;
      final time = DateTime.tryParse(at);
      return time == null ? null : OnlineSignIn(userId: user, at: time.toUtc());
    } on FormatException {
      return null;
    }
  }

  /// Records that [userId] has just signed in with the server, and clears
  /// the wrong-PIN count (the person has proved who they are).
  Future<void> recordOnlineSignIn(String userId) async {
    await _store.write(
      signInEntry,
      jsonEncode({'user': userId, 'at': _now().toUtc().toIso8601String()}),
    );
    await _store.delete(failuresEntry);
  }

  /// Whether the person must sign in with the server before the data opens:
  /// no online sign-in is recorded, the last one is more than
  /// [offlineLimit] ago, or the phone's clock is earlier than it (so the
  /// time since cannot be trusted).
  bool mustSignInOnline(OnlineSignIn? last) {
    if (last == null) return true;
    final now = _now().toUtc();
    return now.isAfter(last.at.add(offlineLimit)) ||
        now.isBefore(last.at.subtract(clockTolerance));
  }

  /// The organisation's server address remembered for an online sign-in
  /// before the database opens, if any.
  Future<Uri?> serverAddress() async {
    final stored = await _store.read(serverEntry);
    return stored == null ? null : Uri.tryParse(stored);
  }

  /// Remembers [address] as the organisation's server address.
  Future<void> rememberServerAddress(Uri address) =>
      _store.write(serverEntry, address.toString());

  /// Forgets everything this class stored, for a new install whose old
  /// entries survived (an iOS Keychain outlives the app).
  Future<void> reset() async {
    for (final name in entries) {
      await _store.delete(name);
    }
  }

  Future<({int count, DateTime? until})> _failures() async {
    final stored = await _store.read(failuresEntry);
    if (stored == null) return (count: 0, until: null);
    try {
      final json = jsonDecode(stored);
      if (json is Map<String, Object?>) {
        final count = json['count'];
        final until = json['until'];
        return (
          count: count is int && count > 0 ? count : 0,
          until: until is String ? DateTime.tryParse(until)?.toUtc() : null,
        );
      }
    } on FormatException {
      // Unreadable: handled below.
    }
    // A damaged record must not reset the count to zero: the next wrong PIN
    // waits.
    return (count: triesBeforeWait, until: null);
  }
}

// Built in top-level functions so the closures capture only plain values
// and can run on another isolate.
PinHash Function() _hashWork(String digits, int iterations) =>
    () => PinHash.create(digits, iterations: iterations);

bool Function() _matchWork(PinHash stored, String digits) =>
    () => stored.matches(digits);
