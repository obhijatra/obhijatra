import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

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

  /// The full request URL, query included.
  final Uri url;

  /// The exact body bytes that will be sent (empty for GET).
  final Uint8List body;
}

/// Adds device-signature headers to every request (zero-trust milestone).
///
/// The planned implementation signs method, path, Unix time, a 16-byte
/// nonce and the SHA-256 of [SignableRequest.body] with the device's
/// Ed25519 key through the injected `sodium` API, and returns the device
/// id, time, nonce and signature as headers.
abstract interface class RequestSigner {
  /// Returns the headers to add to [request]; an empty map adds none.
  Future<Map<String, String>> signatureHeaders(SignableRequest request);
}

/// Phase 1 behaviour: requests are not signed.
final class UnsignedRequests implements RequestSigner {
  /// Creates the no-op signer.
  const UnsignedRequests();

  @override
  Future<Map<String, String>> signatureHeaders(SignableRequest request) async =>
      const {};
}

/// The server answered with a redirect (HTTP 3xx), which a
/// [SigningHttpClient] never follows: following it would send the session
/// token and the signed body to an address nobody chose (for example a
/// public Wi-Fi sign-in page). `ObhijatraServer` turns it into
/// `ProblemCode.redirected`.
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

/// An HTTP client that gives every request to a [RequestSigner], never
/// follows redirects (a 3xx answer throws [RedirectNotFollowed]) and stops
/// waiting for an answer after [timeout].
///
/// The body is buffered so it can be signed; large media will move to one
/// file per request before attachments grow beyond a few megabytes.
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
    final signed = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      // Never follow a redirect, whatever the caller asked for.
      ..followRedirects = false
      ..persistentConnection = request.persistentConnection
      ..bodyBytes = body;
    // Setting bodyBytes may add a charset; keep the original content type.
    final contentType = request.headers['content-type'];
    if (contentType != null) signed.headers['content-type'] = contentType;

    final extra = await _signer.signatureHeaders(
      SignableRequest(method: request.method, url: request.url, body: body),
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
