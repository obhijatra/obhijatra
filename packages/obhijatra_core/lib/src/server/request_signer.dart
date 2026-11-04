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

/// An HTTP client that gives every request to a [RequestSigner] and stops
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
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..bodyBytes = body;
    // Setting bodyBytes may add a charset; keep the original content type.
    final contentType = request.headers['content-type'];
    if (contentType != null) signed.headers['content-type'] = contentType;

    final extra = await _signer.signatureHeaders(
      SignableRequest(method: request.method, url: request.url, body: body),
    );
    signed.headers.addAll(extra);

    return _inner.send(signed).timeout(timeout);
  }

  @override
  void close() => _inner.close();
}
