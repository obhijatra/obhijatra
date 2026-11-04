import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:obhijatra_core/src/forms/xform_info.dart';
import 'package:xml/xml.dart';

/// The password of every field user of a [FakeObhijatraServer].
const String fakePassword = 'correct-horse-battery-1';

/// The email of the field user a [FakeObhijatraServer] starts with.
const String fakeEmail = 'field1@example.org';

/// A field user of a [FakeObhijatraServer].
final class FakeFieldUser {
  /// Creates the user.
  const FakeFieldUser({
    required this.id,
    this.name = 'Rahima Akter',
    this.locationPath = '/aaaaaaaaaaaaaaa/',
    this.active = true,
  });

  /// The `field_users` record id (15 characters).
  final String id;

  /// The display name.
  final String name;

  /// The user's place in the organisation tree.
  final String locationPath;

  /// Whether the account is active; an inactive user cannot sign in and a
  /// submission with an earlier session is refused with 403.
  final bool active;
}

/// How the fake answers one request instead of handling it normally.
sealed class Glitch {
  const Glitch();
}

/// The connection fails before the request reaches the server.
final class NoConnection extends Glitch {
  /// Creates the glitch.
  const NoConnection();
}

/// The server answers with [status] and a JSON error with [message].
final class ErrorStatus extends Glitch {
  /// Creates the glitch.
  const ErrorStatus(this.status, [this.message = 'Something went wrong.']);

  /// The HTTP status.
  final int status;

  /// The message in the body.
  final String message;
}

/// For a submission: the server stores it, but the answer never reaches the
/// phone (the connection drops after the request). Elsewhere it acts as
/// [NoConnection].
final class LostResponse extends Glitch {
  /// Creates the glitch.
  const LostResponse();
}

/// The address answers with a redirect to [location] (HTTP [status]), as a
/// public Wi-Fi sign-in page or a moved server would. Nothing is stored.
final class Redirect extends Glitch {
  /// Creates the glitch.
  const Redirect({
    this.status = 302,
    this.location = 'https://wifi-login.example.net/',
  });

  /// The HTTP status (300 to 399).
  final int status;

  /// The address in the `Location` header.
  final String location;
}

/// One part of a multipart request.
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

/// A submission the fake stored.
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

/// An in-memory stand-in for `obhijatra-server`, for app and core tests.
///
/// It follows the server's contract for what the apps use:
/// `GET /api/obhijatra/v1/meta`, field-user sign-in, published form
/// versions with protected XForm downloads (a file token from
/// `/api/files/token` is required), and `POST /api/obhijatra/v1/submissions`
/// with its idempotency (`received`, `already_received`, 409 for different
/// XML under the same instance ID, 422 for an unknown form version, 401
/// without a session, 403 for an inactive user). Every answer carries a
/// `Date` header, as the real server's do.
///
/// ```dart
/// final fake = FakeObhijatraServer(xform: myXForm);
/// final server = ObhijatraServer(
///   baseUrl: FakeObhijatraServer.baseUrl,
///   appVersion: '0.1.0',
///   httpClientFactory: fake.client,
/// );
/// fake.submissionGlitches.add(const NoConnection()); // next upload fails
/// fake.clockOffset = const Duration(hours: 1);       // server clock ahead
/// ```
///
/// The end-to-end test in `obhijatra_core` runs the real server instead.
final class FakeObhijatraServer {
  /// Creates a server publishing [xform], if given.
  FakeObhijatraServer({String? xform}) {
    if (xform != null) publish(xform);
  }

  /// The address to give the client; any address works.
  static final Uri baseUrl = Uri.parse('https://data.example.org');

  /// The answer to the meta route.
  Map<String, Object?> meta = {
    'server_version': '0.1.0-dev',
    'schema_version': 3,
    'api_version': '1',
    'min_client_version': '0.1.0',
  };

  /// How far the server's clock is ahead of the phone's (negative: behind).
  /// The `Date` header is the phone's time ([clock.now], so a test's fake
  /// clock counts) moved by this offset.
  Duration clockOffset = Duration.zero;

  /// Answer every request with a web page, as an address that is a website
  /// and not an Obhijatra server would.
  bool isWebsite = false;

  /// Glitches for the next meta requests, used up one per request.
  final List<Glitch> metaGlitches = [];

  /// Glitches for the next sign-in requests, used up one per request.
  final List<Glitch> signInGlitches = [];

  /// Glitches for the next submission requests, used up one per request.
  final List<Glitch> submissionGlitches = [];

  /// A glitch for every meta request while set, once [metaGlitches] is
  /// empty.
  Glitch? metaGlitch;

  /// A glitch for every sign-in while set, once [signInGlitches] is empty.
  Glitch? signInGlitch;

  /// A glitch for every submission while set, once [submissionGlitches] is
  /// empty.
  Glitch? submissionGlitch;

  /// Field users by email.
  final Map<String, FakeFieldUser> users = {
    fakeEmail: const FakeFieldUser(id: 'fielduser1abcde'),
  };

  /// Stored submissions by instance ID.
  final Map<String, StoredSubmission> submissions = {};

  /// Every request received, as `METHOD path`.
  final List<String> log = [];

  /// The headers of the last submission request that reached the handler.
  Map<String, String> lastSubmissionHeaders = const {};

  final Map<String, String> _published = {};
  final Map<String, String> _tokens = {};
  final List<String> _fileTokens = [];

  /// Publishes [xform] as a form version.
  void publish(String xform) {
    final info = XFormInfo.read(xform);
    _published['${info.formId}@${info.version}'] = xform;
  }

  /// Registers a session token for [userId], as if the user signed in
  /// earlier, expiring [inHours] from now.
  String issueToken(String userId, {int inHours = 24}) {
    final token = fakeToken(userId, inHours: inHours);
    _tokens[token] = userId;
    return token;
  }

  /// Forgets every session, as when sessions expire on the server.
  void expireSessions() => _tokens.clear();

  /// An HTTP client routed to this fake.
  http.Client client() => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    log.add('${request.method} $path');
    if (isWebsite) {
      return _withDate(
        http.Response(
          '<html><body>Hello</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      );
    }
    final response = switch (path) {
      '/api/obhijatra/v1/meta' => _meta(request),
      '/api/collections/field_users/auth-with-password' => _signIn(request),
      '/api/collections/form_versions/records' => _listVersions(request),
      '/api/files/token' => _fileToken(request),
      '/api/obhijatra/v1/submissions' => _submit(request),
      _ when path.startsWith('/api/files/form_versions/') => _download(request),
      _ => _error(404, "The requested resource wasn't found."),
    };
    return _withDate(response);
  }

  http.Response _withDate(http.Response response) => http.Response.bytes(
    response.bodyBytes,
    response.statusCode,
    headers: {
      ...response.headers,
      'date': formatHttpDate(clock.now().add(clockOffset)),
    },
  );

  static http.Response _redirect(Redirect glitch) => http.Response(
    '<html><body>Moved</body></html>',
    glitch.status,
    headers: {'location': glitch.location, 'content-type': 'text/html'},
  );

  static Glitch? _next(List<Glitch> queue, Glitch? always) =>
      queue.isNotEmpty ? queue.removeAt(0) : always;

  static Never _drop(http.Request request) =>
      throw http.ClientException('Connection refused', request.url);

  String? _user(http.Request request) =>
      _tokens[request.headers['Authorization'] ?? ''];

  http.Response _meta(http.Request request) {
    final glitch = _next(metaGlitches, metaGlitch);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    return _json(200, meta);
  }

  http.Response _signIn(http.Request request) {
    final glitch = _next(signInGlitches, signInGlitch);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final email = body['identity'];
    final user = users[email];
    if (user == null || body['password'] != fakePassword || !user.active) {
      // One answer for every refused sign-in, as the server gives.
      return _error(
        400,
        'Sign-in failed. Check the email address and password and try again.',
      );
    }
    return _json(200, {
      'token': issueToken(user.id),
      'record': {
        'id': user.id,
        'collectionId': 'pbc_field_users',
        'collectionName': 'field_users',
        'email': email,
        'name': user.name,
        'location_path': user.locationPath,
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

  http.Response _fileToken(http.Request request) {
    if (_user(request) == null) return _error(401, 'Sign in.');
    _fileTokens.add('file-token-${_fileTokens.length}');
    return _json(200, {'token': _fileTokens.last});
  }

  http.Response _download(http.Request request) {
    // A protected file: only a file token opens it, as on the server.
    if (!_fileTokens.contains(request.url.queryParameters['token'])) {
      return _error(404, "The requested resource wasn't found.");
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
    return _error(404, "The requested resource wasn't found.");
  }

  http.Response _submit(http.Request request) {
    final glitch = _next(submissionGlitches, submissionGlitch);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection) {
      throw http.ClientException('Connection reset by peer', request.url);
    }
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);

    final userId = _user(request);
    if (userId == null) {
      return _error(
        401,
        'The request requires valid record authorization token.',
      );
    }
    final active = users.values.any((u) => u.id == userId && u.active);
    if (!active) {
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
      if (existing.userId != userId || existing.xml != xml) {
        return _error(
          409,
          'A different submission with this instance ID is already on the '
          'server. It was not replaced.',
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
    submissions[instanceId] = StoredSubmission(id, xml, userId, parts);
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
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static http.Response _error(int status, String message) => _json(status, {
    'status': status,
    'message': message,
    'data': <String, Object?>{},
  });
}

/// A session token PocketBase's `AuthStore.isValid` accepts for [userId],
/// expiring [inHours] from now (negative for an expired token). It is not
/// signed; only a [FakeObhijatraServer] accepts it, after
/// [FakeObhijatraServer.issueToken].
String fakeToken(String userId, {int inHours = 24}) {
  String encode(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(Duration(hours: inHours)).millisecondsSinceEpoch ~/
      1000;
  return '${encode({'alg': 'HS256'})}.'
      '${encode({'id': userId, 'exp': exp, 'type': 'auth'})}.sig';
}

/// Splits a `multipart/form-data` [body] using the boundary in
/// [contentType].
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
