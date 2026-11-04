import 'dart:math';

import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

void main() {
  const backoff = Backoff(
    base: Duration(seconds: 10),
    max: Duration(minutes: 5),
  );

  test('the ceiling doubles from the base and stops at the maximum', () {
    expect(backoff.ceiling(1), const Duration(seconds: 10));
    expect(backoff.ceiling(2), const Duration(seconds: 20));
    expect(backoff.ceiling(3), const Duration(seconds: 40));
    expect(backoff.ceiling(5), const Duration(seconds: 160));
    expect(backoff.ceiling(6), const Duration(minutes: 5));
    expect(backoff.ceiling(1000), const Duration(minutes: 5));
    expect(backoff.ceiling(0), const Duration(seconds: 10));
  });

  test('each delay lies in the upper half of its ceiling', () {
    final random = Random(1);
    for (var attempt = 1; attempt <= 12; attempt++) {
      final top = backoff.ceiling(attempt);
      for (var i = 0; i < 200; i++) {
        final delay = backoff.delay(attempt, random);
        expect(delay, greaterThanOrEqualTo(top ~/ 2));
        expect(delay, lessThanOrEqualTo(top));
      }
    }
  });

  test('delays are spread out (jitter), not identical', () {
    final random = Random(7);
    final delays = {for (var i = 0; i < 50; i++) backoff.delay(4, random)};
    expect(delays.length, greaterThan(40));
  });

  test('the default policy waits 7.5 to 15 seconds after a first failure', () {
    const policy = Backoff();
    final delay = policy.delay(1, Random(3));
    expect(delay.inMilliseconds, inInclusiveRange(7500, 15000));
    expect(policy.ceiling(50), const Duration(hours: 1));
  });
}
