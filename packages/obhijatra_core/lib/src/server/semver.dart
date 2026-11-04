/// Compares two semantic versions (`1.2.3`, `1.2.3-beta.1`, `1.2.3+build`).
///
/// Returns a negative number when [a] is older than [b], zero when they
/// are the same release, and a positive number when [a] is newer. Build
/// metadata is ignored and a pre-release sorts before its release, as in
/// Semantic Versioning 2.0.0. Throws [FormatException] for anything else.
int compareVersions(String a, String b) {
  final left = _Version.parse(a);
  final right = _Version.parse(b);
  for (var i = 0; i < 3; i++) {
    final diff = left.core[i].compareTo(right.core[i]);
    if (diff != 0) return diff;
  }
  return _comparePreRelease(left.preRelease, right.preRelease);
}

final _pattern = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
  r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
  r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
);

final class _Version {
  const _Version(this.core, this.preRelease);

  factory _Version.parse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) {
      throw FormatException('Not a semantic version', text);
    }
    return _Version([
      for (var i = 1; i <= 3; i++) int.parse(match.group(i)!),
    ], match.group(4)?.split('.') ?? const []);
  }

  final List<int> core;
  final List<String> preRelease;
}

int _comparePreRelease(List<String> a, List<String> b) {
  // A release (no pre-release part) is newer than any of its pre-releases.
  if (a.isEmpty || b.isEmpty) return (a.isEmpty ? 1 : 0) - (b.isEmpty ? 1 : 0);
  for (var i = 0; i < a.length && i < b.length; i++) {
    final x = int.tryParse(a[i]);
    final y = int.tryParse(b[i]);
    final int diff;
    if (x != null && y != null) {
      diff = x.compareTo(y);
    } else if (x != null) {
      diff = -1; // numeric identifiers sort before alphanumeric ones
    } else if (y != null) {
      diff = 1;
    } else {
      diff = a[i].compareTo(b[i]);
    }
    if (diff != 0) return diff;
  }
  return a.length.compareTo(b.length);
}
