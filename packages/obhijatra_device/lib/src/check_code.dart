import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The number of digits in a device check code.
const int checkCodeDigits = 18;

const String _codeLabel = 'obhijatra-device-code-v1';

/// A device's check code: 18 decimal digits worked out from its two public
/// keys.
///
/// The device shows it, the person approving the device types it, and both
/// sides work it out from the keys, so a key swapped on the way gives a
/// different code. It is not secret.
///
/// ```text
/// digest = SHA-256("obhijatra-device-code-v1" || 0x00 || signKey || encKey)
/// code   = big-endian uint64(digest[0..8]) mod 10^18, as 18 digits
/// ```
String deviceCheckCode(List<int> signPublicKey, List<int> encPublicKey) {
  if (signPublicKey.length != 32 || encPublicKey.length != 32) {
    throw ArgumentError('Device public keys are 32 bytes each');
  }
  final digest = sha256.convert([
    ...utf8.encode(_codeLabel),
    0,
    ...signPublicKey,
    ...encPublicKey,
  ]).bytes;
  // BigInt, not int: integers on the web have only 53 bits.
  var n = BigInt.zero;
  for (final b in digest.take(8)) {
    n = (n << 8) | BigInt.from(b);
  }
  final code = n % BigInt.from(10).pow(checkCodeDigits);
  return code.toString().padLeft(checkCodeDigits, '0');
}

/// [code] as six groups of three digits, for example `225 142 753 699 752 889`.
String groupCheckCode(String code) {
  final groups = <String>[];
  for (var i = 0; i + 3 <= code.length; i += 3) {
    groups.add(code.substring(i, i + 3));
  }
  return groups.join(' ');
}

/// The digits of what a person typed, Bangla digits (০–৯) read as their
/// English values; spaces, dashes and anything else are dropped.
String normaliseCheckCode(String typed) {
  final out = StringBuffer();
  for (final r in typed.runes) {
    if (r >= 0x30 && r <= 0x39) {
      out.writeCharCode(r);
    } else if (r >= 0x09E6 && r <= 0x09EF) {
      out.writeCharCode(0x30 + r - 0x09E6);
    }
  }
  return out.toString();
}

/// [text] with its English digits written as Bangla digits, for showing a
/// code in Bangla.
String toBanglaDigits(String text) => String.fromCharCodes(
  text.runes.map((r) => r >= 0x30 && r <= 0x39 ? 0x09E6 + r - 0x30 : r),
);
