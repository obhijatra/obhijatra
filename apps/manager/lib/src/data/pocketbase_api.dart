import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/export.dart';
import 'package:obhijatra_manager/src/data/manager_api.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/phone_number.dart';
import 'package:obhijatra_manager/src/data/places.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/device/device_http.dart';
import 'package:pocketbase/pocketbase.dart';

/// The real [ManagerApi], talking to an Obhijatra server (PocketBase).
///
/// The session lives in memory only (PocketBase's default auth store), so
/// nothing about the person is written to browser storage.
///
/// Every request goes through a [DeviceHttpClient] and is signed by
/// [signer] with this device's keys (docs/decisions/0008-device-trust.md):
/// the SDK's requests, live updates, the raw file downloads and the Google
/// code exchange alike. Redirects are never followed.
class PocketBaseApi implements ManagerApi {
  /// Creates the API for the server at [baseUrl], signing with `signer`.
  /// [httpClient] is for tests.
  PocketBaseApi(
    String baseUrl, {
    http.Client? httpClient,
    this._signer = const UnsignedRequests(),
    this.timeout = const Duration(seconds: 30),
    @visibleForTesting AuthStore? authStore,
  }) : _newInner = httpClient == null ? http.Client.new : (() => httpClient) {
    _pb = PocketBase(
      baseUrl,
      authStore: authStore,
      httpClientFactory: _signedClient,
    );
  }

  late final PocketBase _pb;
  final http.Client Function() _newInner;
  final RequestSigner _signer;

  /// A new client that signs with [signer], by default this device's. The
  /// SDK closes the client it gets after each request.
  http.Client _signedClient([RequestSigner? signer]) =>
      DeviceHttpClient(_newInner(), signer: signer ?? _signer);

  /// How long to wait for the server before giving up.
  final Duration timeout;

  static const String _staff = 'staff_users';

  @override
  String get serverUrl => _pb.baseURL;

  @override
  StaffUser? get currentUser {
    final record = _pb.authStore.record;
    if (record == null || !_pb.authStore.isValid) return null;
    return _staffFrom(record);
  }

  StaffUser _staffFrom(RecordModel record) => StaffUser(
    id: record.id,
    name: record.getStringValue('name'),
    email: record.getStringValue('email'),
    phone: record.getStringValue('phone'),
    role: record.getStringValue('role'),
    // An answer without the field (an older server) counts as active.
    active: record.data['active'] != false,
    mustChangePassword: record.getBoolValue(_mustChange),
  );

  static const String _mustChange = 'must_change_password';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<StaffUser> signIn(String email, String password) async {
    try {
      final auth = await _pb
          .collection(_staff)
          .authWithPassword(email.trim(), password)
          .timeout(timeout);
      return _staffFrom(auth.record);
    } on ClientException catch (e) {
      // A wrong password, a switched-off account or a wrong collection all
      // end here as the same plain sentence.
      if (e.statusCode == 400 || e.statusCode == 401 || e.statusCode == 403) {
        throw AppProblem(ProblemKind.signInFailed, statusCode: e.statusCode);
      }
      throw problemFrom(e);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  void signOut() => _pb.authStore.clear();

  // ------------------------------------------------------------- sign-in

  static const String _signIn = '/api/obhijatra/v1/signin';
  static const String _google = 'google';

  Future<Map<String, dynamic>> _sendJson(
    String path, {
    String method = 'GET',
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final answer = await _pb
        .send<dynamic>(path, method: method, body: body)
        .timeout(timeout);
    if (answer is Map<String, dynamic>) return answer;
    throw const AppProblem(ProblemKind.unknown);
  }

  @override
  Future<SignInMethods> signInMethods() async {
    try {
      return SignInMethods.fromJson(await _sendJson('$_signIn/methods'));
    } on ClientException catch (e) {
      // A server from before these sign-in methods has no such route.
      if (e.statusCode == 404) return SignInMethods.passwordOnly;
      throw problemFrom(e);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<PhoneCodeRequest> requestPhoneCode(String phone) async {
    try {
      final answer = await _sendJson(
        '$_signIn/phone/code',
        method: 'POST',
        body: <String, dynamic>{'collection': _staff, 'phone': phone},
      );
      return PhoneCodeRequest(
        codeId: answer['code_id'] as String? ?? '',
        phone: phone,
        expiresIn: Duration(
          seconds: (answer['expires_in'] as num?)?.toInt() ?? 300,
        ),
        resendAfter: Duration(
          seconds: (answer['resend_after'] as num?)?.toInt() ?? 60,
        ),
      );
    } on ClientException catch (e) {
      throw switch (e.statusCode) {
        400 when fieldProblems(e).containsKey('phone') => const AppProblem(
          ProblemKind.phoneInvalid,
          statusCode: 400,
        ),
        403 => const AppProblem(ProblemKind.smsOff, statusCode: 403),
        429 => const AppProblem(ProblemKind.tooManyCodes, statusCode: 429),
        _ => problemFrom(e),
      };
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<StaffUser> signInWithPhoneCode(String codeId, String code) async {
    try {
      final answer = await _sendJson(
        '$_signIn/phone/verify',
        method: 'POST',
        body: <String, dynamic>{'code_id': codeId, 'code': code},
      );
      final token = answer['token'];
      final record = answer['record'];
      if (token is! String || record is! Map<String, dynamic>) {
        throw const AppProblem(ProblemKind.unknown);
      }
      final model = RecordModel.fromJson(record);
      _pb.authStore.save(token, model);
      return _staffFrom(model);
    } on ClientException catch (e) {
      throw switch (e.statusCode) {
        400 ||
        401 => AppProblem(ProblemKind.codeWrong, statusCode: e.statusCode),
        403 => const AppProblem(ProblemKind.smsOff, statusCode: 403),
        429 => const AppProblem(ProblemKind.tooManyTries, statusCode: 429),
        _ => problemFrom(e),
      };
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<StaffUser?> signInWithGoogle({
    required FutureOr<void> Function(Uri url) openUrl,
    required Future<void> cancelled,
  }) async {
    // PocketBase's own flow (RecordService.authWithOAuth2), written out so
    // that waiting can be cancelled and the live connection closed.
    AuthMethodProvider? offered;
    try {
      final methods = await _pb
          .collection(_staff)
          .listAuthMethods()
          .timeout(timeout);
      if (methods.oauth2.enabled) {
        offered = methods.oauth2.providers
            .where((p) => p.name == _google)
            .firstOrNull;
      }
    } on Object catch (error) {
      throw problemFrom(error);
    }
    if (offered == null) {
      throw const AppProblem(ProblemKind.googleUnavailable);
    }
    final provider = offered;

    final redirect = _pb.buildURL('/api/oauth2-redirect').toString();
    // Only ever open a secure web page, whatever the server says.
    final page = _secureUrl(provider.authURL + redirect);
    if (page == null) throw const AppProblem(ProblemKind.googleFailed);
    final realtime = RealtimeService(_pb);
    final result = Completer<StaffUser?>();
    var stopped = false;

    void finish({StaffUser? user, AppProblem? problem}) {
      if (result.isCompleted) return;
      if (problem != null) {
        result.completeError(problem);
      } else {
        result.complete(user);
      }
    }

    try {
      await realtime
          .subscribe('@oauth2', (message) async {
            try {
              final event = message.jsonData();
              final code = event['code'] as String? ?? '';
              final state = event['state'] as String? ?? '';
              final error = event['error'] as String? ?? '';
              if (error == 'access_denied') {
                finish(); // The person turned Google down.
                return;
              }
              if (state.isEmpty ||
                  state != realtime.clientId ||
                  error.isNotEmpty ||
                  code.isEmpty) {
                finish(problem: const AppProblem(ProblemKind.googleFailed));
                return;
              }
              // The code is exchanged on a separate client with an empty
              // session: no existing session token is sent (so PocketBase
              // cannot link this Google account to whoever is signed in),
              // and nobody watching the real session sees a sign-in that
              // the person has already cancelled.
              final exchange = PocketBase(
                _pb.baseURL,
                lang: _pb.lang,
                authStore: AuthStore(),
                httpClientFactory: _pb.httpClientFactory,
              );
              final auth = await exchange
                  .collection(_staff)
                  .authWithOAuth2Code(
                    provider.name,
                    code,
                    provider.codeVerifier,
                    redirect,
                  )
                  .timeout(timeout);
              if (stopped) {
                finish(); // Cancelled while Google was finishing.
                return;
              }
              _pb.authStore.save(auth.token, auth.record);
              finish(user: _staffFrom(auth.record));
            } on ClientException catch (e) {
              finish(problem: _googleProblem(e));
            } on Object catch (error) {
              finish(problem: problemFrom(error));
            }
          })
          .timeout(timeout);
    } on Object catch (error) {
      unawaited(realtime.unsubscribe());
      throw problemFrom(error);
    }
    // A lost connection means the browser's answer can no longer arrive.
    realtime.onDisconnect = (_) =>
        finish(problem: const AppProblem(ProblemKind.offline));

    final url = page.replace(
      queryParameters: <String, String>{
        ...page.queryParameters,
        'state': realtime.clientId,
      },
    );
    unawaited(
      cancelled.then((_) {
        stopped = true;
        finish();
      }),
    );
    try {
      await openUrl(url);
    } on Object {
      // The screen offers the address as a button as well.
    }
    try {
      return await result.future;
    } finally {
      stopped = true;
      realtime.onDisconnect = null;
      unawaited(realtime.unsubscribe());
    }
  }

  /// [address] if it is an absolute `https` address with a host, else null.
  static Uri? _secureUrl(String address) {
    final url = Uri.tryParse(address);
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return null;
    return url;
  }

  /// Google refusals arrive as 400 with a reason code in
  /// `data.reason.code` (server schema version 5); each becomes its own
  /// plain, translated message. Anything else is "did not finish".
  static AppProblem _googleProblem(ClientException e) {
    if (e.statusCode != 400) return problemFrom(e);
    final data = e.response['data'];
    final reason = data is Map ? data['reason'] : null;
    final code = reason is Map ? reason['code'] : null;
    final kind = switch (code) {
      'google_no_account' => ProblemKind.googleNoAccount,
      'google_email_unconfirmed' => ProblemKind.googleUnconfirmed,
      'google_no_email' => ProblemKind.googleNoEmail,
      'google_email_not_managed' => ProblemKind.googleUnmanaged,
      'account_not_allowed' => ProblemKind.googleNotAllowed,
      _ => ProblemKind.googleFailed,
    };
    return AppProblem(kind, statusCode: 400);
  }

  @override
  Future<SignInSettings> loadSignInSettings() => _guard(
    () async => SignInSettings.fromJson(await _sendJson('$_signIn/settings')),
  );

  @override
  Future<SignInSettings> saveSignInSettings(SignInSettingsUpdate update) async {
    try {
      return SignInSettings.fromJson(
        await _sendJson(
          '$_signIn/settings',
          method: 'PUT',
          body: update.toJson(),
        ),
      );
    } on ClientException catch (e) {
      throw _settingsProblem(e);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<SmsSendResult> sendTestSms(String phone, SmsProviderDraft sms) async {
    try {
      return SmsSendResult.fromJson(
        await _sendJson(
          '$_signIn/test-sms',
          method: 'POST',
          body: <String, dynamic>{'phone': phone, 'sms': sms.toJson()},
        ),
      );
    } on ClientException catch (e) {
      if (e.statusCode == 429) {
        throw const AppProblem(ProblemKind.tooManyTests, statusCode: 429);
      }
      throw _settingsProblem(e);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  static AppProblem _settingsProblem(ClientException e) {
    final fields = e.statusCode == 400
        ? fieldProblems(e)
        : const <String, String>{};
    if (fields.isEmpty) return problemFrom(e);
    return AppProblem(
      ProblemKind.settingsInvalid,
      statusCode: 400,
      fields: fields,
    );
  }

  @override
  Future<String> organisationName() => _guard(() async {
    final page = await _pb.collection('settings').getList(perPage: 1);
    return page.items.isEmpty
        ? ''
        : page.items.first.getStringValue('organisation_name');
  });

  @override
  Future<List<FormSummary>> listForms() => _guard(() async {
    final results = await Future.wait<List<RecordModel>>(
      <Future<List<RecordModel>>>[
        _pb.collection('forms').getFullList(sort: 'title'),
        _pb.collection('form_versions').getFullList(sort: '-created'),
      ],
    );
    final versions = results[1].map(_versionFrom).toList();
    return results[0].map((record) {
      return FormSummary(
        id: record.id,
        formId: record.getStringValue('form_id'),
        title: record.getStringValue('title'),
        versions: versions.where((v) => v.formRecordId == record.id).toList(),
      );
    }).toList();
  });

  FormVersion _versionFrom(RecordModel record) => FormVersion(
    id: record.id,
    formRecordId: record.getStringValue('form'),
    version: record.getStringValue('version'),
    published: record.getBoolValue('published'),
    created:
        _date(record.getStringValue('created')) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    publishedAt: _date(record.getStringValue('published_at')),
    xformFile: record.getStringValue('xform'),
  );

  static DateTime? _date(String text) => text.isEmpty
      ? null
      : DateTime.tryParse(text.replaceFirst(' ', 'T'))?.toLocal();

  @override
  Future<String> downloadXForm(FormVersion version) => _guard(() async {
    final token = await _pb.files.getToken();
    final uri = _pb.buildURL(
      '/api/files/form_versions/${version.id}/${version.xformFile}',
      <String, dynamic>{'token': token},
    );
    return _fetchText(uri);
  });

  /// Downloads a file, signed like every other request: the server refuses
  /// a file token that does not come from an approved device of its person.
  Future<String> _fetchText(Uri uri) async {
    final client = _signedClient();
    try {
      final response = await client.get(
        uri,
        headers: <String, String>{'Authorization': _pb.authStore.token},
      );
      if (response.statusCode != 200) {
        Map<String, dynamic> body;
        try {
          body = jsonDecode(response.body) as Map<String, dynamic>;
        } on Object {
          body = const <String, dynamic>{};
        }
        throw ClientException(
          url: uri,
          statusCode: response.statusCode,
          response: body,
        );
      }
      return utf8.decode(response.bodyBytes);
    } finally {
      client.close();
    }
  }

  @override
  Future<FormVersion> uploadDraft({
    required String formId,
    required String title,
    required String version,
    required Uint8List xmlBytes,
  }) => _guard(() async {
    final existing = await _pb
        .collection('forms')
        .getList(
          perPage: 1,
          filter: _pb.filter('form_id = {:id}', <String, dynamic>{
            'id': formId,
          }),
        );
    final form = existing.items.isNotEmpty
        ? existing.items.first
        : await _pb
              .collection('forms')
              .create(
                body: <String, dynamic>{'form_id': formId, 'title': title},
              );
    final record = await _pb
        .collection('form_versions')
        .create(
          body: <String, dynamic>{
            'form': form.id,
            'version': version,
            'published': false,
          },
          files: <http.MultipartFile>[
            http.MultipartFile.fromBytes(
              'xform',
              xmlBytes,
              filename:
                  '${formId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}.xml',
              contentType: MediaType('text', 'xml'),
            ),
          ],
        );
    return _versionFrom(record);
  });

  @override
  Future<FormVersion> publish(FormVersion version) => _guard(() async {
    final record = await _pb
        .collection('form_versions')
        .update(version.id, body: <String, dynamic>{'published': true});
    return _versionFrom(record);
  });

  String? _filter(SubmissionQuery q, {bool withState = true}) {
    final parts = <String>[];
    final params = <String, dynamic>{};
    if (q.formRecordId != null) {
      parts.add('form = {:form}');
      params['form'] = q.formRecordId;
    }
    if (q.from != null) {
      parts.add('received_at >= {:from}');
      params['from'] = q.from!.toUtc();
    }
    if (q.to != null) {
      parts.add('received_at < {:to}');
      params['to'] = q.to!.toUtc();
    }
    if (withState && q.state != null) {
      parts.add('review_state = {:state}');
      params['state'] = q.state!.wire;
    }
    return parts.isEmpty ? null : _pb.filter(parts.join(' && '), params);
  }

  @override
  Future<SubmissionPage> listSubmissions(SubmissionQuery query) =>
      _guard(() async {
        final result = await _pb
            .collection('submissions')
            .getList(
              page: query.page,
              perPage: SubmissionQuery.perPage,
              sort: '-received_at',
              expand: 'form,submitted_by',
              filter: _filter(query),
            );
        return SubmissionPage(
          items: result.items.map(_rowFrom).toList(),
          page: result.page,
          perPage: result.perPage,
          totalItems: result.totalItems,
          totalPages: result.totalPages,
        );
      });

  SubmissionRow _rowFrom(RecordModel record) => SubmissionRow(
    id: record.id,
    instanceId: record.getStringValue('instance_id'),
    formRecordId: record.getStringValue('form'),
    formVersionId: record.getStringValue('form_version'),
    formTitle: _firstNonEmpty(
      record.get<String>('expand.form.title', ''),
      record.get<String>('expand.form.form_id', ''),
    ),
    collector: _firstNonEmpty(
      record.get<String>('expand.submitted_by.name', ''),
      record.get<String>('expand.submitted_by.email', ''),
    ),
    locationPath: record.getStringValue('location_path'),
    receivedAt:
        _date(record.getStringValue('received_at')) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    state: ReviewState.fromWire(record.getStringValue('review_state')),
    comment: record.getStringValue('review_comment'),
    commentSupported: record.data.containsKey('review_comment'),
  );

  static String _firstNonEmpty(String a, String b) =>
      a.trim().isNotEmpty ? a.trim() : b.trim();

  @override
  Future<Map<ReviewState, int>> countByState(SubmissionQuery query) =>
      _guard(() async {
        final counts = await Future.wait<int>(
          ReviewState.values.map((state) async {
            final result = await _pb
                .collection('submissions')
                .getList(
                  perPage: 1,
                  filter: _filter(query.copyWith(state: state)),
                );
            return result.totalItems;
          }),
        );
        return <ReviewState, int>{
          for (var i = 0; i < ReviewState.values.length; i++)
            ReviewState.values[i]: counts[i],
        };
      });

  @override
  Future<Map<String, String>> locationNames() => _guard(() async {
    final records = await _pb.collection('locations').getFullList();
    return <String, String>{
      for (final record in records)
        record.getStringValue('path'): record.getStringValue('name'),
    };
  });

  @override
  Future<String> downloadInstance(String submissionId) => _guard(() async {
    final record = await _pb.collection('submissions').getOne(submissionId);
    final file = record.getStringValue('xml');
    final token = await _pb.files.getToken();
    final uri = _pb.buildURL(
      '/api/files/submissions/$submissionId/$file',
      <String, dynamic>{'token': token},
    );
    return _fetchText(uri);
  });

  @override
  Future<SubmissionRow> setReview(
    SubmissionRow row,
    ReviewState state, {
    String? comment,
  }) => _guard(() async {
    final body = <String, dynamic>{'review_state': state.wire};
    // Send the note only to a server that has a place for it; a server
    // without the field would drop it without a word.
    if (row.commentSupported || (comment != null && comment.isNotEmpty)) {
      body['review_comment'] = comment ?? '';
    }
    final record = await _pb
        .collection('submissions')
        .update(row.id, body: body, expand: 'form,submitted_by');
    final saved = _rowFrom(record);
    if (comment != null && comment.isNotEmpty && !saved.commentSupported) {
      throw const AppProblem(ProblemKind.commentNotSaved);
    }
    return saved;
  });

  // ------------------------------------------------------------- people

  static const String _locks = 'login_locks';

  /// The sign-in locks in force now. `@now` is the server's clock, so a
  /// wrong clock on this computer changes nothing.
  static const String _lockInForce =
      'account_collection = {:kind} && unlocked = false && '
      'locked_until > @now';

  /// The most accounts one "locked" filter or lock lookup asks about.
  static const int _maxIds = 200;

  Person _personFrom(PersonKind kind, RecordModel record) => Person(
    id: record.id,
    kind: kind,
    name: record.getStringValue('name'),
    email: record.getStringValue('email'),
    verified: record.getBoolValue('verified'),
    phone: record.getStringValue('phone'),
    role: record.getStringValue('role'),
    locationId: record.getStringValue('location'),
    locationPath: record.getStringValue('location_path'),
    active: record.getBoolValue('active'),
    mustChangePassword: record.getBoolValue(_mustChange),
    created: _date(record.getStringValue('created')),
  );

  /// `(field = {:p0} || field = {:p1} ...)` for [ids], with its values.
  (String, Map<String, dynamic>) _anyOf(String field, List<String> ids) {
    final params = <String, dynamic>{};
    final parts = <String>[];
    for (var i = 0; i < ids.length; i++) {
      parts.add('$field = {:id$i}');
      params['id$i'] = ids[i];
    }
    return ('(${parts.join(' || ')})', params);
  }

  @override
  Future<PeoplePage> listPeople(PeopleQuery query) => _guard(() async {
    final parts = <String>[];
    final params = <String, dynamic>{};
    final search = query.search.trim();
    if (search.isNotEmpty) {
      // Mobile numbers are kept as +8801712345678, so the digits typed
      // ("01712 345678") are looked for as well as the text itself.
      final digits = latinDigits(search).replaceAll(RegExp('[^0-9]'), '');
      parts.add(
        digits.length >= 3
            ? '(name ~ {:q} || email ~ {:q} || phone ~ {:digits})'
            : '(name ~ {:q} || email ~ {:q} || phone ~ {:q})',
      );
      params['q'] = search;
      if (digits.length >= 3) params['digits'] = digits;
    }
    switch (query.status) {
      case null:
        break;
      case PeopleStatus.active:
        parts.add('active = true');
      case PeopleStatus.deactivated:
        parts.add('active = false');
      case PeopleStatus.locked:
        final locks = await _pb
            .collection(_locks)
            .getFullList(
              filter: _pb.filter(_lockInForce, <String, dynamic>{
                'kind': query.kind.collection,
              }),
            );
        final ids = <String>{
          for (final lock in locks) lock.getStringValue('account_id'),
        }.where((id) => id.isNotEmpty).take(_maxIds).toList();
        if (ids.isEmpty) return PeoplePage.empty(page: query.page);
        final (expression, values) = _anyOf('id', ids);
        parts.add(expression);
        params.addAll(values);
    }
    final place = query.placePath;
    if (place != null && place.isNotEmpty) {
      // A path occurs inside another only as its start (see the server's
      // LocationPathPattern), so "contains" finds the place and every
      // place below it.
      parts.add('location_path ~ {:place}');
      params['place'] = place;
    }
    final result = await _pb
        .collection(query.kind.collection)
        .getList(
          page: query.page,
          perPage: PeopleQuery.perPage,
          sort: switch (query.sort) {
            PeopleSort.newest => '-created',
            PeopleSort.name => 'name,-created',
          },
          filter: parts.isEmpty ? null : _pb.filter(parts.join(' && '), params),
        );
    return PeoplePage(
      items: result.items.map((r) => _personFrom(query.kind, r)).toList(),
      page: result.page,
      perPage: result.perPage,
      totalItems: result.totalItems,
      totalPages: result.totalPages,
    );
  });

  @override
  Future<Person> getPerson(PersonKind kind, String id) => _guard(() async {
    final record = await _pb.collection(kind.collection).getOne(id);
    return _personFrom(kind, record);
  });

  /// Runs a change to a person; refused fields become
  /// [ProblemKind.detailsInvalid] with the server's codes and messages.
  Future<T> _personChange<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on ClientException catch (e) {
      throw _detailsProblem(e);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  static AppProblem _detailsProblem(ClientException e) {
    // Another admin changed the person between loading and saving.
    if (e.statusCode == 409) {
      return const AppProblem(ProblemKind.personChanged, statusCode: 409);
    }
    final fields = e.statusCode == 400
        ? fieldProblems(e)
        : const <String, String>{};
    if (fields.isEmpty) return problemFrom(e);
    return AppProblem(
      ProblemKind.detailsInvalid,
      statusCode: 400,
      fields: fields,
      codes: fieldCodes(e),
    );
  }

  @override
  Future<Person> createPerson(
    PersonKind kind,
    PersonDraft draft, {
    required String password,
    required bool oneTimePassword,
  }) => _personChange(() async {
    final record = await _pb
        .collection(kind.collection)
        .create(
          body: <String, dynamic>{
            ...draft.toJson(),
            'active': true,
            'password': password,
            'passwordConfirm': password,
            _mustChange: oneTimePassword,
          },
        );
    return _personFrom(kind, record);
  });

  @override
  Future<Person> updatePerson(Person person, PersonDraft draft) =>
      _personChange(() async {
        final changes = draft.changesFrom(person);
        if (changes.isEmpty) return person;
        final record = await _pb
            .collection(person.kind.collection)
            .update(person.id, body: changes);
        return _personFrom(person.kind, record);
      });

  @override
  Future<Person> setPersonActive(Person person, {required bool active}) =>
      _personChange(() async {
        final record = await _pb
            .collection(person.kind.collection)
            .update(person.id, body: <String, dynamic>{'active': active});
        return _personFrom(person.kind, record);
      });

  @override
  Future<Person> resetOneTimePassword(Person person, String password) =>
      _personChange(() async {
        final record = await _pb
            .collection(person.kind.collection)
            .update(
              person.id,
              body: <String, dynamic>{
                'password': password,
                'passwordConfirm': password,
                _mustChange: true,
              },
            );
        return _personFrom(person.kind, record);
      });

  @override
  Future<List<SignInLock>> activeLocks(
    PersonKind kind,
    Iterable<String> accountIds,
  ) => _guard(() async {
    final ids = accountIds.toSet().take(_maxIds).toList();
    if (ids.isEmpty) return const <SignInLock>[];
    final (expression, values) = _anyOf('account_id', ids);
    final records = await _pb
        .collection(_locks)
        .getFullList(
          filter: _pb.filter('$_lockInForce && $expression', <String, dynamic>{
            'kind': kind.collection,
            ...values,
          }),
        );
    return <SignInLock>[
      for (final record in records)
        SignInLock(
          id: record.id,
          kind: kind,
          accountId: record.getStringValue('account_id'),
          ip: record.getStringValue('ip'),
          failedAttempts: record.getIntValue('failed_attempts'),
          lockedUntil:
              _date(record.getStringValue('locked_until')) ?? DateTime.now(),
        ),
    ];
  });

  @override
  Future<void> unlockSignIn(SignInLock lock) => _guard(() async {
    await _pb
        .collection(_locks)
        .update(lock.id, body: <String, dynamic>{'unlocked': true});
  });

  // ------------------------------------------------------------- places

  static const String _locations = 'locations';

  /// The fields a place needs, so thousands of places stay a small answer.
  static const String _placeFields = 'id,name,code,parent,path,closed';

  static Place _placeFrom(RecordModel record) => Place(
    id: record.id,
    name: record.getStringValue('name'),
    code: record.getStringValue('code'),
    parentId: record.getStringValue('parent'),
    path: record.getStringValue('path'),
    closed: record.getBoolValue('closed'),
  );

  @override
  Future<List<Place>> listPlaces() => _guard(() async {
    // getFullList asks for one page after another until none is left.
    final records = await _pb
        .collection(_locations)
        .getFullList(batch: 500, fields: _placeFields);
    return records.map(_placeFrom).toList();
  });

  /// Runs a change to a place; refused fields become
  /// [ProblemKind.detailsInvalid] with the server's codes and messages.
  Future<T> _placeChange<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on ClientException catch (e) {
      throw _fieldsProblem(e);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  static AppProblem _fieldsProblem(ClientException e) {
    final fields = e.statusCode == 400
        ? fieldProblems(e)
        : const <String, String>{};
    if (fields.isEmpty) return problemFrom(e);
    return AppProblem(
      ProblemKind.detailsInvalid,
      statusCode: 400,
      fields: fields,
      codes: fieldCodes(e),
    );
  }

  @override
  Future<Place> createPlace({
    required String parentId,
    required String name,
    required String code,
  }) => _placeChange(() async {
    final record = await _pb
        .collection(_locations)
        .create(
          // Never an id: the server makes it, and refuses one sent.
          body: <String, dynamic>{
            'name': cleanPlaceName(name),
            'code': code.trim(),
            'parent': parentId,
          },
          fields: _placeFields,
        );
    return _placeFrom(record);
  });

  @override
  Future<Place> updatePlace(
    Place place, {
    required String name,
    required String code,
  }) => _placeChange(() async {
    final body = <String, dynamic>{
      if (cleanPlaceName(name) != place.name) 'name': cleanPlaceName(name),
      if (code.trim() != place.code) 'code': code.trim(),
    };
    if (body.isEmpty) return place;
    final record = await _pb
        .collection(_locations)
        .update(place.id, body: body, fields: _placeFields);
    return _placeFrom(record);
  });

  @override
  Future<Place> setPlaceClosed(Place place, {required bool closed}) =>
      _placeChange(() async {
        final record = await _pb
            .collection(_locations)
            .update(
              place.id,
              body: <String, dynamic>{'closed': closed},
              fields: _placeFields,
            );
        return _placeFrom(record);
      });

  @override
  Future<void> deletePlace(Place place) =>
      _placeChange(() => _pb.collection(_locations).delete(place.id));

  static const String _importPath = '/api/obhijatra/v1/places/import';

  @override
  Future<PlaceImportResult> importPlaces({
    required String parentId,
    required List<PlaceImportRow> rows,
    required bool dryRun,
  }) async {
    try {
      final answer = await _pb
          .send<dynamic>(
            _importPath,
            method: 'POST',
            body: <String, dynamic>{
              'parent': parentId,
              'rows': <Map<String, dynamic>>[
                for (final row in rows) row.toJson(),
              ],
              'dry_run': dryRun,
            },
          )
          // Thousands of places are saved in one go, so this may take a
          // while.
          .timeout(timeout * 10);
      if (answer is! Map<String, dynamic>) {
        throw const AppProblem(ProblemKind.unknown);
      }
      return PlaceImportResult.fromJson(answer);
    } on ClientException catch (e) {
      // A real import with problems saves nothing and answers 400 with
      // the same body as a check.
      if (e.statusCode == 400 && e.response['problems'] is List) {
        return PlaceImportResult.fromJson(e.response);
      }
      throw _fieldsProblem(e);
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<int> countActiveOrgAdmins() => _guard(() async {
    final result = await _pb
        .collection(_staff)
        .getList(
          perPage: 1,
          filter: _pb.filter(
            'role = {:role} && active = true',
            <String, dynamic>{'role': orgAdminRole},
          ),
        );
    return result.totalItems;
  });

  // ------------------------------------------------------------- export

  /// How long a download may wait for its first byte: the server builds
  /// the CSV tables before it sends anything.
  static const Duration _exportStart = Duration(minutes: 10);

  /// How long a download may wait for its next part once it is flowing.
  static const Duration _exportStall = Duration(minutes: 2);

  @override
  Future<String?> downloadSubmissions(
    SubmissionExport export, {
    required Future<void> Function(List<int> chunk) onChunk,
    Future<void>? stop,
  }) async {
    // Not through the SDK, which reads every answer as text: the bytes go
    // to [onChunk] as they arrive. Signed like every other request.
    final client = DeviceHttpClient(
      _newInner(),
      signer: _signer,
      timeout: _exportStart,
    );
    // Closing the client ends the request at once, wherever it is.
    var stopped = false;
    unawaited(
      stop?.then((_) {
        stopped = true;
        client.close();
      }),
    );
    try {
      final request = http.Request('POST', _pb.buildURL(exportSubmissionsPath))
        ..headers['Authorization'] = _pb.authStore.token
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(export.toJson());
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw _exportProblem(
          response.statusCode,
          await response.stream.toBytes(),
        );
      }
      await for (final chunk in response.stream.timeout(_exportStall)) {
        if (stopped) throw const DownloadStopped();
        await onChunk(chunk);
      }
      if (stopped) throw const DownloadStopped();
      return exportFileName(response.headers['content-disposition']);
    } on AppProblem {
      rethrow;
    } on Object catch (error) {
      if (stopped || error is DownloadStopped) throw const DownloadStopped();
      // The connection failed or broke off part way.
      if (error is http.ClientException) {
        throw const AppProblem(ProblemKind.offline);
      }
      throw problemFrom(error);
    } finally {
      // Also ends a download stopped part way.
      client.close();
    }
  }

  /// The problem in a refused download's JSON answer.
  static AppProblem _exportProblem(int status, List<int> body) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    } on Object {
      json = const <String, dynamic>{};
    }
    final error = ClientException(statusCode: status, response: json);
    if (status == 400) {
      final codes = fieldCodes(error);
      return AppProblem(switch (codes['form']) {
        'validation_form_not_found' => ProblemKind.formUnavailable,
        'validation_form_has_no_version' => ProblemKind.exportNoVersion,
        _ => ProblemKind.detailsInvalid,
      }, statusCode: 400);
    }
    return problemFrom(error);
  }

  // ------------------------------------------------------------ devices

  static const String _devices = '/api/obhijatra/v1/devices';

  /// The device fields a list needs, and the names of the people they
  /// belong to (never their whole records).
  static const String _deviceFields =
      'id,field_user,staff_user,label,platform,status,expires,approved_at,'
      'first_approved_by,sign_public_key,enc_public_key,created,'
      'expand.field_user.name,expand.field_user.email,expand.field_user.phone,'
      'expand.staff_user.name,expand.staff_user.email,expand.staff_user.phone,'
      'expand.staff_user.role';

  @override
  Future<DeviceView> enrolDevice({
    required String userId,
    required DeviceKeys keys,
    required String label,
    required String platform,
  }) async {
    // The keys are someone else's when another person signed in meanwhile.
    if (_pb.authStore.record?.id != userId) {
      throw const AppProblem(ProblemKind.signInRequired);
    }
    // Signed with the keys it enrols ("enrol" as the device), whatever the
    // device signer holds: this proves the device has the private key.
    final enrol = PocketBase(
      _pb.baseURL,
      lang: _pb.lang,
      authStore: _pb.authStore,
      httpClientFactory: () => _signedClient(DeviceRequestSigner(keys)),
    );
    try {
      final answer = await enrol
          .send<dynamic>(
            deviceEnrolPath,
            method: 'POST',
            body: <String, dynamic>{
              'label': label,
              'platform': platform,
              'sign_public_key': base64.encode(keys.signPublicKey),
              'enc_public_key': base64.encode(keys.encPublicKey),
            },
          )
          .timeout(timeout);
      if (answer is! Map<String, dynamic>) {
        throw const AppProblem(ProblemKind.unknown);
      }
      return DeviceView.fromJson(answer);
    } on ClientException catch (e) {
      throw switch (e.statusCode) {
        409 => const AppProblem(ProblemKind.deviceKeyInUse, statusCode: 409),
        429 => const AppProblem(
          ProblemKind.tooManyWaitingDevices,
          statusCode: 429,
        ),
        _ => problemFrom(e),
      };
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<DeviceView> myDevice() =>
      _guard(() async => DeviceView.fromJson(await _sendJson(deviceMePath)));

  DeviceRecord _deviceFrom(RecordModel record) {
    final fieldUser = record.getStringValue('field_user');
    final kind = fieldUser.isNotEmpty ? PersonKind.field : PersonKind.staff;
    final relation = kind == PersonKind.field ? 'field_user' : 'staff_user';
    String owner(String field) =>
        record.get<String>('expand.$relation.$field', '');
    final contact = _firstNonEmpty(owner('email'), owner('phone'));
    final name = owner('name').trim();
    return DeviceRecord(
      id: record.id,
      ownerKind: kind,
      ownerId: kind == PersonKind.field
          ? fieldUser
          : record.getStringValue('staff_user'),
      ownerName: _firstNonEmpty(name, contact),
      ownerContact: name.isEmpty ? '' : contact,
      ownerRole: kind == PersonKind.field ? fieldOfficerRole : owner('role'),
      label: record.getStringValue('label'),
      platform: record.getStringValue('platform'),
      status: DeviceStatus.fromWire(record.getStringValue('status')),
      signPublicKey: record.getStringValue('sign_public_key'),
      encPublicKey: record.getStringValue('enc_public_key'),
      expires: _date(record.getStringValue('expires')),
      approvedAt: _date(record.getStringValue('approved_at')),
      created: _date(record.getStringValue('created')),
      firstApprovedBy: record.getStringValue('first_approved_by'),
    );
  }

  @override
  Future<List<DeviceRecord>> listDevices() => _guard(() async {
    final records = await _pb
        .collection('devices')
        .getFullList(
          batch: 200,
          sort: '-created',
          expand: 'field_user,staff_user',
          fields: _deviceFields,
        );
    return records.map(_deviceFrom).toList();
  });

  @override
  Future<DeviceView> approveDevice(String deviceId, String code) async {
    try {
      return DeviceView.fromJson(
        await _sendJson(
          '$_devices/${Uri.encodeComponent(deviceId)}/approve',
          method: 'POST',
          body: <String, dynamic>{'code': code},
        ),
      );
    } on ClientException catch (e) {
      throw switch (e.statusCode) {
        400 when fieldCodes(e)['code'] == 'validation_device_code_mismatch' =>
          const AppProblem(ProblemKind.deviceCodeMismatch, statusCode: 400),
        409 => const AppProblem(ProblemKind.deviceNotWaiting, statusCode: 409),
        _ => problemFrom(e),
      };
    } on Object catch (error) {
      throw problemFrom(error);
    }
  }

  @override
  Future<DeviceView> revokeDevice(String deviceId) => _guard(
    () async => DeviceView.fromJson(
      await _sendJson(
        '$_devices/${Uri.encodeComponent(deviceId)}/revoke',
        method: 'POST',
      ),
    ),
  );

  @override
  Future<StaffUser> chooseNewPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final record = _pb.authStore.record;
    if (record == null || !_pb.authStore.isValid) {
      throw const AppProblem(ProblemKind.signInRequired);
    }
    final email = record.getStringValue('email');
    await _personChange(
      () => _pb
          .collection(_staff)
          .update(
            record.id,
            body: <String, dynamic>{
              'oldPassword': currentPassword,
              'password': newPassword,
              'passwordConfirm': newPassword,
            },
          ),
    );
    // Choosing a password ends every session the person has, this one too,
    // so the app signs in again with the new password.
    try {
      final auth = await _pb
          .collection(_staff)
          .authWithPassword(email, newPassword)
          .timeout(timeout);
      return _staffFrom(auth.record);
    } on Object {
      _pb.authStore.clear();
      throw const AppProblem(ProblemKind.passwordSavedSignIn);
    }
  }
}
