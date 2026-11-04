// An in-memory stand-in for obhijatra-server, following the contract the
// core's own tests use (meta, PocketBase sign-in and record routes, the
// OpenRosa-style submission route with idempotency).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:xml/xml.dart';

/// The password every fake field user has.
const String fakePassword = 'correct-horse-battery-1';

/// The email of the fake field user.
const String fakeEmail = 'field1@example.org';

/// How the fake answers one request instead of handling it normally.
sealed class Glitch {
  const Glitch();
}

/// The connection fails before reaching the server.
final class NoConnection extends Glitch {
  const NoConnection();
}

/// The server answers with [status] and a JSON error.
final class ErrorStatus extends Glitch {
  const ErrorStatus(this.status, [this.message = 'Something went wrong.']);
  final int status;
  final String message;
}

/// A fake `obhijatra-server`.
final class FakeServer {
  FakeServer({String? xform}) {
    if (xform != null) publish(xform);
  }

  /// The address the app is given.
  static final Uri baseUrl = Uri.parse('https://data.example.org');

  /// The meta answer.
  Map<String, Object?> meta = <String, Object?>{
    'server_version': '0.1.0-dev',
    'schema_version': 1,
    'api_version': '1',
    'min_client_version': '0.1.0',
  };

  /// Make every meta request fail this way (null: answer normally).
  Glitch? metaGlitch;

  /// Make every sign-in fail this way.
  Glitch? signInGlitch;

  /// Make every submission fail this way.
  Glitch? submissionGlitch;

  /// Answer every unknown route with an HTML page (a website, not a server).
  bool isWebsite = false;

  /// Stored submissions: instance id to XML.
  final Map<String, String> submissions = <String, String>{};

  /// Every request: `METHOD path`.
  final List<String> log = <String>[];

  final Map<String, String> _published = <String, String>{};
  final Map<String, String> _tokens = <String, String>{};
  final List<String> _fileTokens = <String>[];

  /// Makes every saved sign-in stop working (the server forgets them), as
  /// when a session expires.
  void expireSessions() => _tokens.clear();

  /// Publishes [xform].
  void publish(String xform) {
    final info = XFormInfo.read(xform);
    _published['${info.formId}@${info.version}'] = xform;
  }

  /// A client routed to this fake.
  http.Client client() => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    log.add('${request.method} $path');
    if (isWebsite) {
      return http.Response(
        '<html><body>Hello</body></html>',
        200,
        headers: <String, String>{'content-type': 'text/html'},
      );
    }
    if (path == '/api/obhijatra/v1/meta') {
      final g = metaGlitch;
      if (g is NoConnection) throw http.ClientException('refused', request.url);
      if (g is ErrorStatus) return _error(g.status, g.message);
      return _json(200, meta);
    }
    if (path == '/api/collections/field_users/auth-with-password') {
      final g = signInGlitch;
      if (g is NoConnection) throw http.ClientException('refused', request.url);
      if (g is ErrorStatus) return _error(g.status, g.message);
      final body = jsonDecode(request.body) as Map<String, Object?>;
      if (body['identity'] != fakeEmail || body['password'] != fakePassword) {
        return _error(400, 'Failed to authenticate.');
      }
      final token = _token('fielduser1abcde');
      _tokens[token] = 'fielduser1abcde';
      return _json(200, <String, Object?>{
        'token': token,
        'record': <String, Object?>{
          'id': 'fielduser1abcde',
          'collectionId': 'pbc_field_users',
          'collectionName': 'field_users',
          'email': fakeEmail,
          'name': 'Rahima Akter',
          'location_path': '/aaaaaaaaaaaaaaa/',
          'active': true,
        },
      });
    }
    if (path == '/api/collections/form_versions/records') {
      return _versions(request);
    }
    if (path == '/api/files/token') {
      _fileTokens.add('file-token-${_fileTokens.length}');
      return _json(200, <String, Object?>{'token': _fileTokens.last});
    }
    if (path.startsWith('/api/files/form_versions/')) return _download(request);
    if (path == '/api/obhijatra/v1/submissions') return _submit(request);
    return _error(404, 'Not found.');
  }

  http.Response _versions(http.Request request) {
    if (_tokens[request.headers['Authorization'] ?? ''] == null) {
      return _error(401, 'Sign in.');
    }
    final items = <Map<String, Object?>>[
      for (final MapEntry(:key, :value) in _published.entries)
        <String, Object?>{
          'id': 'fv${key.hashCode.abs()}'.padRight(15, '0').substring(0, 15),
          'collectionName': 'form_versions',
          'form': 'formrecord00001',
          'version': key.split('@').last,
          'xform': '${key.split('@').first}_abc123.xml',
          'published': true,
          'published_at': '2026-11-04 08:00:00.000Z',
          'expand': <String, Object?>{
            'form': <String, Object?>{
              'id': 'formrecord00001',
              'collectionName': 'forms',
              'form_id': key.split('@').first,
              'title': XFormInfo.read(value).title,
            },
          },
        },
    ];
    return _json(200, <String, Object?>{
      'page': 1,
      'perPage': 1000,
      'totalItems': items.length,
      'totalPages': 1,
      'items': items,
    });
  }

  http.Response _download(http.Request request) {
    if (!_fileTokens.contains(request.url.queryParameters['token'])) {
      return _error(404, 'Not found.');
    }
    final name = request.url.pathSegments.last;
    for (final MapEntry(:key, :value) in _published.entries) {
      if (name.startsWith('${key.split('@').first}_')) {
        return http.Response.bytes(
          utf8.encode(value),
          200,
          headers: <String, String>{'content-type': 'text/xml'},
        );
      }
    }
    return _error(404, 'Not found.');
  }

  http.Response _submit(http.Request request) {
    final g = submissionGlitch;
    if (g is NoConnection) throw http.ClientException('reset', request.url);
    if (g is ErrorStatus) return _error(g.status, g.message);
    if (_tokens[request.headers['Authorization'] ?? ''] == null) {
      return _error(401, 'Sign in.');
    }
    final xml = _xmlPart(request.headers['content-type']!, request.bodyBytes);
    final root = XmlDocument.parse(xml).rootElement;
    final instanceId = root
        .findElements('meta')
        .single
        .findElements('instanceID')
        .single
        .innerText;
    final existing = submissions[instanceId];
    if (existing != null) {
      if (existing != xml) {
        return _error(409, 'A different submission is already here.');
      }
      return _json(200, <String, Object?>{
        'id': 'sub0'.padRight(15, '0'),
        'instance_id': instanceId,
        'status': 'already_received',
      });
    }
    submissions[instanceId] = xml;
    return _json(200, <String, Object?>{
      'id': 'sub${submissions.length}'.padRight(15, '0'),
      'instance_id': instanceId,
      'status': 'received',
    });
  }

  static String _xmlPart(String contentType, Uint8List body) {
    final boundary = RegExp(r'boundary=("?)([^";]+)\1')
        .firstMatch(contentType)!
        .group(2)!;
    final text = utf8.decode(body);
    for (final chunk in text.split('--$boundary')) {
      if (chunk.contains('name="xml_submission_file"')) {
        final start = chunk.indexOf('\r\n\r\n') + 4;
        return chunk.substring(start, chunk.length - 2);
      }
    }
    throw StateError('no xml part');
  }

  static String _token(String userId) {
    String encode(Map<String, Object?> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final exp =
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/
        1000;
    return '${encode(<String, Object?>{'alg': 'HS256'})}.'
        '${encode(<String, Object?>{'id': userId, 'exp': exp, 'type': 'auth'})}.sig';
  }

  static http.Response _json(int status, Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    },
  );

  static http.Response _error(int status, String message) =>
      _json(status, <String, Object?>{
        'status': status,
        'message': message,
        'data': <String, Object?>{},
      });
}
