import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  }) : _client = httpClient ?? http.Client(),
       _pb = PocketBase(
         baseUrl,
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
    final uri = _pb.buildURL(
      '/api/files/form_versions/${version.id}/${version.xformFile}',
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
