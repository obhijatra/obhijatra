// An in-memory stand-in for obhijatra-server, for unit tests. It follows
// the contract of server/internal/api (meta, submissions with SHA-256
// idempotency) and PocketBase's auth and record routes closely enough for
// the client and sync engine; the end-to-end test runs the real binary.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:xml/xml.dart';

/// A field user's password in the fake server.
const String fakePassword = 'correct-horse-battery-1';

/// One multipart part.
final class Part {
  /// Creates a part.
  Part(this.name, this.filename, this.contentType, this.bytes);

  /// The form field name.
  final String name;

  /// The file name, if any.
  final String? filename;

  /// The part's content type, if any.
  final String? contentType;

  /// The content.
  final Uint8List bytes;
}

/// Splits a multipart/form-data [body] using the boundary in [contentType].
List<Part> parseMultipart(String contentType, Uint8List body) {
  final boundary = RegExp(r'boundary=("?)([^";]+)\1').firstMatch(contentType)!;
  final text = latin1.decode(body);
  final parts = <Part>[];
  for (final chunk in text.split('--${boundary.group(2)}')) {
    if (chunk.isEmpty || chunk.startsWith('--')) continue;
    final content = chunk.substring(2, chunk.length - 2); // CRLF framing
    final split = content.indexOf('\r\n\r\n');
    final headers = content.substring(0, split).split('\r\n');
    final disposition = headers.firstWhere(
      (h) => h.toLowerCase().startsWith('content-disposition'),
    );
    final type = headers
        .where((h) => h.toLowerCase().startsWith('content-type'))
        .map((h) => h.substring(h.indexOf(':') + 1).trim())
        .firstOrNull;
    parts.add(
      Part(
        RegExp(r'name="([^"]*)"').firstMatch(disposition)!.group(1)!,
        RegExp(r'filename="([^"]*)"').firstMatch(disposition)?.group(1),
        type,
        Uint8List.fromList(latin1.encode(content.substring(split + 4))),
      ),
    );
  }
  return parts;
}

/// A token PocketBase's `AuthStore.isValid` accepts, expiring [inHours]
/// from now (negative for an expired token).
String fakeToken(String userId, {int inHours = 24}) {
  String encode(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(Duration(hours: inHours)).millisecondsSinceEpoch ~/
      1000;
  return '${encode({'alg': 'HS256'})}.'
      '${encode({'id': userId, 'exp': exp, 'type': 'auth'})}.sig';
}

/// How the fake answers one request, instead of handling it normally.
sealed class Glitch {
  const Glitch();
}

/// The connection fails before reaching the server.
final class NoConnection extends Glitch {
  /// Creates the glitch.
  const NoConnection();
}

/// The server answers with [status] and a JSON error.
final class ErrorStatus extends Glitch {
  /// Creates the glitch.
  const ErrorStatus(this.status, [this.message = 'Something went wrong.']);

  /// The HTTP status.
  final int status;

  /// The message in the body.
  final String message;
}

/// The server stores the submission, but the answer never reaches the
/// phone (the connection drops after the request).
final class LostResponse extends Glitch {
  /// Creates the glitch.
  const LostResponse();
}

/// A stored submission.
final class StoredSubmission {
  /// Creates the record.
  StoredSubmission(this.id, this.xml, this.userId, this.parts);

  /// The record id.
  final String id;

  /// The XML as received.
  final String xml;

  /// Who sent it.
  final String userId;

  /// Every part of the request.
  final List<Part> parts;
}

/// The fake server.
final class FakeObhijatraServer {
  /// Creates a server publishing the sample form.
  FakeObhijatraServer({String? xform}) {
    if (xform != null) publish(xform);
  }

  /// The base URL the client should use.
  static final Uri baseUrl = Uri.parse('http://fake.obhijatra.test');

  /// The meta answer.
  Map<String, Object?> meta = {
    'server_version': '0.1.0-dev',
    'schema_version': 1,
    'api_version': '1',
    'min_client_version': '0.1.0',
  };

  /// Glitches to apply to the next submission requests, in order.
  final List<Glitch> submissionGlitches = [];

  /// Glitches to apply to the next meta requests, in order.
  final List<Glitch> metaGlitches = [];

  /// Stored submissions by instance id.
  final Map<String, StoredSubmission> submissions = {};

  /// Every request received, as `METHOD path`.
  final List<String> log = [];

  /// The last submission request's headers.
  Map<String, String> lastSubmissionHeaders = const {};

  /// Published form versions: `formId@version` to XForm XML.
  final Map<String, String> _published = {};

  /// Valid tokens to user ids.
  final Map<String, String> _tokens = {};

  /// File tokens issued by `/api/files/token`.
  final List<String> _fileTokens = [];

  /// Field users: email to user id.
  final Map<String, String> users = {'field1@example.org': 'fielduser1abcde'};

  /// Whether the field user is active.
  bool userActive = true;

  /// Publishes [xform].
  void publish(String xform) {
    final info = XFormInfo.read(xform);
    _published['${info.formId}@${info.version}'] = xform;
  }

  /// Registers a token for [userId] (as if the user signed in earlier).
  String issueToken(String userId, {int inHours = 24}) {
    final token = fakeToken(userId, inHours: inHours);
    _tokens[token] = userId;
    return token;
  }

  /// An HTTP client routed to this fake.
  http.Client client() => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    log.add('${request.method} $path');
    if (path == '/api/obhijatra/v1/meta') {
      if (metaGlitches.isNotEmpty) {
        final glitch = metaGlitches.removeAt(0);
        if (glitch is NoConnection) {
          throw http.ClientException('Connection refused', request.url);
        }
        if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
      }
      return _json(200, meta);
    }
    if (path == '/api/collections/field_users/auth-with-password') {
      return _signIn(request);
    }
    if (path == '/api/collections/form_versions/records') {
      return _listVersions(request);
    }
    if (path == '/api/files/token') {
      if (_user(request) == null) return _error(401, 'Sign in.');
      _fileTokens.add('file-token-${_fileTokens.length}');
      return _json(200, {'token': _fileTokens.last});
    }
    if (path.startsWith('/api/files/form_versions/')) {
      return _download(request);
    }
    if (path == '/api/obhijatra/v1/submissions') {
      return _submit(request);
    }
    return _error(404, 'Not found.');
  }

  String? _user(http.Request request) =>
      _tokens[request.headers['Authorization'] ?? ''];

  http.Response _signIn(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final id = users[body['identity']];
    if (id == null || body['password'] != fakePassword || !userActive) {
      return _error(400, 'Failed to authenticate.');
    }
    final token = issueToken(id);
    return _json(200, {
      'token': token,
      'record': {
        'id': id,
        'collectionId': 'pbc_field_users',
        'collectionName': 'field_users',
        'email': body['identity'],
        'name': 'Field One',
        'location_path': '/aaaaaaaaaaaaaaa/bbbbbbbbbbbbbbb/',
        'active': true,
      },
    });
  }

  http.Response _listVersions(http.Request request) {
    if (_user(request) == null) return _error(401, 'Sign in.');
    final items = [
      for (final MapEntry(:key, :value) in _published.entries)
        {
          'id': 'fv${key.hashCode.abs()}'.padRight(15, '0').substring(0, 15),
          'collectionName': 'form_versions',
          'form': 'formrecord00001',
          'version': key.split('@').last,
          'xform': '${key.split('@').first}_abc123.xml',
          'published': true,
          'published_at': '2026-11-04 08:00:00.000Z',
          'expand': {
            'form': {
              'id': 'formrecord00001',
              'collectionName': 'forms',
              'form_id': key.split('@').first,
              'title': XFormInfo.read(value).title,
            },
          },
        },
    ];
    return _json(200, {
      'page': 1,
      'perPage': 1000,
      'totalItems': items.length,
      'totalPages': 1,
      'items': items,
    });
  }

  http.Response _download(http.Request request) {
    // Treated as a protected file: a file token is required.
    if (!_fileTokens.contains(request.url.queryParameters['token'])) {
      return _error(404, 'The requested resource wasn\'t found.');
    }
    final fileName = request.url.pathSegments.last;
    for (final MapEntry(:key, :value) in _published.entries) {
      if (fileName.startsWith('${key.split('@').first}_')) {
        return http.Response.bytes(
          utf8.encode(value),
          200,
          headers: {'content-type': 'text/xml'},
        );
      }
    }
    return _error(404, 'Not found.');
  }

  Future<http.Response> _submit(http.Request request) async {
    final glitch = submissionGlitches.isEmpty
        ? null
        : submissionGlitches.removeAt(0);
    if (glitch is NoConnection) {
      throw http.ClientException('Connection reset by peer', request.url);
    }
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);

    final user = _user(request);
    if (user == null) {
      return _error(
        401,
        'The request requires valid record authorization token.',
      );
    }
    if (!userActive) {
      return _error(
        403,
        'This account is not active. Please contact your organisation admin.',
      );
    }
    lastSubmissionHeaders = request.headers;
    final parts = parseMultipart(
      request.headers['content-type']!,
      request.bodyBytes,
    );
    final xmlParts = parts.where((p) => p.name == 'xml_submission_file');
    if (xmlParts.length != 1) {
      return _error(400, 'Send exactly one "xml_submission_file" part.');
    }
    final xml = utf8.decode(xmlParts.single.bytes);
    final root = XmlDocument.parse(xml).rootElement;
    final formId = root.getAttribute('id');
    final version = root.getAttribute('version');
    final instanceId = root
        .findElements('meta')
        .single
        .findElements('instanceID')
        .single
        .innerText;

    final existing = submissions[instanceId];
    if (existing != null) {
      if (existing.userId != user || existing.xml != xml) {
        return _error(
          409,
          'A different submission with this instance ID is already on the server. It was not replaced.',
        );
      }
      return _json(200, {
        'id': existing.id,
        'instance_id': instanceId,
        'status': 'already_received',
        'message': 'This submission was already received. Nothing was changed.',
      });
    }
    if (!_published.containsKey('$formId@$version')) {
      return _error(
        422,
        'Version "$version" of form "$formId" is not on this server.',
      );
    }
    final id = 'sub${submissions.length}'.padRight(15, '0');
    submissions[instanceId] = StoredSubmission(id, xml, user, parts);
    if (glitch is LostResponse) {
      throw http.ClientException(
        'Connection closed before full header was received',
        request.url,
      );
    }
    return _json(200, {
      'id': id,
      'instance_id': instanceId,
      'status': 'received',
      'message': 'Submission received.',
    });
  }

  static http.Response _json(int status, Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
  );

  static http.Response _error(int status, String message) => _json(status, {
    'status': status,
    'message': message,
    'data': <String, Object?>{},
  });
}
