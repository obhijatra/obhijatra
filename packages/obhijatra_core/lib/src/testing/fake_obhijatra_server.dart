import 'dart:async';
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

/// The mobile number of the field user a [FakeObhijatraServer] starts with.
const String fakePhone = '+8801712345678';

/// A field user of a [FakeObhijatraServer].
final class FakeFieldUser {
  /// Creates the user.
  const FakeFieldUser({
    required this.id,
    this.name = 'Rahima Akter',
    this.locationPath = '/aaaaaaaaaaaaaaa/',
    this.active = true,
    this.phone,
    this.emailConfirmed = true,
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

  /// The mobile number for SMS-code sign-in, in international form.
  final String? phone;

  /// Whether an admin confirmed the email address; Google sign-in needs it.
  final bool emailConfirmed;
}

/// An SMS a [FakeObhijatraServer] sent: the sign-in [code] for [phone].
final class FakeSms {
  /// Creates the record.
  const FakeSms(this.phone, this.code);

  /// The number it went to.
  final String phone;

  /// The 6-digit code in it.
  final String code;
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
/// Sign-in by SMS code and by Google follow the server too: switch them on
/// with [offersPhone] and [offersGoogle]. Codes "sent" by SMS are in
/// [sentSms]; [finishGoogleSignIn] plays the person's part on Google's page
/// (the realtime connection the app holds gets the code, as the server's
/// redirect page would hand it over).
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

  /// Whether SMS-code sign-in is switched on (and an SMS provider set).
  bool offersPhone = false;

  /// Whether Google sign-in is switched on.
  bool offersGoogle = false;

  /// Whether the server has the sign-in methods route; `false` answers 404,
  /// as a server from before Google and SMS-code sign-in does.
  bool answersSignInMethods = true;

  /// The SMS messages "sent", oldest first.
  final List<FakeSms> sentSms = [];

  /// Glitches for the next meta requests, used up one per request.
  final List<Glitch> metaGlitches = [];

  /// Glitches for the next sign-in requests (password, SMS-code check and
  /// Google code exchange), used up one per request.
  final List<Glitch> signInGlitches = [];

  /// Glitches for the next requests of the sign-in methods route.
  final List<Glitch> signInMethodsGlitches = [];

  /// Glitches for the next requests for an SMS code.
  final List<Glitch> phoneCodeGlitches = [];

  /// Glitches for the next realtime connections (`GET /api/realtime`).
  final List<Glitch> realtimeGlitches = [];

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
    fakeEmail: const FakeFieldUser(id: 'fielduser1abcde', phone: fakePhone),
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

  // SMS codes by code id, and when codes were asked for, by number.
  final Map<String, _Code> _codes = {};
  final Map<String, List<DateTime>> _codeRequests = {};
  int _codeIds = 0;

  // Realtime connections by client id, and Google codes handed out.
  final Map<String, _RealtimeClient> _realtime = {};
  final Map<String, String> _googleCodes = {};
  int _realtimeIds = 0;

  /// How many realtime connections are open now (the app must close its
  /// own when a Google sign-in ends, however it ends).
  int get openRealtimeConnections => _realtime.length;

  /// The PKCE code verifier of the fake's Google provider.
  static const String googleCodeVerifier = 'fake-google-code-verifier';

  /// The redirect address the server gives Google.
  static final Uri oauth2RedirectUrl = baseUrl.replace(
    path: '/api/oauth2-redirect',
  );

  /// Plays the person's part on Google's page that [url] (the address the
  /// app opened) shows: signs in to Google as [googleEmail], or declines
  /// when [decline] is true, and lets the server's redirect page hand the
  /// answer to the app's realtime connection.
  ///
  /// Returns `false` when no connection waits for it (the app stopped
  /// waiting), as the server's redirect page would then show a failure.
  bool finishGoogleSignIn(
    Uri url, {
    String googleEmail = fakeEmail,
    bool decline = false,
  }) {
    final state = url.queryParameters['state'];
    final client = _realtime[state];
    if (url.queryParameters['redirect_uri'] != oauth2RedirectUrl.toString() ||
        client == null ||
        !client.topics.remove('@oauth2')) {
      return false;
    }
    final String data;
    if (decline) {
      data = jsonEncode({'state': state, 'code': '', 'error': 'access_denied'});
    } else {
      final code = 'google-code-${_googleCodes.length + 1}';
      _googleCodes[code] = googleEmail;
      data = jsonEncode({'state': state, 'code': code});
    }
    client.send('@oauth2', data);
    return true;
  }

  /// Ends every realtime connection, as the server does after 5 minutes
  /// without a message; with [broken], as a dropped connection does.
  Future<void> endRealtime({bool broken = false}) async {
    for (final client in _realtime.values.toList()) {
      if (broken) {
        client.controller.addError(
          http.ClientException('Connection reset by peer'),
        );
      }
      await client.controller.close();
    }
    _realtime.clear();
  }

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
  http.Client client() => MockClient.streaming(_handleStreamed);

  Future<http.StreamedResponse> _handleStreamed(
    http.BaseRequest base,
    http.ByteStream bodyStream,
  ) async {
    final bodyBytes = await bodyStream.toBytes();
    if (!isWebsite &&
        base.method == 'GET' &&
        base.url.path == '/api/realtime') {
      log.add('GET /api/realtime');
      return _connectRealtime(base);
    }
    final request = http.Request(base.method, base.url)
      ..persistentConnection = base.persistentConnection
      ..followRedirects = base.followRedirects
      ..maxRedirects = base.maxRedirects
      ..headers.addAll(base.headers)
      ..bodyBytes = bodyBytes;
    final response = await _handle(request);
    return http.StreamedResponse(
      http.ByteStream.fromBytes(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: base,
      headers: response.headers,
      isRedirect: response.isRedirect,
      reasonPhrase: response.reasonPhrase,
    );
  }

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
      '/api/obhijatra/v1/signin/methods' => _signInMethods(request),
      '/api/obhijatra/v1/signin/phone/code' => _phoneCode(request),
      '/api/obhijatra/v1/signin/phone/verify' => _phoneVerify(request),
      '/api/collections/field_users/auth-methods' => _authMethods(),
      '/api/collections/field_users/auth-with-oauth2' => _googleCode(request),
      '/api/realtime' => _realtimeSubscribe(request),
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
    return _authResponse(email as String, user);
  }

  /// PocketBase's answer to a sign-in that worked: a session token and the
  /// user's record.
  http.Response _authResponse(String email, FakeFieldUser user) => _json(200, {
    'token': issueToken(user.id),
    'record': {
      'id': user.id,
      'collectionId': 'pbc_field_users',
      'collectionName': 'field_users',
      'email': email,
      'name': user.name,
      'location_path': user.locationPath,
      'phone': user.phone ?? '',
      'active': true,
    },
  });

  http.Response _signInMethods(http.Request request) {
    final glitch = _next(signInMethodsGlitches, null);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    if (!answersSignInMethods) {
      return _error(404, "The requested resource wasn't found.");
    }
    return _json(200, {
      'password': true,
      'google': offersGoogle,
      'phone': offersPhone,
    });
  }

  http.Response _phoneCode(http.Request request) {
    final glitch = _next(phoneCodeGlitches, null);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final phone = (body['phone'] as String? ?? '').replaceAll(
      RegExp(r'[\s\-.()]'),
      '',
    );
    if (body['collection'] != 'field_users') {
      return _error(400, 'Unknown kind of account.');
    }
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      const message =
          'Enter the mobile number in international form, for example '
          '+8801712345678.';
      return _json(400, {
        'status': 400,
        'message': message,
        'data': {
          'phone': {'code': 'validation_invalid_phone', 'message': message},
        },
      });
    }
    if (!offersPhone) return _error(403, _phoneOffMessage);
    final now = clock.now();
    final asked = (_codeRequests[phone] ??= [])
      ..removeWhere((t) => now.difference(t) >= const Duration(minutes: 15));
    if (asked.length >= 3) {
      return _error(
        429,
        'Too many codes were asked for. Wait 15 minutes, or use another way '
        'to sign in.',
      );
    }
    asked.add(now);
    // The same answer whether or not the number has an account.
    final codeId = 'code${++_codeIds}'.padRight(15, '0');
    final user = users.values
        .where((u) => u.phone == phone && u.active)
        .firstOrNull;
    if (user != null) {
      final code = ((246810 + 111111 * sentSms.length) % 1000000)
          .toString()
          .padLeft(6, '0');
      _codes[codeId] = _Code(user, phone, code, now);
      sentSms.add(FakeSms(phone, code));
    }
    return _json(200, {
      'code_id': codeId,
      'expires_in': 300,
      'resend_after': 60,
    });
  }

  http.Response _phoneVerify(http.Request request) {
    final glitch = _next(signInGlitches, signInGlitch);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    if (!offersPhone) return _error(403, _phoneOffMessage);
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final codeId = body['code_id'];
    final code = body['code'];
    const wrong =
        'That code is wrong or has expired. Check the SMS, or ask for a new '
        'code.';
    final stored = _codes[codeId];
    if (stored == null ||
        code is! String ||
        !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return _error(400, wrong);
    }
    final current = users.values
        .where((u) => u.id == stored.user.id)
        .firstOrNull;
    if (clock.now().difference(stored.sentAt) > const Duration(minutes: 5) ||
        current == null ||
        !current.active ||
        current.phone != stored.phone) {
      _codes.remove(codeId);
      return _error(400, wrong);
    }
    if (code != stored.code) {
      // After 3 wrong tries the code is discarded.
      if (++stored.wrongTries >= 3) _codes.remove(codeId);
      return _error(400, wrong);
    }
    _codes.remove(codeId); // A code works once.
    final email = users.entries
        .firstWhere((e) => identical(e.value, current))
        .key;
    return _authResponse(email, current);
  }

  http.Response _authMethods() => _json(200, {
    'password': {
      'enabled': true,
      'identityFields': ['email'],
    },
    'oauth2': {
      'enabled': offersGoogle,
      'providers': [
        if (offersGoogle)
          {
            'name': 'google',
            'displayName': 'Google',
            'state': 'fakestate',
            'authURL':
                'https://accounts.google.example/o/oauth2/v2/auth'
                '?client_id=fake-client&code_challenge=fake-challenge'
                '&code_challenge_method=S256&response_type=code'
                '&scope=openid+email&state=fakestate&redirect_uri=',
            'codeVerifier': googleCodeVerifier,
            'codeChallenge': 'fake-challenge',
            'codeChallengeMethod': 'S256',
          },
      ],
    },
    'mfa': {'enabled': false, 'duration': 0},
    'otp': {'enabled': false, 'duration': 0},
  });

  http.Response _googleCode(http.Request request) {
    final glitch = _next(signInGlitches, signInGlitch);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    if (!offersGoogle) {
      return _error(
        403,
        'The collection is not configured to allow OAuth2 authentication.',
      );
    }
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final email = _googleCodes.remove(body['code']);
    if (body['provider'] != 'google' ||
        body['codeVerifier'] != googleCodeVerifier ||
        body['redirectURL'] != oauth2RedirectUrl.toString() ||
        email == null) {
      return _error(400, 'Failed to fetch OAuth2 token.');
    }
    // The server's guard: only an existing, active account whose confirmed
    // email is the Google email.
    final entry = users.entries
        .where((e) => e.key.toLowerCase() == email.toLowerCase())
        .firstOrNull;
    if (email.isEmpty) {
      return _error(
        400,
        'Google did not share a confirmed email address for this Google '
        'account. Use a Google account with a confirmed email address, or '
        'another way to sign in.',
      );
    }
    if (entry == null) {
      return _error(
        400,
        'No Obhijatra account here uses this Google email address. Ask your '
        'organisation admin to add it, or use another way to sign in.',
      );
    }
    if (!entry.value.emailConfirmed) {
      return _error(
        400,
        'Your organisation admin must confirm your email address on your '
        'account before you can sign in with Google.',
      );
    }
    if (!entry.value.active) {
      return _error(
        400,
        'This account cannot sign in. Ask your organisation admin.',
      );
    }
    return _authResponse(entry.key, entry.value);
  }

  http.StreamedResponse _connectRealtime(http.BaseRequest request) {
    final glitch = _next(realtimeGlitches, null);
    if (glitch is NoConnection || glitch is LostResponse) {
      throw http.ClientException('Connection refused', request.url);
    }
    final refusal = switch (glitch) {
      Redirect() => _redirect(glitch),
      ErrorStatus(:final status, :final message) => _error(status, message),
      _ => null,
    };
    if (refusal != null) {
      return http.StreamedResponse(
        http.ByteStream.fromBytes(refusal.bodyBytes),
        refusal.statusCode,
        headers: refusal.headers,
      );
    }
    final id = 'realtime${++_realtimeIds}'.padRight(15, '0');
    final client = _realtime[id] = _RealtimeClient(
      id,
      onCancel: () => _realtime.remove(id),
    );
    client.send('PB_CONNECT', jsonEncode({'clientId': id}));
    return http.StreamedResponse(
      client.controller.stream,
      200,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-store',
        'date': formatHttpDate(clock.now().add(clockOffset)),
      },
    );
  }

  http.Response _realtimeSubscribe(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final client = _realtime[body['clientId']];
    if (client == null) return _error(404, 'Missing or invalid client id.');
    client.topics
      ..clear()
      ..addAll((body['subscriptions'] as List<Object?>? ?? []).cast<String>());
    return http.Response('', 204);
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

  static const String _phoneOffMessage =
      'Sign-in by SMS code is switched off on this server. Use another way '
      'to sign in.';

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

/// An SMS sign-in code the fake keeps.
final class _Code {
  _Code(this.user, this.phone, this.code, this.sentAt);

  final FakeFieldUser user;
  final String phone;
  final String code;
  final DateTime sentAt;
  int wrongTries = 0;
}

/// A realtime connection the fake holds open.
final class _RealtimeClient {
  _RealtimeClient(this.id, {required void Function() onCancel})
    : controller = StreamController<List<int>>(onCancel: onCancel);

  final String id;

  /// The event stream; the fake closes it in `endRealtime`.
  final StreamController<List<int>> controller;
  final Set<String> topics = {};

  /// Sends one server-sent event, as PocketBase writes it.
  void send(String name, String data) =>
      controller.add(utf8.encode('id:$id\nevent:$name\ndata:$data\n\n'));
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
