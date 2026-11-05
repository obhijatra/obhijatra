import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:obhijatra_core/src/phone_number.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/server/realtime_channel.dart';
import 'package:obhijatra_core/src/server/request_signer.dart';
import 'package:obhijatra_core/src/server/server_models.dart';
import 'package:pocketbase/pocketbase.dart';

/// Reads the files sent with submissions, and removes them once the server
/// holds them; implemented by the app (for example with `dart:io`), so the
/// core stays free of platform libraries.
abstract interface class AttachmentStore {
  /// Returns the bytes of the file at [path]; throws an
  /// [ObhijatraException] with [ProblemCode.attachmentMissing] if it is gone.
  Future<Uint8List> read(String path);

  /// Removes the file at [path] after the server confirmed the submission it
  /// belongs to. A file that is already gone is not an error; a path outside
  /// the store's folder is never touched.
  Future<void> delete(String path);
}

/// The multipart part that carries the instance XML (the OpenRosa name).
const String xmlPartName = 'xml_submission_file';

/// Opens a web address in a secure browser tab (Chrome Custom Tabs,
/// `SFSafariViewController`) for Google sign-in; supplied by the app, so the
/// core stays free of platform libraries. Throws an [ObhijatraException]
/// with [ProblemCode.browserUnavailable] when nothing can open it.
typedef OpenBrowser = Future<void> Function(Uri url);

/// Talks to one `obhijatra-server`: the version handshake, field-user
/// sign-in (email and password, SMS code, Google), published forms and
/// submission upload.
///
/// Every failure is an [ObhijatraException] with a plain-language
/// [ProblemCode]; raw transport exceptions never leave this class.
final class ObhijatraServer {
  /// Connects to the server at [baseUrl] as app release [appVersion].
  ///
  /// Pass an [authStore] that persists the session (see
  /// `SettingsRepository.authStore`); [signer] adds device signatures once
  /// the zero-trust milestone ships; [httpClientFactory] is for tests.
  ObhijatraServer({
    required Uri baseUrl,
    required this.appVersion,
    AuthStore? authStore,
    RequestSigner signer = const UnsignedRequests(),
    http.Client Function()? httpClientFactory,
    Duration timeout = const Duration(seconds: 60),
  }) {
    final innerFactory = httpClientFactory ?? http.Client.new;
    http.Client signing() =>
        SigningHttpClient(innerFactory(), signer: signer, timeout: timeout);
    _newClient = signing;
    _pb = PocketBase(
      baseUrl.toString(),
      authStore: authStore,
      httpClientFactory: signing,
    );
    _http = signing();
  }

  /// The app release reported to, and checked against, the server.
  final String appVersion;

  late final PocketBase _pb;
  late final http.Client _http;
  late final http.Client Function() _newClient;

  /// Realtime connections of Google sign-ins in progress.
  final Set<RealtimeChannel> _channels = {};

  /// The route prefix of Obhijatra's own API.
  static const String apiPrefix = '/api/obhijatra/v1';

  /// The auth collection of field users.
  static const String fieldUsersCollection = 'field_users';

  /// The name of Google among the server's OAuth2 providers.
  static const String googleProvider = 'google';

  /// The realtime topic on which the server hands back an OAuth2 code.
  static const String _oauth2Topic = '@oauth2';

  /// Whether a field user is signed in with an unexpired session.
  bool get hasValidSession {
    final store = _pb.authStore;
    if (store.record?.collectionName != fieldUsersCollection) return false;
    try {
      return store.isValid;
    } on Object {
      return false; // A malformed stored token is no session.
    }
  }

  /// The signed-in field user, if any (even if the session has expired).
  SignedInUser? get currentUser {
    final record = _pb.authStore.record;
    if (record == null || record.collectionName != fieldUsersCollection) {
      return null;
    }
    return _userOf(record);
  }

  /// Asks the server which versions it runs (public; no sign-in needed).
  ///
  /// [ServerMeta.serverTime] is read from the answer's HTTP `Date` header,
  /// so the sync engine can compare the server's clock with the phone's.
  Future<ServerMeta> fetchMeta() async {
    final response = await _sendRaw(
      http.Request('GET', _pb.buildURL('$apiPrefix/meta')),
    );
    if (response.statusCode >= 400) {
      throw _problemForStatus(
        response.statusCode,
        _messageOf(response),
        onBadRequest: ProblemCode.unexpectedResponse,
      );
    }
    return ServerMeta.fromJson(
      _asJsonObject(_decodeJson(response)),
      serverTime: _dateOf(response),
    );
  }

  /// Signs in a field user with [email] and [password].
  Future<SignedInUser> signIn({
    required String email,
    required String password,
  }) async {
    final auth = await _pocketBase(
      () => _pb
          .collection(fieldUsersCollection)
          .authWithPassword(email.trim(), password),
      onBadRequest: ProblemCode.signInFailed,
    );
    return _userOf(auth.record);
  }

  /// Asks the server which ways to sign in it offers (public; no sign-in
  /// needed). A server from before Google and SMS-code sign-in (HTTP 404)
  /// offers email and password only.
  Future<SignInMethods> fetchSignInMethods() async {
    final response = await _sendRaw(
      http.Request('GET', _pb.buildURL('$apiPrefix/signin/methods')),
    );
    if (response.statusCode == 404) return SignInMethods.passwordOnly;
    if (response.statusCode != 200) {
      throw _problemForStatus(
        response.statusCode,
        _messageOf(response),
        onBadRequest: ProblemCode.unexpectedResponse,
      );
    }
    return SignInMethods.fromJson(_asJsonObject(_decodeJson(response)));
  }

  /// Asks the server to send a 6-digit sign-in code by SMS to [phone], in
  /// international form (see `parsePhoneNumber`).
  ///
  /// The answer is the same whether or not the number belongs to an
  /// account, so it never tells who has one. Failures:
  /// [ProblemCode.phoneNumberInvalid], [ProblemCode.signInMethodOff] (SMS
  /// sign-in switched off) and [ProblemCode.tooManySignInCodes].
  Future<PhoneCodeRequest> requestPhoneCode(String phone) async {
    if (!e164Pattern.hasMatch(phone)) {
      throw const ObhijatraException(ProblemCode.phoneNumberInvalid);
    }
    final response = await _postJson('$apiPrefix/signin/phone/code', {
      'collection': fieldUsersCollection,
      'phone': phone,
    });
    if (response.statusCode != 200) {
      throw _problemForStatus(
        response.statusCode,
        _messageOf(response),
        onBadRequest: ProblemCode.phoneNumberInvalid,
        overrides: const {
          403: ProblemCode.signInMethodOff,
          404: ProblemCode.signInMethodOff,
          429: ProblemCode.tooManySignInCodes,
        },
      );
    }
    final json = _asJsonObject(_decodeJson(response));
    final codeId = json['code_id'];
    final expiresIn = json['expires_in'];
    final resendAfter = json['resend_after'];
    if (codeId is! String ||
        codeId.isEmpty ||
        expiresIn is! num ||
        resendAfter is! num) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    return PhoneCodeRequest(
      codeId: codeId,
      phone: phone,
      expiresIn: Duration(seconds: expiresIn.toInt()),
      resendAfter: Duration(seconds: resendAfter.toInt()),
    );
  }

  /// Signs in a field user with the [code] from the SMS sent for [codeId]
  /// (see [requestPhoneCode]); Bangla digits are read as digits.
  ///
  /// Every refused code gets [ProblemCode.signInCodeWrong]: wrong, expired,
  /// already used, or discarded after 3 wrong tries. Wrong codes count
  /// towards the same lock as wrong passwords. Other failures:
  /// [ProblemCode.signInMethodOff] and [ProblemCode.tooManyCodeTries].
  Future<SignedInUser> signInWithPhoneCode({
    required String codeId,
    required String code,
  }) async {
    final digits = toAsciiDigits(code.trim());
    if (codeId.isEmpty ||
        !RegExp('^[0-9]{$phoneCodeLength}\$').hasMatch(digits)) {
      throw const ObhijatraException(ProblemCode.signInCodeWrong);
    }
    final response = await _postJson('$apiPrefix/signin/phone/verify', {
      'code_id': codeId,
      'code': digits,
    });
    if (response.statusCode != 200) {
      throw _problemForStatus(
        response.statusCode,
        _messageOf(response),
        onBadRequest: ProblemCode.signInCodeWrong,
        overrides: const {
          403: ProblemCode.signInMethodOff,
          404: ProblemCode.signInMethodOff,
          429: ProblemCode.tooManyCodeTries,
        },
      );
    }
    return _saveSession(_decodeJson(response));
  }

  /// Signs in a field user with Google, through the server's own OAuth2
  /// flow: [openBrowser] shows Google's page, and the server hands the
  /// answer back over a realtime connection that lives only as long as this
  /// call.
  ///
  /// [cancellation] stops waiting at once (the person left Google's page):
  /// the call throws [ProblemCode.signInCancelled], the realtime connection
  /// closes, and a sign-in that completes afterwards is thrown away, never
  /// saved. Declining on Google's page is [ProblemCode.signInCancelled]
  /// too. The server refuses ([ProblemCode.googleSignInRefused]) a Google
  /// account whose email no active, admin-confirmed account here uses;
  /// [ProblemCode.signInMethodOff] means Google sign-in is switched off.
  Future<SignedInUser> signInWithGoogle(
    OpenBrowser openBrowser, {
    SignInCancellation? cancellation,
  }) async {
    final cancel = cancellation ?? SignInCancellation();
    final provider = await _unlessCancelled(cancel, _googleProviderInfo());
    final channel = await _unlessCancelled(
      cancel,
      _connectRealtime(),
      discard: (late) => late.close(),
    );
    _channels.add(channel);
    unawaited(cancel.whenCancelled.then((_) => channel.close()));
    try {
      await _unlessCancelled(cancel, _subscribe(channel, _oauth2Topic));
      final answer = channel.next(_oauth2Topic);
      final redirectUrl = _pb.buildURL('/api/oauth2-redirect');
      final authUrl = _googleAuthUrl(provider, redirectUrl, channel.clientId);
      await _unlessCancelled(cancel, _open(openBrowser, authUrl));
      final event = await _unlessCancelled(cancel, _realtimeEvent(answer));
      channel.close(); // One answer is all it is for.
      final code = _oauth2CodeOf(event, channel.clientId);
      final response = await _unlessCancelled(
        cancel,
        _postJson('/api/collections/$fieldUsersCollection/auth-with-oauth2', {
          'provider': provider.name,
          'code': code,
          'codeVerifier': provider.codeVerifier,
          'redirectURL': redirectUrl.toString(),
        }),
      );
      if (response.statusCode != 200) {
        throw _problemForStatus(
          response.statusCode,
          _messageOf(response),
          onBadRequest: ProblemCode.googleSignInRefused,
          overrides: const {403: ProblemCode.signInMethodOff},
        );
      }
      return _saveSession(_decodeJson(response));
    } finally {
      channel.close();
      _channels.remove(channel);
    }
  }

  /// Forgets the session on this device.
  void signOut() => _pb.authStore.clear();

  /// Lists every form version the server has published to this user.
  Future<List<RemoteFormVersion>> listPublishedFormVersions() async {
    _requireSession();
    final records = await _pocketBase(
      () => _pb
          .collection('form_versions')
          .getFullList(
            filter: 'published = true',
            expand: 'form',
            sort: 'created',
          ),
    );
    return [for (final r in records) _formVersionOf(r)];
  }

  /// Downloads the XForm XML of [version].
  ///
  /// Uses a short-lived file token, so the download keeps working if the
  /// server marks the `xform` file field as protected.
  Future<String> downloadXForm(RemoteFormVersion version) async {
    _requireSession();
    final fileToken = await _pocketBase(() => _pb.files.getToken());
    final url = _pb.buildURL(
      '/api/files/form_versions/'
      '${Uri.encodeComponent(version.serverId)}/'
      '${Uri.encodeComponent(version.xformFileName)}',
      {'token': fileToken},
    );
    final request = http.Request('GET', url);
    final response = await _sendRaw(request);
    if (response.statusCode != 200) {
      throw _problemForStatus(response.statusCode, _messageOf(response));
    }
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException catch (e) {
      throw ObhijatraException(ProblemCode.formInvalid, cause: e);
    }
  }

  /// Uploads one finalised submission: [instanceXml] as
  /// `xml_submission_file` plus each file in [attachmentPaths], read from
  /// [attachments] and sent under its file name, which the XML refers to.
  ///
  /// The server is idempotent on the instance id: a retry of the same
  /// bytes is acknowledged as [ReceiptStatus.alreadyReceived].
  Future<SubmissionReceipt> submit({
    required String instanceXml,
    List<String> attachmentPaths = const [],
    AttachmentStore? attachments,
  }) async {
    _requireSession();
    final request =
        http.MultipartRequest('POST', _pb.buildURL('$apiPrefix/submissions'))
          ..headers['Authorization'] = _pb.authStore.token
          ..files.add(
            http.MultipartFile.fromBytes(
              xmlPartName,
              utf8.encode(instanceXml),
              filename: 'submission.xml',
              contentType: MediaType('text', 'xml', {'charset': 'utf-8'}),
            ),
          );
    for (final path in attachmentPaths) {
      if (attachments == null) {
        throw const ObhijatraException(ProblemCode.attachmentMissing);
      }
      final Uint8List bytes;
      try {
        bytes = await attachments.read(path);
      } on ObhijatraException {
        rethrow;
      } on Object catch (e) {
        throw ObhijatraException(ProblemCode.attachmentMissing, cause: e);
      }
      final name = fileNameOf(path);
      request.files.add(
        http.MultipartFile.fromBytes(name, bytes, filename: name),
      );
    }

    final response = await _sendRaw(request);
    if (response.statusCode != 200) {
      throw _problemForStatus(response.statusCode, _messageOf(response));
    }
    final json = _asJsonObject(_decodeJson(response));
    final id = json['id'];
    final instanceId = json['instance_id'];
    final status = switch (json['status']) {
      'received' => ReceiptStatus.received,
      'already_received' => ReceiptStatus.alreadyReceived,
      _ => null,
    };
    if (id is! String || instanceId is! String || status == null) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    return SubmissionReceipt(
      serverId: id,
      instanceId: instanceId,
      status: status,
    );
  }

  /// Releases the network connections, including the realtime connection
  /// of a Google sign-in in progress (which then ends as cancelled).
  void close() {
    for (final channel in _channels.toList()) {
      channel.close();
    }
    _pb.close();
    _http.close();
  }

  /// The last path segment of [path], for `/` and `\` separators.
  static String fileNameOf(String path) => path
      .split(RegExp(r'[/\\]'))
      .lastWhere((s) => s.isNotEmpty, orElse: () => path);

  // -------------------------------------------------------------------

  void _requireSession() {
    if (!hasValidSession) {
      throw const ObhijatraException(ProblemCode.signInRequired);
    }
  }

  Future<http.Response> _sendRaw(http.BaseRequest request) async {
    try {
      return await http.Response.fromStream(await _http.send(request));
    } on Object catch (e) {
      final problem = _transportProblem(e);
      if (problem == null) rethrow;
      throw problem;
    }
  }

  /// Posts [body] as JSON to [path]. No session token is sent: sign-in
  /// routes must not see one (PocketBase would link a Google account to it).
  Future<http.Response> _postJson(String path, Map<String, Object?> body) =>
      _sendRaw(
        http.Request('POST', _pb.buildURL(path))
          ..headers['content-type'] = 'application/json'
          ..bodyBytes = utf8.encode(jsonEncode(body)),
      );

  /// The plain problem for a failure of the HTTP transport, or `null` for
  /// anything else.
  static ObhijatraException? _transportProblem(Object error) => switch (error) {
    RedirectNotFollowed(:final statusCode) => ObhijatraException(
      ProblemCode.redirected,
      statusCode: statusCode,
      cause: error,
    ),
    TimeoutException() => ObhijatraException(ProblemCode.timeout, cause: error),
    http.ClientException() => ObhijatraException(
      ProblemCode.offline,
      cause: error,
    ),
    _ => null,
  };

  /// Stores the session in a sign-in answer (`token` and the `record` of
  /// the field user, as PocketBase answers) and returns the user.
  SignedInUser _saveSession(Object? json) {
    final body = _asJsonObject(json);
    final token = body['token'];
    final record = body['record'];
    if (token is! String || token.isEmpty || record is! Map<String, Object?>) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    final model = RecordModel.fromJson(record);
    if (model.id.isEmpty || model.collectionName != fieldUsersCollection) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    _pb.authStore.save(token, model);
    return _userOf(model);
  }

  /// [work], unless [cancel] comes first: then this fails at once with
  /// [ProblemCode.signInCancelled], and [discard] receives [work]'s late
  /// result (its late failure is dropped).
  static Future<T> _unlessCancelled<T>(
    SignInCancellation cancel,
    Future<T> work, {
    void Function(T late)? discard,
  }) {
    const cancelled = ObhijatraException(ProblemCode.signInCancelled);
    final result = Completer<T>();
    unawaited(
      work.then<void>(
        (value) {
          if (result.isCompleted) {
            discard?.call(value);
          } else {
            result.complete(value);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    if (cancel.isCancelled) {
      result.completeError(cancelled);
    } else {
      unawaited(
        cancel.whenCancelled.then((_) {
          if (!result.isCompleted) result.completeError(cancelled);
        }),
      );
    }
    return result.future;
  }

  /// Google's entry in the field users' OAuth2 providers; throws
  /// [ProblemCode.signInMethodOff] when Google sign-in is switched off.
  Future<AuthMethodProvider> _googleProviderInfo() async {
    final response = await _sendRaw(
      http.Request(
        'GET',
        _pb.buildURL('/api/collections/$fieldUsersCollection/auth-methods'),
      ),
    );
    if (response.statusCode != 200) {
      throw _problemForStatus(
        response.statusCode,
        _messageOf(response),
        onBadRequest: ProblemCode.unexpectedResponse,
      );
    }
    final json = _asJsonObject(_decodeJson(response));
    final AuthMethodsList methods;
    try {
      methods = AuthMethodsList.fromJson(json);
    } on Object catch (e) {
      throw ObhijatraException(ProblemCode.unexpectedResponse, cause: e);
    }
    final google = methods.oauth2.enabled
        ? methods.oauth2.providers
              .where((p) => p.name == googleProvider)
              .firstOrNull
        : null;
    if (google == null || google.authURL.isEmpty) {
      throw const ObhijatraException(ProblemCode.signInMethodOff);
    }
    return google;
  }

  /// Opens a realtime connection of its own (never the shared client, so
  /// closing it releases its socket).
  Future<RealtimeChannel> _connectRealtime() async {
    try {
      return await RealtimeChannel.connect(
        _newClient(),
        _pb.buildURL('/api/realtime'),
      );
    } on RealtimeChannelException catch (e) {
      throw _channelProblem(e);
    } on Object catch (e) {
      throw _transportProblem(e) ??
          ObhijatraException(ProblemCode.unknown, cause: e);
    }
  }

  /// Subscribes [channel]'s client to [topic].
  Future<void> _subscribe(RealtimeChannel channel, String topic) async {
    final response = await _postJson('/api/realtime', {
      'clientId': channel.clientId,
      'subscriptions': [topic],
    });
    if (response.statusCode >= 300) {
      throw _problemForStatus(
        response.statusCode,
        _messageOf(response),
        onBadRequest: ProblemCode.unexpectedResponse,
        overrides: const {404: ProblemCode.unexpectedResponse},
      );
    }
  }

  /// Waits for [event], in plain problems.
  static Future<RealtimeEvent> _realtimeEvent(
    Future<RealtimeEvent> event,
  ) async {
    try {
      return await event;
    } on RealtimeChannelException catch (e) {
      throw _channelProblem(e);
    }
  }

  static ObhijatraException _channelProblem(RealtimeChannelException e) {
    final status = e.statusCode;
    if (status != null) {
      return _problemForStatus(
        status,
        null,
        onBadRequest: ProblemCode.unexpectedResponse,
      );
    }
    if (e.closedHere) {
      return ObhijatraException(ProblemCode.signInCancelled, cause: e);
    }
    final cause = e.cause;
    // The server ends a silent connection after 5 minutes; a silent one that
    // died ends after the idle limit. Either way Google's page took too long.
    if (cause == null || cause is TimeoutException) {
      return ObhijatraException(ProblemCode.timeout, cause: e);
    }
    return _transportProblem(cause) ??
        ObhijatraException(ProblemCode.offline, cause: e);
  }

  /// The address of Google's page: the server's OAuth2 address for Google,
  /// sending the answer to the server's redirect page, with the realtime
  /// [clientId] as `state` so the server knows which connection to hand the
  /// code to.
  static Uri _googleAuthUrl(
    AuthMethodProvider provider,
    Uri redirectUrl,
    String clientId,
  ) {
    final Uri url;
    try {
      // PocketBase's address ends with "redirect_uri=", as its SDK expects.
      url = Uri.parse(provider.authURL + redirectUrl.toString());
    } on FormatException catch (e) {
      throw ObhijatraException(ProblemCode.unexpectedResponse, cause: e);
    }
    // Only ever open a secure web page, whatever the server says.
    if (url.scheme != 'https' || url.host.isEmpty) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    return url.replace(
      queryParameters: {...url.queryParameters, 'state': clientId},
    );
  }

  static Future<void> _open(OpenBrowser openBrowser, Uri url) async {
    try {
      await openBrowser(url);
    } on ObhijatraException {
      rethrow;
    } on Object catch (e) {
      throw ObhijatraException(ProblemCode.browserUnavailable, cause: e);
    }
  }

  /// The OAuth2 code in the server's realtime answer [event].
  static String _oauth2CodeOf(RealtimeEvent event, String clientId) {
    final Object? json;
    try {
      json = jsonDecode(event.data);
    } on FormatException catch (e) {
      throw ObhijatraException(ProblemCode.unexpectedResponse, cause: e);
    }
    if (json is! Map<String, Object?> || json['state'] != clientId) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    final error = json['error'];
    if (error is String && error.isNotEmpty) {
      // "access_denied": the person declined on Google's page.
      throw ObhijatraException(
        error == 'access_denied'
            ? ProblemCode.signInCancelled
            : ProblemCode.unexpectedResponse,
        serverMessage: error,
      );
    }
    final code = json['code'];
    if (code is! String || code.isEmpty) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    return code;
  }

  Future<T> _pocketBase<T>(
    Future<T> Function() call, {
    ProblemCode onBadRequest = ProblemCode.unexpectedResponse,
  }) async {
    try {
      return await call();
    } on ClientException catch (e) {
      final original = e.originalError;
      if (original is RedirectNotFollowed) {
        throw ObhijatraException(
          ProblemCode.redirected,
          statusCode: original.statusCode,
          cause: original,
        );
      }
      if (e.statusCode == 0) {
        final timedOut = original is TimeoutException;
        throw ObhijatraException(
          timedOut ? ProblemCode.timeout : ProblemCode.offline,
          cause: original ?? e,
        );
      }
      final message = e.response['message'];
      throw _problemForStatus(
        e.statusCode,
        message is String ? message : null,
        onBadRequest: onBadRequest,
      );
    }
  }

  static ObhijatraException _problemForStatus(
    int status,
    String? message, {
    ProblemCode onBadRequest = ProblemCode.submissionInvalid,
    Map<int, ProblemCode> overrides = const {},
  }) {
    final code =
        overrides[status] ??
        switch (status) {
          400 => onBadRequest,
          401 => ProblemCode.signInRequired,
          403 => ProblemCode.accountNotPermitted,
          404 => ProblemCode.serverIncompatible,
          409 => ProblemCode.duplicateInstance,
          413 => ProblemCode.submissionTooLarge,
          422 => ProblemCode.formNotOnServer,
          429 => ProblemCode.serverBusy,
          >= 500 => ProblemCode.serverError,
          _ => ProblemCode.unexpectedResponse,
        };
    return ObhijatraException(code, statusCode: status, serverMessage: message);
  }

  static Object? _decodeJson(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  /// The time in [response]'s `Date` header, or `null` if it has none or
  /// it cannot be read.
  static DateTime? _dateOf(http.Response response) {
    for (final MapEntry(:key, :value) in response.headers.entries) {
      if (key.toLowerCase() != 'date') continue;
      try {
        return parseHttpDate(value);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static String? _messageOf(http.Response response) {
    final json = _decodeJson(response);
    if (json is Map<String, Object?>) {
      final message = json['message'];
      if (message is String) return message;
    }
    return null;
  }

  static Map<String, Object?> _asJsonObject(Object? json) {
    if (json is Map<String, Object?>) return json;
    throw const ObhijatraException(ProblemCode.unexpectedResponse);
  }

  static SignedInUser _userOf(RecordModel record) => SignedInUser(
    id: record.id,
    email: record.getStringValue('email'),
    name: record.getStringValue('name'),
    locationPath: record.getStringValue('location_path'),
  );

  static RemoteFormVersion _formVersionOf(RecordModel r) {
    final publishedAt = DateTime.tryParse(r.getStringValue('published_at'));
    final formId = r.getStringValue('expand.form.form_id');
    final title = r.getStringValue('expand.form.title');
    final version = r.getStringValue('version');
    final file = r.getStringValue('xform');
    if (formId.isEmpty || version.isEmpty || file.isEmpty) {
      throw const ObhijatraException(ProblemCode.unexpectedResponse);
    }
    return RemoteFormVersion(
      serverId: r.id,
      formServerId: r.getStringValue('form'),
      formId: formId,
      title: title.isEmpty ? null : title,
      version: version,
      xformFileName: file,
      publishedAt: publishedAt,
    );
  }
}
