import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:obhijatra_core/src/forms/xform_info.dart';
import 'package:obhijatra_core/src/server/request_signer.dart';
import 'package:obhijatra_core/src/server/server_models.dart';
import 'package:obhijatra_core/src/testing/ed25519_check.dart';
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

/// The server refuses the request as its device gate does: HTTP [status]
/// with the device-trust [reason] (one of `DeviceReason`) in
/// `data.reason.code`. Used by submissions.
final class DeviceRefusal extends Glitch {
  /// Creates the glitch.
  const DeviceRefusal(this.status, this.reason);

  /// The HTTP status (401 or 403).
  final int status;

  /// The reason code.
  final String reason;
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

/// A device enrolled with a [FakeObhijatraServer].
final class FakeDevice {
  FakeDevice._({
    required this.id,
    required this.userId,
    required this.label,
    required this.platform,
    required this.signPublicKey,
    required this.encPublicKey,
  });

  /// The device id the fake gave it (15 characters).
  final String id;

  /// The field user it belongs to.
  final String userId;

  /// Its label, as sent at enrolment.
  final String label;

  /// Its platform, as sent at enrolment.
  final String platform;

  /// Its Ed25519 public key.
  final Uint8List signPublicKey;

  /// Its X25519 public key.
  final Uint8List encPublicKey;

  /// `pending`, `active` or `revoked`, as the server stores it.
  String status = 'pending';

  /// When it was approved.
  DateTime? approvedAt;

  /// When its approval runs out.
  DateTime? expires;

  /// The 18-digit check code of its keys, as the approver's app works it
  /// out.
  String get checkCode => deviceCheckCode(signPublicKey, encPublicKey);

  /// Whether it is approved and the approval has not run out at [now].
  bool usableAt(DateTime now) {
    final until = expires;
    return status == 'active' && until != null && until.isAfter(now);
  }
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
/// Device trust follows the server (docs/decisions/0008-device-trust.md):
/// `POST /api/obhijatra/v1/devices/enrol` and `GET .../devices/me` always
/// work, with the server's checks and refusals, and every signature is
/// checked with the real Ed25519 algorithm. With [requireDevices], every
/// request of a signed-in person must also be signed by an approved device
/// of theirs (a waiting one may only read its status and do what replacing
/// a one-time password needs), sessions belong to one device, and file
/// downloads need an approved device. [approveDevice] does what
/// `obhijatra-server device approve` does (it checks the code);
/// [revokeDevice], [expireDevice] and [endSessionsOf] do what an
/// organisation admin, time and the server do; [forgetDevice] what a
/// restore from an older backup does (the device's requests then get
/// `device_unknown`).
///
/// One-time passwords follow the server as well: [giveOneTimePassword] does
/// what an organisation admin does (the sign-in answer then says
/// `must_change_password`, every other request gets 403 with the reason
/// `password_change_required`, and every session of the user ends), and
/// `PATCH /api/collections/field_users/records/{own id}` with only
/// `oldPassword`, `password` and `passwordConfirm` chooses a new password
/// (at least 12 characters), which ends every session again.
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
  /// Creates a server publishing [xform], if given; [requireDevices] turns
  /// on the device checks of every request.
  FakeObhijatraServer({String? xform, this.requireDevices = false}) {
    if (xform != null) publish(xform);
  }

  /// Whether every request of a signed-in person must be signed by an
  /// approved device of theirs, as on the real server. Off by default, for
  /// tests that are not about device trust; the device routes work either
  /// way.
  bool requireDevices;

  /// Whether a newly enrolled device is approved at once (for tests that
  /// need a signed-in, approved phone without playing the approver).
  bool approveDevicesAtOnce = false;

  /// The devices enrolled, by id.
  final Map<String, FakeDevice> devices = {};

  /// The devices of the user with [email], oldest first.
  List<FakeDevice> devicesOf(String email) {
    final id = users[email]?.id;
    return [
      for (final d in devices.values)
        if (d.userId == id) d,
    ];
  }

  /// Approves the device [id] after checking [code] (spaces, dashes and
  /// Bangla digits allowed), as `obhijatra-server device approve` does: for
  /// a year from now. Throws a [StateError] when the device is unknown or
  /// switched off, or the code does not match.
  FakeDevice approveDevice(String id, String code) {
    final device = devices[id];
    if (device == null) throw StateError('No device has the id $id');
    if (device.status == 'revoked') {
      throw StateError('The device $id is switched off');
    }
    if (normaliseCheckCode(code) != device.checkCode) {
      throw StateError('The code does not match the device $id');
    }
    final now = _serverNow();
    device
      ..status = 'active'
      ..approvedAt = now
      ..expires = now.add(const Duration(days: 365));
    return device;
  }

  /// Switches the device [id] off and ends its sessions.
  void revokeDevice(String id) {
    devices[id]!.status = 'revoked';
    for (final token in [
      for (final MapEntry(:key, :value) in _sessionDevices.entries)
        if (value == id) key,
    ]) {
      final user = _tokens.remove(token);
      if (user != null) _endedSessions[token] = user;
    }
  }

  /// Forgets the device [id] as a restore from a backup older than its
  /// enrolment does: the device is gone, and so is what tied sessions to it
  /// (the sessions themselves stay; end them with [endSessionsOf] for a
  /// backup older than the sign-in too). Its keys can then be enrolled
  /// again as a new device.
  void forgetDevice(String id) {
    devices.remove(id);
    _sessionDevices.removeWhere((_, device) => device == id);
  }

  /// Makes the approval of device [id] run out (an hour ago).
  void expireDevice(String id) =>
      devices[id]!.expires = _serverNow().subtract(const Duration(hours: 1));

  /// Ends every session of the user with [email], as an organisation admin
  /// does: the session tokens still look valid, but the server answers 401
  /// with the reason `session_revoked`.
  void endSessionsOf(String email) {
    final id = users[email]!.id;
    for (final token in [
      for (final MapEntry(:key, :value) in _tokens.entries)
        if (value == id) key,
    ]) {
      _endedSessions[token] = _tokens.remove(token)!;
    }
  }

  /// Registers a file token for [userId], as `POST /api/files/token` gives
  /// one (for example, to open a download link without the app).
  String issueFileToken(String userId) {
    final token = 'file-token-${_fileTokens.length}';
    _fileTokens[token] = userId;
    return token;
  }

  /// The id of the device session [token] belongs to, if any.
  String? deviceOfSession(String token) => _sessionDevices[token];

  /// The headers of the last request that reached the fake.
  Map<String, String> lastHeaders = const {};

  /// The device signature of every request that reached the fake, in order
  /// (empty for an unsigned one).
  final List<String> signatures = [];

  /// How many of the next signed requests to refuse with the reason
  /// `device_signature_invalid` before checking them, as a server that has
  /// just restarted refuses signatures made in the second it started.
  int refuseSignatures = 0;

  /// Glitches for the next device requests (enrolment and status), used up
  /// one per request.
  final List<Glitch> deviceGlitches = [];

  final Map<String, String> _sessionDevices = {};
  final Map<String, String> _endedSessions = {};
  final Set<String> _nonces = {};
  int _deviceIds = 0;

  /// The server's clock: the phone's ([clock.now]) moved by [clockOffset].
  DateTime _serverNow() => clock.now().toUtc().add(clockOffset);

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

  /// Glitches for the next password changes (`PATCH` of a user's own
  /// record), used up one per request.
  final List<Glitch> passwordChangeGlitches = [];

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

  /// Passwords other than [fakePassword], by email.
  final Map<String, String> passwords = {};

  /// The password of the user with [email] now.
  String passwordOf(String email) => passwords[email] ?? fakePassword;

  /// Ids of the users who must choose their own password first.
  final Set<String> _mustChange = {};

  /// Gives the user with [email] the one-time [password], as an
  /// organisation admin does: they must choose their own password before
  /// anything else, and every session they have ends.
  void giveOneTimePassword(String email, String password) {
    final user = users[email]!;
    passwords[email] = password;
    _mustChange.add(user.id);
    _endSessionsOf(user.id);
  }

  /// Makes the user with [email] choose a new password before anything
  /// else, keeping their password and their sessions (the admin set only
  /// the flag): their next request with a session gets the 403.
  void requirePasswordChange(String email) => _mustChange.add(users[email]!.id);

  /// Whether the user with [email] must still choose their own password.
  bool mustChangePassword(String email) =>
      _mustChange.contains(users[email]?.id);

  /// Stored submissions by instance ID.
  final Map<String, StoredSubmission> submissions = {};

  /// Every request received, as `METHOD path`.
  final List<String> log = [];

  /// The headers of the last submission request that reached the handler.
  Map<String, String> lastSubmissionHeaders = const {};

  final Map<String, String> _published = {};
  final Map<String, String> _tokens = {};
  int _tokenSerial = 0;

  /// File tokens and the user each was given to.
  final Map<String, String> _fileTokens = {};

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
    final token = fakeToken(userId, inHours: inHours, serial: ++_tokenSerial);
    _tokens[token] = userId;
    return token;
  }

  /// Forgets every session, as when sessions expire on the server.
  void expireSessions() {
    _tokens.clear();
    _endedSessions.clear();
  }

  /// Ends every session of [userId], as a password change does (the old
  /// session tokens stop working at all).
  void _endSessionsOf(String userId) {
    _tokens.removeWhere((_, owner) => owner == userId);
    _endedSessions.removeWhere((_, owner) => owner == userId);
  }

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
    lastHeaders = request.headers;
    signatures.add(request.headers[DeviceHeaders.signature] ?? '');
    if (refuseSignatures > 0 &&
        (request.headers[DeviceHeaders.signature] ?? '').isNotEmpty) {
      refuseSignatures--;
      return _withDate(_deviceRefusal(403, DeviceReason.signatureInvalid));
    }
    FakeDevice? verified;
    if (requireDevices) {
      final gate = _deviceGate(request);
      if (gate.refusal != null) return _withDate(gate.refusal!);
      verified = gate.device;
    }
    final refused = _passwordGate(request);
    if (refused != null) return _withDate(refused);
    final response = switch (path) {
      deviceEnrolPath => _enrolDevice(request),
      deviceMePath => _deviceMe(request, verified),
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
      _ when path.startsWith(_userRecords) => _updateOwnRecord(
        request,
        path.substring(_userRecords.length),
      ),
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
    if (user == null ||
        body['password'] != passwordOf(email! as String) ||
        !user.active) {
      // One answer for every refused sign-in, as the server gives.
      return _error(
        400,
        'Sign-in failed. Check the email address and password and try again.',
      );
    }
    return _authResponse(request, email as String, user);
  }

  /// PocketBase's answer to a sign-in that worked: a session token and the
  /// user's record. A sign-in signed by a device of the user's (not
  /// switched off) ties the new session to it at once.
  http.Response _authResponse(
    http.Request request,
    String email,
    FakeFieldUser user,
  ) {
    final token = issueToken(user.id);
    if ((request.headers[DeviceHeaders.device] ?? '').isNotEmpty) {
      final signed = _verifiedDevice(request, user.id);
      if (signed.device != null) _sessionDevices[token] = signed.device!.id;
    }
    return _json(200, {'token': token, 'record': _recordOf(email, user)});
  }

  /// The user's record, as the server shows it to the user.
  Map<String, Object?> _recordOf(String email, FakeFieldUser user) => {
    'id': user.id,
    'collectionId': 'pbc_field_users',
    'collectionName': 'field_users',
    'email': email,
    'name': user.name,
    'location_path': user.locationPath,
    'phone': user.phone ?? '',
    'active': user.active,
    'must_change_password': _mustChange.contains(user.id),
  };

  static const String _userRecords = '/api/collections/field_users/records/';

  /// The server's password gate: a user who must choose their own password
  /// may only sign in, refresh the session, read or change their own
  /// record (only the password fields), and use the public routes.
  http.Response? _passwordGate(http.Request request) {
    final userId = _user(request);
    if (userId == null || !_mustChange.contains(userId)) return null;
    if (_passwordGateAllows(request, userId)) return null;
    const message = 'Choose a new password before you continue.';
    return _json(403, {
      'status': 403,
      'message': message,
      'data': {
        'reason': {'code': 'password_change_required', 'message': message},
      },
    });
  }

  /// What a person who must choose their own password may do: the public
  /// routes, sign-in and refresh, enrol this device and read its status,
  /// and read or change (only the password of) their own record; never with
  /// related records expanded.
  static bool _passwordGateAllows(http.Request request, String userId) {
    if (request.url.queryParameters.containsKey('expand')) return false;
    final path = request.url.path;
    return switch (path) {
      '/api/obhijatra/v1/meta' || '/api/obhijatra/v1/signin/methods' => true,
      deviceEnrolPath => request.method == 'POST',
      deviceMePath => request.method == 'GET',
      _
          when path.startsWith('/api/collections/field_users/auth-with-') ||
              path == '/api/collections/field_users/auth-refresh' =>
        request.method == 'POST',
      _ when path == '$_userRecords$userId' => switch (request.method) {
        'GET' => true,
        'PATCH' => _onlyPasswordFields(request),
        _ => false,
      },
      _ => false,
    };
  }

  static bool _onlyPasswordFields(http.Request request) {
    final Object? body;
    try {
      body = jsonDecode(request.body);
    } on FormatException {
      return false;
    }
    const fields = {'oldPassword', 'password', 'passwordConfirm'};
    return body is Map<String, Object?> && body.keys.every(fields.contains);
  }

  /// `PATCH` of a user's own record: only a password change, with
  /// PocketBase's checks (the old password, the repeat, then the length).
  http.Response _updateOwnRecord(http.Request request, String id) {
    final glitch = _next(passwordChangeGlitches, null);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    final userId = _user(request);
    if (userId == null) {
      return _error(
        401,
        'The request requires valid record authorization token.',
      );
    }
    final entry = users.entries.where((e) => e.value.id == id).firstOrNull;
    // The update rule hides other people's records and inactive accounts.
    if (request.method != 'PATCH' ||
        userId != id ||
        entry == null ||
        !entry.value.active) {
      return _error(404, "The requested resource wasn't found.");
    }
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final password = body['password'];
    final errors = <String, Object?>{
      if (body['oldPassword'] != passwordOf(entry.key))
        'oldPassword': {
          'code': 'validation_invalid_old_password',
          'message': 'Missing or invalid old password.',
        },
      if (body['passwordConfirm'] != password)
        'passwordConfirm': {
          'code': 'validation_values_mismatch',
          'message': "Values don't match.",
        },
    };
    if (errors.isEmpty && password is! String) {
      errors['password'] = {
        'code': 'validation_required',
        'message': 'Cannot be blank.',
      };
    } else if (errors.isEmpty && password is String) {
      final length = password.runes.length;
      if (length < 12 || length > 71) {
        errors['password'] = {
          'code': length < 12
              ? 'validation_min_text_constraint'
              : 'validation_max_text_constraint',
          'message': length < 12
              ? 'Must be at least 12 character(s)'
              : 'Must be less than 71 character(s)',
        };
      }
    }
    if (errors.isNotEmpty) {
      return _json(400, {
        'status': 400,
        'message': 'Failed to update record.',
        'data': errors,
      });
    }
    passwords[entry.key] = password! as String;
    _mustChange.remove(id);
    _endSessionsOf(id);
    return _json(200, _recordOf(entry.key, entry.value));
  }

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
    return _authResponse(request, email, current);
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
    return _authResponse(request, entry.key, entry.value);
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
    final user = _user(request);
    if (user == null) return _error(401, 'Sign in.');
    return _json(200, {'token': issueFileToken(user)});
  }

  http.Response _download(http.Request request) {
    // A protected file: only a file token opens it, as on the server.
    if (!_fileTokens.containsKey(request.url.queryParameters['token'])) {
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
    if (glitch is DeviceRefusal) {
      return _deviceRefusal(glitch.status, glitch.reason);
    }

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

  // ---- Device trust ------------------------------------------------------

  /// The server's device gate for one request (see [requireDevices]): the
  /// device that signed it, or why it is refused.
  ({FakeDevice? device, http.Response? refusal}) _deviceGate(
    http.Request request,
  ) {
    final token = request.headers['Authorization'] ?? '';
    final person = _tokens[token] ?? _endedSessions[token];
    if (person == null) {
      // Strangers and sign-in; a file token of a person needs their device.
      return (device: null, refusal: _fileTokenGate(request));
    }
    final path = request.url.path;
    if (request.method == 'POST' && path == deviceEnrolPath) {
      return (device: null, refusal: null); // checked by the route
    }
    final signed = _verifiedDevice(request, person);
    final device = signed.device;
    if (device == null) return signed;
    if (!device.usableAt(_serverNow()) && !_mayUseUnapproved(request, person)) {
      return (device: null, refusal: _unusable(device));
    }
    final session = _sessionRefusal(token, device);
    return (device: session == null ? device : null, refusal: session);
  }

  /// What a waiting device (or one whose approval ran out) may do.
  bool _mayUseUnapproved(http.Request request, String userId) {
    final path = request.url.path;
    if (path == deviceMePath && request.method == 'GET') return true;
    if (request.method == 'POST' &&
        path == '/api/collections/field_users/auth-refresh' &&
        !request.url.queryParameters.containsKey('expand')) {
      return true;
    }
    return _mustChange.contains(userId) && _passwordGateAllows(request, userId);
  }

  http.Response? _fileTokenGate(http.Request request) {
    if (!request.url.path.startsWith('/api/files/')) return null;
    final person = _fileTokens[request.url.queryParameters['token']];
    if (person == null) return null;
    final signed = _verifiedDevice(request, person);
    final device = signed.device;
    if (device == null) return signed.refusal;
    return device.usableAt(_serverNow()) ? null : _unusable(device);
  }

  http.Response _unusable(FakeDevice device) => device.status == 'active'
      ? _deviceRefusal(403, DeviceReason.expired)
      : _deviceRefusal(403, DeviceReason.notApproved);

  /// The session [token] on [device]: refused when it has ended or belongs
  /// to another device; a session no device has used yet becomes this
  /// one's.
  http.Response? _sessionRefusal(String token, FakeDevice device) {
    if (_endedSessions.containsKey(token)) {
      return _deviceRefusal(401, DeviceReason.sessionRevoked);
    }
    final bound = _sessionDevices[token];
    if (bound == null) {
      _sessionDevices[token] = device.id;
    } else if (bound != device.id) {
      return _deviceRefusal(401, DeviceReason.sessionOtherDevice);
    }
    return null;
  }

  /// The device named in [request]'s headers, if it belongs to [userId],
  /// signed this request and is not switched off; otherwise the refusal.
  ({FakeDevice? device, http.Response? refusal}) _verifiedDevice(
    http.Request request,
    String userId,
  ) {
    final id = request.headers[DeviceHeaders.device] ?? '';
    if (id.isEmpty) {
      return (
        device: null,
        refusal: _deviceRefusal(403, DeviceReason.signatureRequired),
      );
    }
    final device = devices[id];
    if (device == null || device.userId != userId) {
      // Not one of this person's devices (for example, forgotten by a
      // restore from an older backup): the phone enrols again.
      return (device: null, refusal: _deviceRefusal(403, DeviceReason.unknown));
    }
    final refusal = _signatureRefusal(request, id, device.signPublicKey);
    if (refusal != null) return (device: null, refusal: refusal);
    if (device.status == 'revoked') {
      return (device: null, refusal: _deviceRefusal(403, DeviceReason.revoked));
    }
    return (device: device, refusal: null);
  }

  /// Checks the signature headers of [request] with [signKey]: the time
  /// within 5 minutes of the server's clock, a nonce not seen before (for
  /// [scope]) and the Ed25519 signature over the exact request.
  http.Response? _signatureRefusal(
    http.Request request,
    String scope,
    List<int> signKey,
  ) {
    final time = request.headers[DeviceHeaders.time] ?? '';
    final nonce = request.headers[DeviceHeaders.nonce] ?? '';
    final signature = request.headers[DeviceHeaders.signature] ?? '';
    if (time.isEmpty || nonce.isEmpty || signature.isEmpty) {
      return _deviceRefusal(403, DeviceReason.signatureRequired);
    }
    final seconds = int.tryParse(time);
    if (seconds == null || !RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(nonce)) {
      return _deviceRefusal(403, DeviceReason.signatureInvalid);
    }
    final at = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    if (at.difference(_serverNow()).abs() > const Duration(minutes: 5)) {
      return _deviceRefusal(403, DeviceReason.clock);
    }
    final List<int> bytes;
    try {
      bytes = base64Url.decode(base64Url.normalize(signature));
    } on FormatException {
      return _deviceRefusal(403, DeviceReason.signatureInvalid);
    }
    final message = requestMessage(
      method: request.method,
      target: requestTarget(request.url),
      unixTime: time,
      nonce: nonce,
      body: request.bodyBytes,
    );
    if (!ed25519SignatureValid(signKey, message, bytes) ||
        !_nonces.add('$scope\u0000$nonce')) {
      return _deviceRefusal(403, DeviceReason.signatureInvalid);
    }
    return null;
  }

  /// `POST /api/obhijatra/v1/devices/enrol`, with the server's checks.
  http.Response _enrolDevice(http.Request request) {
    final glitch = _next(deviceGlitches, null);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    if (request.method != 'POST') {
      return _error(404, "The requested resource wasn't found.");
    }
    final token = request.headers['Authorization'] ?? '';
    final userId = _tokens[token] ?? _endedSessions[token];
    if (userId == null) {
      return _error(
        401,
        'The request requires valid record authorization token.',
      );
    }
    final Object? body;
    try {
      body = jsonDecode(request.body);
    } on FormatException {
      return _error(400, 'The request could not be read.');
    }
    if (body is! Map<String, Object?>) {
      return _error(400, 'The request could not be read.');
    }
    final signText = body['sign_public_key'];
    final encText = body['enc_public_key'];
    final signKey = _keyOf(signText);
    if (signKey == null || !ed25519KeyUsable(signKey)) {
      return _fieldError('sign_public_key', 'validation_invalid_key');
    }
    final encKey = _keyOf(encText);
    if (encKey == null || encKey.every((b) => b == 0)) {
      return _fieldError('enc_public_key', 'validation_invalid_key');
    }
    final label = body['label'] is String
        ? (body['label']! as String).trim()
        : '';
    if (label.isEmpty ||
        label.runes.length > maxDeviceLabelLength ||
        label.runes.any((r) => r < 0x20 || (r >= 0x7f && r < 0xa0))) {
      return _fieldError('label', 'validation_invalid_label');
    }
    final platform = body['platform'];
    if (!DevicePlatform.values.any((p) => p.name == platform)) {
      return _fieldError('platform', 'validation_invalid_platform');
    }
    if (request.headers[DeviceHeaders.device] != enrolDeviceId) {
      return _deviceRefusal(403, DeviceReason.signatureRequired);
    }
    // The session first, so an ended session cannot fill the nonce memory.
    if (_endedSessions.containsKey(token)) {
      return _deviceRefusal(401, DeviceReason.sessionRevoked);
    }
    // A session already tied to a device (even one that is gone) enrols
    // only that device's keys.
    final boundId = _sessionDevices[token];
    final bound = devices[boundId];
    if (boundId != null &&
        (bound == null || !_sameBytes(bound.signPublicKey, signKey))) {
      return _deviceRefusal(401, DeviceReason.sessionOtherDevice);
    }
    final refusal = _signatureRefusal(request, 'enrol:$signText', signKey);
    if (refusal != null) return refusal;

    final existing = devices.values
        .where((d) => _sameBytes(d.signPublicKey, signKey))
        .firstOrNull;
    if (existing != null) {
      if (existing.userId != userId ||
          existing.status == 'revoked' ||
          !_sameBytes(existing.encPublicKey, encKey)) {
        return _error(
          409,
          "This device's key is already in use. Clear the app's data on "
          'this device and sign in again.',
        );
      }
      _sessionDevices[token] = existing.id;
      return _json(200, _viewOf(existing));
    }
    if (bound != null) {
      return _deviceRefusal(401, DeviceReason.sessionOtherDevice);
    }
    final waiting = devices.values
        .where((d) => d.userId == userId && d.status == 'pending')
        .length;
    if (waiting >= 3) {
      return _error(
        429,
        'Too many of your devices are waiting for approval. Ask your '
        'approver to approve them or switch them off.',
      );
    }
    final device = FakeDevice._(
      id: 'device${++_deviceIds}'.padRight(15, '0'),
      userId: userId,
      label: label,
      platform: platform! as String,
      signPublicKey: signKey,
      encPublicKey: encKey,
    );
    devices[device.id] = device;
    if (approveDevicesAtOnce) approveDevice(device.id, device.checkCode);
    _sessionDevices[token] = device.id;
    return _json(200, _viewOf(device));
  }

  /// `GET /api/obhijatra/v1/devices/me`: the status of the device that
  /// signed the request ([verified] by the gate, or checked here when
  /// [requireDevices] is off).
  http.Response _deviceMe(http.Request request, FakeDevice? verified) {
    final glitch = _next(deviceGlitches, null);
    if (glitch is Redirect) return _redirect(glitch);
    if (glitch is NoConnection || glitch is LostResponse) _drop(request);
    if (glitch is ErrorStatus) return _error(glitch.status, glitch.message);
    if (request.method != 'GET') {
      return _error(404, "The requested resource wasn't found.");
    }
    var device = verified;
    if (device == null) {
      final token = request.headers['Authorization'] ?? '';
      final userId = _tokens[token] ?? _endedSessions[token];
      if (userId == null) {
        return _error(
          401,
          'The request requires valid record authorization token.',
        );
      }
      final signed = _verifiedDevice(request, userId);
      if (signed.device == null) return signed.refusal!;
      final session = _sessionRefusal(token, signed.device!);
      if (session != null) return session;
      device = signed.device!;
    }
    return _json(200, _viewOf(device));
  }

  /// The server's device view.
  Map<String, Object?> _viewOf(FakeDevice d) => {
    'id': d.id,
    'status': d.status,
    'label': d.label,
    'platform': d.platform,
    'expires': _pocketBaseDate(d.expires),
    'approved_at': _pocketBaseDate(d.approvedAt),
    'needs_second_approval': false,
    'approval_expired': d.status == 'active' && !d.usableAt(_serverNow()),
  };

  static String _pocketBaseDate(DateTime? time) =>
      time == null ? '' : time.toUtc().toIso8601String().replaceFirst('T', ' ');

  /// A public key as the server reads it: 32 bytes in standard base64 with
  /// padding, written the one canonical way.
  static Uint8List? _keyOf(Object? text) {
    if (text is! String) return null;
    try {
      final bytes = base64.decode(text);
      if (bytes.length != 32 || base64.encode(bytes) != text) return null;
      return bytes;
    } on FormatException {
      return null;
    }
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// A device-trust refusal with its reason code in `data.reason.code`, as
  /// the server words it.
  static http.Response _deviceRefusal(int status, String reason) {
    final message = switch (reason) {
      DeviceReason.signatureRequired =>
        'This device is not set up for this server yet. Sign in again on '
            'this device.',
      DeviceReason.signatureInvalid =>
        'This request could not be checked. Try again; if it keeps '
            'happening, sign in again.',
      DeviceReason.unknown =>
        'The server does not know this device. Set it up again; it will '
            'need approval again.',
      DeviceReason.clock =>
        "This device's date or time is wrong. Set the date and time, then "
            'try again.',
      DeviceReason.notApproved =>
        'This device is waiting for approval. Ask your branch manager or '
            'organisation admin to approve it.',
      DeviceReason.revoked =>
        'This device has been switched off for Obhijatra. Ask your '
            'organisation admin.',
      DeviceReason.expired =>
        "This device's approval has run out. Ask your branch manager or "
            'organisation admin to approve it again.',
      DeviceReason.sessionRevoked => 'Your session has ended. Sign in again.',
      _ =>
        'This session belongs to another device. Sign in again on this '
            'device.',
    };
    return _json(status, {
      'status': status,
      'message': message,
      'data': {
        'reason': {'code': reason, 'message': message},
      },
    });
  }

  static http.Response _fieldError(String field, String code) {
    const message = 'Invalid value.';
    return _json(400, {
      'status': 400,
      'message': 'Something went wrong while processing your request.',
      'data': {
        field: {'code': code, 'message': message},
      },
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
/// [FakeObhijatraServer.issueToken]. A [serial] makes each token unique.
String fakeToken(String userId, {int inHours = 24, int? serial}) {
  String encode(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(Duration(hours: inHours)).millisecondsSinceEpoch ~/
      1000;
  return '${encode({'alg': 'HS256'})}.'
      '${encode({'id': userId, 'exp': exp, 'type': 'auth', 'n': ?serial})}'
      '.sig';
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
