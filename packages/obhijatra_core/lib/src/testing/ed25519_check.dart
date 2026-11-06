/// Ed25519 signature checking (RFC 8032, section 5.1.7) in plain `BigInt`
/// arithmetic, so the fake server can check device signatures with the
/// real algorithm without a cryptography package of its own.
///
/// For tests only: it is slow and not constant-time. That is acceptable
/// here because it only checks public values (a public key, a message and
/// its signature); nothing secret passes through it. Apps sign with
/// `SoftwareDeviceKeys` (package:obhijatra_device), never with this.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Whether [signature] (64 bytes) is a valid Ed25519 signature of
/// [message] by [publicKey] (32 bytes).
///
/// Checks as Go's `crypto/ed25519` does (the server's library): the
/// signature's `S` must be below the group order, and `[S]B - [k]A` must
/// encode to the signature's `R` exactly.
bool ed25519SignatureValid(
  List<int> publicKey,
  List<int> message,
  List<int> signature,
) {
  if (publicKey.length != 32 || signature.length != 64) return false;
  final a = _decode(publicKey);
  if (a == null) return false;
  final s = _littleEndian(signature.sublist(32));
  if (s >= _l) return false;
  final digest = sha512.convert([
    ...signature.sublist(0, 32),
    ...publicKey,
    ...message,
  ]).bytes;
  final k = _littleEndian(digest) % _l;
  final check = _add(_multiply(_base, s), _multiply(_negate(a), k));
  final encoded = _encode(check);
  for (var i = 0; i < 32; i++) {
    if (encoded[i] != signature[i]) return false;
  }
  return true;
}

/// Whether [publicKey] is an Ed25519 public key that is a point on the
/// curve and not of small order (the server refuses those: a small-order
/// key would accept one fixed signature for every message).
bool ed25519KeyUsable(List<int> publicKey) {
  if (publicKey.length != 32) return false;
  final point = _decode(publicKey);
  if (point == null) return false;
  // [8]P is the neutral point exactly when P has small order.
  var p = point;
  for (var i = 0; i < 3; i++) {
    p = _add(p, p);
  }
  return !(p.x == BigInt.zero && _mod(p.y - p.z) == BigInt.zero);
}

// ---- The curve -----------------------------------------------------------

final BigInt _p = (BigInt.one << 255) - BigInt.from(19);

final BigInt _l =
    (BigInt.one << 252) +
    BigInt.parse('27742317777372353535851937790883648493');

final BigInt _d = _mod(BigInt.from(-121665) * _inverse(BigInt.from(121666)));

final BigInt _sqrtMinusOne = BigInt.two.modPow((_p - BigInt.one) >> 2, _p);

final _Point _base = () {
  final y = _mod(BigInt.from(4) * _inverse(BigInt.from(5)));
  return _decode(_bytesOf(y))!;
}();

/// A point in extended coordinates: x = X/Z, y = Y/Z, x*y = T/Z.
final class _Point {
  const _Point(this.x, this.y, this.z, this.t);

  final BigInt x;
  final BigInt y;
  final BigInt z;
  final BigInt t;
}

final _Point _neutral = _Point(
  BigInt.zero,
  BigInt.one,
  BigInt.one,
  BigInt.zero,
);

BigInt _mod(BigInt v) => v % _p;

BigInt _inverse(BigInt v) => v.modPow(_p - BigInt.two, _p);

_Point _add(_Point p, _Point q) {
  final a = _mod((p.y - p.x) * (q.y - q.x));
  final b = _mod((p.y + p.x) * (q.y + q.x));
  final c = _mod(p.t * BigInt.two * _d * q.t);
  final d = _mod(p.z * BigInt.two * q.z);
  final e = b - a;
  final f = d - c;
  final g = d + c;
  final h = b + a;
  return _Point(_mod(e * f), _mod(g * h), _mod(f * g), _mod(e * h));
}

_Point _negate(_Point p) => _Point(_mod(-p.x), p.y, p.z, _mod(-p.t));

_Point _multiply(_Point p, BigInt scalar) {
  var result = _neutral;
  var addend = p;
  var k = scalar;
  while (k > BigInt.zero) {
    if (k.isOdd) result = _add(result, addend);
    addend = _add(addend, addend);
    k = k >> 1;
  }
  return result;
}

BigInt _littleEndian(List<int> bytes) {
  var v = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i--) {
    v = (v << 8) | BigInt.from(bytes[i]);
  }
  return v;
}

Uint8List _bytesOf(BigInt v) {
  final out = Uint8List(32);
  var rest = v;
  for (var i = 0; i < 32; i++) {
    out[i] = (rest & BigInt.from(0xff)).toInt();
    rest = rest >> 8;
  }
  return out;
}

/// The point that [bytes] encodes (RFC 8032, section 5.1.3), or `null`.
_Point? _decode(List<int> bytes) {
  final copy = Uint8List.fromList(bytes);
  final sign = copy[31] >> 7;
  copy[31] &= 0x7f;
  final y = _littleEndian(copy);
  if (y >= _p) return null;
  final yy = _mod(y * y);
  final u = _mod(yy - BigInt.one);
  final v = _mod(_d * yy + BigInt.one);
  final v3 = _mod(v * v * v);
  final v7 = _mod(v3 * v3 * v);
  var x = _mod(u * v3 * _mod(u * v7).modPow((_p - BigInt.from(5)) >> 3, _p));
  final vxx = _mod(v * x * x);
  if (vxx == u) {
    // x is a square root of u/v.
  } else if (vxx == _mod(-u)) {
    x = _mod(x * _sqrtMinusOne);
  } else {
    return null;
  }
  if (x == BigInt.zero && sign == 1) return null;
  if ((x.isOdd ? 1 : 0) != sign) x = _mod(-x);
  return _Point(x, y, BigInt.one, _mod(x * y));
}

Uint8List _encode(_Point p) {
  final zInverse = _inverse(p.z);
  final x = _mod(p.x * zInverse);
  final y = _mod(p.y * zInverse);
  final out = _bytesOf(y);
  if (x.isOdd) out[31] |= 0x80;
  return out;
}
