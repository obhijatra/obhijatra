import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/server/request_signer.dart';
import 'package:obhijatra_core/src/server/server_models.dart';
import 'package:pocketbase/pocketbase.dart';

/// Reads the files sent with submissions, implemented by the app (for
/// example with `dart:io`), so the core stays free of platform libraries.
abstract interface class AttachmentStore {
  /// Returns the bytes of the file at [path]; throws an
  /// [ObhijatraException] with [ProblemCode.attachmentMissing] if it is gone.
  Future<Uint8List> read(String path);
}

/// The multipart part that carries the instance XML (the OpenRosa name).
const String xmlPartName = 'xml_submission_file';

/// Talks to one `obhijatra-server`: the version handshake, field-user
/// sign-in, published forms and submission upload.
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

  /// The route prefix of Obhijatra's own API.
  static const String apiPrefix = '/api/obhijatra/v1';

  /// The auth collection of field users.
  static const String fieldUsersCollection = 'field_users';

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
  Future<ServerMeta> fetchMeta() async {
    final body = await _pocketBase(() => _pb.send<Object?>('$apiPrefix/meta'));
    return ServerMeta.fromJson(_asJsonObject(body));
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

  /// Releases the network connections.
  void close() {
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
    } on TimeoutException catch (e) {
      throw ObhijatraException(ProblemCode.timeout, cause: e);
    } on http.ClientException catch (e) {
      throw ObhijatraException(ProblemCode.offline, cause: e);
    }
  }

  Future<T> _pocketBase<T>(
    Future<T> Function() call, {
    ProblemCode onBadRequest = ProblemCode.unexpectedResponse,
  }) async {
    try {
      return await call();
    } on ClientException catch (e) {
      if (e.statusCode == 0) {
        final timedOut = e.originalError is TimeoutException;
        throw ObhijatraException(
          timedOut ? ProblemCode.timeout : ProblemCode.offline,
          cause: e.originalError ?? e,
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
  }) {
    final code = switch (status) {
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
