import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The request headers of a device-signed request.
abstract final class DeviceHeaders {
  /// The device id, or [enrolDeviceId] when enrolling.
  static const String device = 'X-Obhijatra-Device';

  /// Unix time in seconds.
  static const String time = 'X-Obhijatra-Time';

  /// 16 random bytes, base64url without padding.
  static const String nonce = 'X-Obhijatra-Nonce';

  /// The Ed25519 signature of [requestMessage], base64url without padding.
  static const String signature = 'X-Obhijatra-Signature';
}

/// The device header value of an enrolment request, which is signed with
/// the key it enrols.
const String enrolDeviceId = 'enrol';

/// The path of the enrolment route.
const String deviceEnrolPath = '/api/obhijatra/v1/devices/enrol';

/// The path of the device's own status.
const String deviceMePath = '/api/obhijatra/v1/devices/me';

/// The reasons the server gives, in `data.reason.code`, for refusing a
/// device-signed request.
abstract final class DeviceReason {
  /// The request carried no device signature.
  static const String signatureRequired = 'device_signature_required';

  /// The signature, its nonce or its device did not check out.
  static const String signatureInvalid = 'device_signature_invalid';

  /// The device's clock is more than 5 minutes from the server's.
  static const String clock = 'device_clock';

  /// The device is waiting for approval.
  static const String notApproved = 'device_not_approved';

  /// The device has been switched off.
  static const String revoked = 'device_revoked';

  /// The device's approval has run out; it must be approved again.
  static const String expired = 'device_expired';

  /// The session has ended.
  static const String sessionRevoked = 'session_revoked';

  /// The session belongs to another device.
  static const String sessionOtherDevice = 'session_other_device';
}

/// What a device signs for one request:
///
/// ```text
/// "OBHIJATRA-REQUEST-V1\n" + METHOD + "\n" + target + "\n" + time + "\n" +
/// nonce + "\n" + hex(SHA-256(body))
/// ```
///
/// [target] is the path and, if any, `?` and the query, exactly as sent
/// (see [requestTarget]).
Uint8List requestMessage({
  required String method,
  required String target,
  required String unixTime,
  required String nonce,
  required List<int> body,
}) => Uint8List.fromList(
  utf8.encode(
    'OBHIJATRA-REQUEST-V1\n${method.toUpperCase()}\n$target\n$unixTime\n'
    '$nonce\n${sha256.convert(body)}',
  ),
);

/// The request target of [url] as it goes on the wire: the path (`/` if
/// empty) and, if any, `?` and the query. Use it on a [canonicalUrl].
String requestTarget(Uri url) {
  final path = url.path.isEmpty ? '/' : url.path;
  return url.hasQuery ? '$path?${url.query}' : path;
}

/// [url] with every character of its path and query that a browser or a
/// proxy might percent-encode already percent-encoded, and no fragment, so
/// the target signed is the target the server receives.
///
/// Kept as they are: letters, digits, `-._~`, existing `%XX` escapes, `/`
/// in the path, and `&`, `=` and `+` in the query (which carry its
/// structure and its spaces).
Uri canonicalUrl(Uri url) {
  final path = _escape(url.path, const {0x2F});
  final query = url.hasQuery
      ? _escape(url.query, const {0x26, 0x3D, 0x2B})
      : null;
  final buffer = StringBuffer()
    ..write(url.scheme)
    ..write('://')
    ..write(url.authority)
    ..write(path.isEmpty ? '/' : path);
  if (query != null) buffer.write('?$query');
  return Uri.parse(buffer.toString());
}

const String _hex = '0123456789ABCDEF';

String _escape(String component, Set<int> keep) {
  final out = StringBuffer();
  final bytes = utf8.encode(component);
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    final unreserved =
        (b >= 0x41 && b <= 0x5A) ||
        (b >= 0x61 && b <= 0x7A) ||
        (b >= 0x30 && b <= 0x39) ||
        b == 0x2D ||
        b == 0x2E ||
        b == 0x5F ||
        b == 0x7E;
    if (unreserved || keep.contains(b)) {
      out.writeCharCode(b);
    } else if (b == 0x25 &&
        i + 2 < bytes.length &&
        _isHex(bytes[i + 1]) &&
        _isHex(bytes[i + 2])) {
      // An existing escape, upper-cased as Dart's Uri.parse writes it.
      out
        ..write('%')
        ..writeCharCode(_upper(bytes[i + 1]))
        ..writeCharCode(_upper(bytes[i + 2]));
      i += 2;
    } else {
      out
        ..write('%')
        ..write(_hex[b >> 4])
        ..write(_hex[b & 0x0F]);
    }
  }
  return out.toString();
}

bool _isHex(int b) =>
    (b >= 0x30 && b <= 0x39) ||
    (b >= 0x41 && b <= 0x46) ||
    (b >= 0x61 && b <= 0x66);

int _upper(int b) => (b >= 0x61 && b <= 0x66) ? b - 0x20 : b;

/// [bytes] in base64url without padding.
String base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
