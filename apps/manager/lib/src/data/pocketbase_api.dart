import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:obhijatra_manager/src/data/manager_api.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:pocketbase/pocketbase.dart';

/// The real [ManagerApi], talking to an Obhijatra server (PocketBase).
///
/// The session lives in memory only (PocketBase's default auth store), so
/// nothing about the person is written to browser storage.
class PocketBaseApi implements ManagerApi {
  /// Creates the API for the server at [baseUrl]. [httpClient] is for tests.
  PocketBaseApi(
    String baseUrl, {
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
    @visibleForTesting AuthStore? authStore,
  }) : _client = httpClient ?? http.Client(),
       _pb = PocketBase(
         baseUrl,
         authStore: authStore,
         httpClientFactory: httpClient == null ? null : () => httpClient,
       );

  final PocketBase _pb;
  final http.Client _client;

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
  );

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

  Future<String> _fetchText(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: <String, String>{'Authorization': _pb.authStore.token},
    );
    if (response.statusCode != 200) {
      throw ClientException(url: uri, statusCode: response.statusCode);
    }
    return utf8.decode(response.bodyBytes);
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
}
