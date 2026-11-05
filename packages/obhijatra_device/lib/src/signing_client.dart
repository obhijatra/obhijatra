import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:obhijatra_device/src/device_keys.dart';
import 'package:obhijatra_device/src/protocol.dart';

/// What a [RequestSigner] signs: the method, the full URL and the body.
final class SignableRequest {
  /// Creates the description of one outgoing request.
  const SignableRequest({
    required this.method,
    required this.url,
    required this.body,
  });

  /// The HTTP method, upper case.
  final String method;

  /// The full request URL, query included, exactly as it will be sent
  /// ([canonicalUrl]).
  final Uri url;

  /// The exact body bytes that will be sent (empty for GET).
  final Uint8List body;
}

/// Adds device-signature headers to requests.
abstract interface class RequestSigner {
  /// Returns the headers to add to [request]; an empty map adds none.
  Future<Map<String, String>> signatureHeaders(SignableRequest request);
}

/// Signs no request (before the device has keys, and in tests).
final class UnsignedRequests implements RequestSigner {
  /// Creates the no-op signer.
  const UnsignedRequests();

  @override
  Future<Map<String, String>> signatureHeaders(SignableRequest request) async =>
      const {};
}

/// Signs requests with a device's [DeviceKeys]
/// (docs/decisions/0008-device-trust.md).
///
/// An enrolment request is signed as [enrolDeviceId]. Every other request
/// is signed as [deviceId] once the device has one, and not signed before.
final class DeviceRequestSigner implements RequestSigner {
  /// Signs with [keys] as the device [deviceId] (null until enrolled).
  DeviceRequestSigner(
    this.keys, {
    this.deviceId,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  /// The device's keys.
  final DeviceKeys keys;

  /// The id the server gave the device at enrolment; null before.
  String? deviceId;

  final DateTime Function() _now;
  final Random _random;

  @override
  Future<Map<String, String>> signatureHeaders(SignableRequest request) async {
    final id = request.url.path == deviceEnrolPath ? enrolDeviceId : deviceId;
    if (id == null || id.isEmpty) return const {};
    final time = (_now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = base64UrlNoPadding(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final signature = await keys.sign(
      requestMessage(
        method: request.method,
        target: requestTarget(request.url),
        unixTime: time,
        nonce: nonce,
        body: request.body,
      ),
    );
    return {
      DeviceHeaders.device: id,
      DeviceHeaders.time: time,
      DeviceHeaders.nonce: nonce,
      DeviceHeaders.signature: base64UrlNoPadding(signature),
    };
  }
}

/// The server answered with a redirect (HTTP 3xx), which a
/// [SigningHttpClient] never follows: following it would send the session
/// token and the signed body to an address nobody chose (for example a
/// public Wi-Fi sign-in page).
final class RedirectNotFollowed implements Exception {
  /// Creates the exception for a [statusCode] answer to [url].
  const RedirectNotFollowed(this.statusCode, this.url);

  /// The HTTP status of the answer (300 to 399).
  final int statusCode;

  /// The address that answered with the redirect.
  final Uri url;

  @override
  String toString() => 'RedirectNotFollowed($statusCode)';
}

/// An HTTP client that sends every request to its [canonicalUrl], gives it
/// to a [RequestSigner], never follows redirects (a 3xx answer throws
/// [RedirectNotFollowed]) and stops waiting for an answer after [timeout].
///
/// The body is buffered so it can be signed; a multipart upload is put
/// together in full first.
final class SigningHttpClient extends http.BaseClient {
  /// Wraps [inner], signing with [signer].
  SigningHttpClient(
    this._inner, {
    this._signer = const UnsignedRequests(),
    this.timeout = const Duration(seconds: 60),
  });

  final http.Client _inner;
  final RequestSigner _signer;

  /// How long to wait for the response headers.
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final url = canonicalUrl(request.url);
    final signed = http.Request(request.method, url)
      ..headers.addAll(request.headers)
      // Never follow a redirect, whatever the caller asked for.
      ..followRedirects = false
      ..persistentConnection = request.persistentConnection
      ..bodyBytes = body;
    // Setting bodyBytes may add a charset; keep the original content type.
    final contentType = request.headers['content-type'];
    if (contentType != null) signed.headers['content-type'] = contentType;

    final extra = await _signer.signatureHeaders(
      SignableRequest(method: request.method, url: url, body: body),
    );
    signed.headers.addAll(extra);

    final response = await _inner.send(signed).timeout(timeout);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      // Release the connection; the body of a redirect is never read.
      await response.stream.listen(null).cancel();
      throw RedirectNotFollowed(response.statusCode, request.url);
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
