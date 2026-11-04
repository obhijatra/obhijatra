import 'dart:convert';

import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

import 'support/test_support.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // RFC 7914, section 11.
    test('matches the published test vectors', () {
      expect(
        _hex(
          pbkdf2HmacSha256(
            utf8.encode('passwd'),
            utf8.encode('salt'),
            1,
            length: 64,
          ),
        ),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
      expect(
        _hex(
          pbkdf2HmacSha256(
            utf8.encode('Password'),
            utf8.encode('NaCl'),
            80000,
            length: 64,
          ),
        ),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
        'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
      );
    });
  });

  group('app PIN', () {
    test('is exactly six digits; Bangla digits count as the same', () {
      expect(normaliseAppPin('123456'), '123456');
      expect(normaliseAppPin('১২৩৪৫৬'), '123456');
      expect(normaliseAppPin('12৩৪56'), '123456');
      for (final bad in [
        '',
        '12345',
        '1234567',
        '12a456',
        ' 123456',
        '12 456',
      ]) {
        expect(normaliseAppPin(bad), isNull, reason: '"$bad"');
      }
    });

    test('is stored only as a salted hash that never shows the PIN', () {
      final a = PinHash.create('123456', iterations: 1000);
      final b = PinHash.create('123456', iterations: 1000);
      expect(a.encode(), startsWith(r'pbkdf2-sha256$1000$'));
      expect(a.encode(), isNot(contains('123456')));
      expect(a.encode(), isNot(b.encode()), reason: 'a new salt each time');
      expect(a.toString(), isNot(contains(a.encode())));

      final read = PinHash.decode(a.encode())!;
      expect(read.iterations, 1000);
      expect(read.matches('123456'), isTrue);
      expect(read.matches('123457'), isFalse);
      expect(PinHash.create('123456').iterations, PinHash.defaultIterations);
      expect(PinHash.defaultIterations, greaterThanOrEqualTo(100000));
    });

    test('a damaged stored hash is no hash', () {
      for (final bad in [
        null,
        '',
        'plain:123456',
        r'pbkdf2-sha256$x$AAAA$AAAA',
        r'pbkdf2-sha256$0$AAAAAAAAAAAAAAAAAAAAAA==$AAAA',
        r'md5$1000$AAAAAAAAAAAAAAAAAAAAAA==$AAAA',
        r'pbkdf2-sha256$1000$!!$!!',
      ]) {
        expect(PinHash.decode(bad), isNull, reason: '$bad');
      }
    });
  });

  group('AppLock', () {
    late MemorySecureValues store;
    late DateTime now;
    late int hashed;

    Future<R> counting<R>(R Function() work) async {
      hashed++;
      return work();
    }

    AppLock lock() =>
        AppLock(store, compute: counting, now: () => now, pinIterations: 1000);

    setUp(() {
      store = MemorySecureValues();
      now = DateTime.utc(2026, 11, 4, 10, 30);
      hashed = 0;
    });

    test('sets and checks the PIN in the protected store only', () async {
      final app = lock();
      expect(await app.hasPin(), isFalse);
      await app.setPin('৪৮১৫৯২');
      expect(await app.hasPin(), isTrue);
      expect(store.values.keys, [AppLock.pinEntry]);
      expect(store.values.values.join(), isNot(contains('481592')));
      expect(await app.checkPin('481592'), isA<PinAccepted>());
      expect(hashed, 2, reason: 'hashing runs through the compute runner');
      expect(() => app.setPin('1234'), throwsArgumentError);
    });

    test('five wrong PINs start a 30-second wait that grows', () async {
      await lock().setPin('481592');
      for (var i = 1; i <= 4; i++) {
        final result = await lock().checkPin('000000');
        expect(result, isA<PinRejected>());
        expect((result as PinRejected).triesLeft, 5 - i);
      }
      final fifth = await lock().checkPin('000000');
      expect(fifth, isA<PinWait>());
      expect((fifth as PinWait).until, now.add(const Duration(seconds: 30)));

      // While waiting, nothing is checked, not even the right PIN.
      final before = hashed;
      now = now.add(const Duration(seconds: 29));
      expect(await lock().checkPin('481592'), isA<PinWait>());
      expect(hashed, before);

      // After the wait one more try is allowed; a wrong one waits longer.
      now = now.add(const Duration(seconds: 1));
      expect(await lock().pinWaitUntil(), isNull);
      final sixth = await lock().checkPin('000000');
      expect((sixth as PinWait).until, now.add(const Duration(seconds: 60)));
      now = now.add(const Duration(seconds: 60));
      final seventh = await lock().checkPin('111111');
      expect((seventh as PinWait).until, now.add(const Duration(minutes: 2)));

      // The right PIN after the wait opens and clears the count.
      now = now.add(const Duration(minutes: 2));
      expect(await lock().checkPin('481592'), isA<PinAccepted>());
      expect(store.values.containsKey(AppLock.failuresEntry), isFalse);
      expect(await lock().checkPin('000000'), isA<PinRejected>());
    });

    test('waits double up to an hour', () {
      expect(AppLock.waitAfter(4), isNull);
      expect(AppLock.waitAfter(5), const Duration(seconds: 30));
      expect(AppLock.waitAfter(6), const Duration(minutes: 1));
      expect(AppLock.waitAfter(8), const Duration(minutes: 4));
      expect(AppLock.waitAfter(11), const Duration(minutes: 32));
      expect(AppLock.waitAfter(12), const Duration(hours: 1));
      expect(AppLock.waitAfter(1000), const Duration(hours: 1));
    });

    test('a clock set back never makes a wait longer than itself', () async {
      await lock().setPin('481592');
      for (var i = 0; i < 5; i++) {
        await lock().checkPin('000000');
      }
      now = now.subtract(const Duration(days: 3));
      expect(await lock().pinWaitUntil(), now.add(const Duration(seconds: 30)));
    });

    test('a damaged wrong-PIN record does not reset the count', () async {
      await lock().setPin('481592');
      store.values[AppLock.failuresEntry] = '{not json';
      expect(await lock().pinWaitUntil(), isNull);
      expect(await lock().checkPin('000000'), isA<PinWait>());
    });

    test('an online sign-in is remembered and clears wrong PINs', () async {
      final app = lock();
      expect(await app.lastOnlineSignIn(), isNull);
      expect(app.mustSignInOnline(null), isTrue);
      await app.setPin('481592');
      await app.checkPin('000000');
      await app.recordOnlineSignIn('fielduser1abcde');
      final last = (await app.lastOnlineSignIn())!;
      expect(last.userId, 'fielduser1abcde');
      expect(last.at, now);
      expect(store.values.containsKey(AppLock.failuresEntry), isFalse);
    });

    test('the data opens for 30 days after an online sign-in', () async {
      await lock().recordOnlineSignIn('u1');
      final last = (await lock().lastOnlineSignIn())!;
      final start = now;
      now = start.add(const Duration(days: 29, hours: 23));
      expect(lock().mustSignInOnline(last), isFalse);
      now = start.add(AppLock.offlineLimit);
      expect(lock().mustSignInOnline(last), isFalse);
      now = start.add(AppLock.offlineLimit + const Duration(seconds: 1));
      expect(lock().mustSignInOnline(last), isTrue);
      // A clock set to before the sign-in cannot be trusted.
      now = start.subtract(const Duration(minutes: 5));
      expect(lock().mustSignInOnline(last), isFalse);
      now = start.subtract(const Duration(hours: 1));
      expect(lock().mustSignInOnline(last), isTrue);
    });

    test('locks again after five minutes in the background', () {
      final away = DateTime.utc(2026, 11, 4, 10);
      expect(
        AppLock.relockDue(away, away.add(const Duration(minutes: 4))),
        isFalse,
      );
      expect(
        AppLock.relockDue(away, away.add(const Duration(minutes: 5))),
        isTrue,
      );
      expect(
        AppLock.relockDue(away, away.subtract(const Duration(seconds: 1))),
        isTrue,
        reason: 'a clock set back counts as time away',
      );
    });

    test(
      'remembers the server address and forgets everything on reset',
      () async {
        final app = lock();
        await app.rememberServerAddress(Uri.parse('https://data.example.org'));
        expect(
          await app.serverAddress(),
          Uri.parse('https://data.example.org'),
        );
        await app.setPin('481592');
        await app.recordOnlineSignIn('u1');
        await app.reset();
        expect(store.values, isEmpty);
      },
    );

    test('a damaged sign-in record counts as none', () async {
      for (final bad in [
        '',
        '{',
        '[]',
        '{"user":"","at":"x"}',
        '{"at":"2026"}',
      ]) {
        store.values[AppLock.signInEntry] = bad;
        expect(await lock().lastOnlineSignIn(), isNull, reason: bad);
      }
    });
  });
}
