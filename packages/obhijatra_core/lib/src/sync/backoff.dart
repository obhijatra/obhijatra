import 'dart:math';

/// Exponential backoff with jitter, for retrying uploads.
///
/// The ceiling for try `n` (1-based) is `base * 2^(n-1)`, capped at [max].
/// The delay is drawn at random from the upper half of that ceiling
/// ("equal jitter"): phones that lost signal together do not all retry
/// at the same moment, and no retry comes sooner than half the ceiling.
final class Backoff {
  /// Creates a policy starting at [base] and never waiting longer than
  /// [max].
  const Backoff({
    this.base = const Duration(seconds: 15),
    this.max = const Duration(hours: 1),
  });

  /// The ceiling of the first retry.
  final Duration base;

  /// The longest wait.
  final Duration max;

  /// The ceiling for the [attempt]th failed try (1-based).
  Duration ceiling(int attempt) {
    final n = attempt < 1 ? 1 : attempt;
    // 2^30 * base already exceeds any sensible max; avoid overflow.
    final factor = 1 << (n - 1 > 30 ? 30 : n - 1);
    final micros = base.inMicroseconds * factor;
    return micros > max.inMicroseconds || micros < 0
        ? max
        : Duration(microseconds: micros);
  }

  /// The wait before retrying after the [attempt]th failed try.
  Duration delay(int attempt, [Random? random]) {
    final top = ceiling(attempt).inMicroseconds;
    final half = top ~/ 2;
    final jitter = (random ?? _random).nextDouble() * (top - half);
    return Duration(microseconds: half + jitter.round());
  }

  static final Random _random = Random();
}
