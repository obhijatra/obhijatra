import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';

/// Signs every request of the signed-in person with this device's keys
/// (docs/decisions/0008-device-trust.md).
///
/// The device check chooses the keys: those of the person signed in, once
/// they are known, and before a sign-in those of whoever last signed in on
/// this device, so the new session is tied to the device at once.
class DeviceSigner implements RequestSigner {
  DeviceRequestSigner? _current;

  /// Signs from now on as [identity]: its keys, and its device id once the
  /// server has given one (before that, nothing is signed).
  void use(DeviceIdentity identity) => _current = DeviceRequestSigner(
    identity.keys,
    deviceId: identity.deviceId,
  );

  /// Signs nothing from now on.
  void clear() => _current = null;

  /// The device id requests are signed as, or null.
  String? get deviceId => _current?.deviceId;

  @override
  Future<Map<String, String>> signatureHeaders(SignableRequest request) =>
      _current?.signatureHeaders(request) ??
      Future<Map<String, String>>.value(const <String, String>{});

  @override
  String toString() => 'DeviceSigner(<redacted>)';
}

/// An HTTP client that signs every request ([SigningHttpClient]: the URL
/// made canonical, the exact bytes signed, redirects never followed), and
/// sends a request once more, freshly signed, when the server answers that
/// its signature could not be checked.
///
/// The server refuses such a request before doing anything with it, so
/// sending it again is safe. It happens when the server restarted in the
/// second the request was signed (ADR 8: "a restart costs at most one
/// retry"). A second refusal is returned as it is.
final class DeviceHttpClient extends http.BaseClient {
  /// Sends through [inner], signing with [signer].
  DeviceHttpClient(http.Client inner, {required RequestSigner signer})
    : _signing = SigningHttpClient(inner, signer: signer);

  final SigningHttpClient _signing;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Finalising first puts a multipart request's boundary into its
    // headers; the body is then the exact bytes to sign and send.
    final body = await request.finalize().toBytes();
    http.Request copy() => http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = false
      ..persistentConnection = request.persistentConnection
      ..bodyBytes = body;

    final first = await _signing.send(copy());
    if (first.statusCode != 403) return first;
    // A refusal is a short JSON answer; read it to see why.
    final bytes = await first.stream.toBytes();
    if (refusalReason(bytes) == DeviceReason.signatureInvalid) {
      return _signing.send(copy());
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      first.statusCode,
      contentLength: bytes.length,
      request: first.request,
      headers: first.headers,
      isRedirect: first.isRedirect,
      persistentConnection: first.persistentConnection,
      reasonPhrase: first.reasonPhrase,
    );
  }

  @override
  void close() => _signing.close();
}

/// `data.reason.code` of a JSON error answer, or an empty string.
String refusalReason(List<int> body) {
  try {
    return switch (jsonDecode(utf8.decode(body))) {
      {'data': {'reason': {'code': final String code}}} => code,
      _ => '',
    };
  } on FormatException {
    return '';
  }
}
