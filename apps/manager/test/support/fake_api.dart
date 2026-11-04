import 'dart:async';
import 'dart:typed_data';

import 'package:obhijatra_manager/src/data/manager_api.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';

/// A server stand-in for widget tests.
class FakeManagerApi implements ManagerApi {
  FakeManagerApi({
    this.user,
    this.forms = const <FormSummary>[],
    this.organisation = 'Sample Development Society',
  });

  StaffUser? user;
  List<FormSummary> forms;
  String organisation;

  /// XForm text by version record id.
  final Map<String, String> xforms = <String, String>{};

  /// Instance XML by submission id.
  final Map<String, String> instances = <String, String>{};

  /// Rows for the submissions table, newest first. When [totalOverride] is
  /// set, [rowFor] makes the rows up on demand.
  List<SubmissionRow> submissions = <SubmissionRow>[];
  int? totalOverride;
  SubmissionRow Function(int index)? rowFor;
  Map<String, String> locations = <String, String>{};

  /// While not null, every call waits for it (shows the loading state).
  Completer<void>? gate;

  /// While not null, every data call throws it.
  AppProblem? failWith;

  /// Set to make [downloadXForm] fail on its own.
  AppProblem? xformFailure;

  /// Set to make [setReview] fail.
  AppProblem? reviewFailure;

  final List<SubmissionQuery> queries = <SubmissionQuery>[];
  final List<(SubmissionRow, ReviewState, String?)> reviews =
      <(SubmissionRow, ReviewState, String?)>[];
  final List<({String formId, String version, String title})> uploads =
      <({String formId, String version, String title})>[];
  final List<FormVersion> published = <FormVersion>[];
  int signOuts = 0;
  AppProblem? signInFailure;

  Future<void> _enter() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  StaffUser? get currentUser => user;

  @override
  String get serverUrl => 'https://data.example.org';

  @override
  Future<StaffUser> signIn(String email, String password) async {
    final f = signInFailure;
    if (f != null) throw f;
    return user = StaffUser(
      id: 'u1',
      name: 'Tania Rahman',
      email: email,
      role: 'org_admin',
    );
  }

  @override
  void signOut() {
    signOuts++;
    user = null;
  }

  @override
  Future<String> organisationName() async {
    await _enter();
    return organisation;
  }

  @override
  Future<List<FormSummary>> listForms() async {
    await _enter();
    return forms;
  }

  @override
  Future<String> downloadXForm(FormVersion version) async {
    await _enter();
    final failure = xformFailure;
    if (failure != null) throw failure;
    final xml = xforms[version.id];
    if (xml == null) throw const AppProblem(ProblemKind.notFound);
    return xml;
  }

  @override
  Future<FormVersion> uploadDraft({
    required String formId,
    required String title,
    required String version,
    required Uint8List xmlBytes,
  }) async {
    await _enter();
    uploads.add((formId: formId, version: version, title: title));
    return FormVersion(
      id: 'new-version',
      formRecordId: 'new-form',
      version: version,
      published: false,
      created: DateTime.now(),
      xformFile: 'x.xml',
    );
  }

  @override
  Future<FormVersion> publish(FormVersion version) async {
    await _enter();
    published.add(version);
    return version;
  }

  @override
  Future<SubmissionPage> listSubmissions(SubmissionQuery query) async {
    await _enter();
    queries.add(query);
    final total = totalOverride ?? submissions.length;
    final first = (query.page - 1) * SubmissionQuery.perPage;
    final count = (total - first).clamp(0, SubmissionQuery.perPage);
    final items = <SubmissionRow>[
      for (var i = 0; i < count; i++)
        rowFor != null ? rowFor!(first + i) : submissions[first + i],
    ];
    return SubmissionPage(
      items: items,
      page: query.page,
      perPage: SubmissionQuery.perPage,
      totalItems: total,
      totalPages: (total / SubmissionQuery.perPage).ceil(),
    );
  }

  @override
  Future<Map<ReviewState, int>> countByState(SubmissionQuery query) async {
    await _enter();
    final total = totalOverride ?? submissions.length;
    return <ReviewState, int>{
      ReviewState.received: total - 3,
      ReviewState.edited: 0,
      ReviewState.hasIssues: 2,
      ReviewState.approved: 1,
      ReviewState.rejected: 0,
    };
  }

  @override
  Future<Map<String, String>> locationNames() async {
    await _enter();
    return locations;
  }

  @override
  Future<String> downloadInstance(String submissionId) async {
    await _enter();
    final xml = instances[submissionId];
    if (xml == null) throw const AppProblem(ProblemKind.notFound);
    return xml;
  }

  @override
  Future<SubmissionRow> setReview(
    SubmissionRow row,
    ReviewState state, {
    String? comment,
  }) async {
    await _enter();
    final failure = reviewFailure;
    if (failure != null) throw failure;
    reviews.add((row, state, comment));
    final updated = row.withReview(state, comment ?? '');
    submissions = <SubmissionRow>[
      for (final r in submissions) r.id == row.id ? updated : r,
    ];
    return updated;
  }
}
