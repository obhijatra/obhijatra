import 'dart:typed_data';

import 'package:obhijatra_manager/src/data/models.dart';

/// Everything the manager screens ask of the server.
///
/// Every method throws an [AppProblem] on failure, never a raw exception.
/// The real implementation is `PocketBaseApi`; tests use a fake.
abstract interface class ManagerApi {
  /// The person signed in now, or null.
  StaffUser? get currentUser;

  /// The server address this API talks to.
  String get serverUrl;

  /// Signs in a staff user.
  Future<StaffUser> signIn(String email, String password);

  /// Forgets the session. The session is kept in memory only.
  void signOut();

  /// The organisation's name, or an empty string.
  Future<String> organisationName();

  /// Every form you may see, with its versions you may see.
  Future<List<FormSummary>> listForms();

  /// Downloads the XForm text of [version].
  Future<String> downloadXForm(FormVersion version);

  /// Saves an XForm as a new draft version, creating the form if needed.
  Future<FormVersion> uploadDraft({
    required String formId,
    required String title,
    required String version,
    required Uint8List xmlBytes,
  });

  /// Publishes a draft. A published version can never be changed.
  Future<FormVersion> publish(FormVersion version);

  /// One page of submissions, newest first, 50 per page.
  Future<SubmissionPage> listSubmissions(SubmissionQuery query);

  /// How many submissions match [query] in each review state.
  Future<Map<ReviewState, int>> countByState(SubmissionQuery query);

  /// Location names by materialised path.
  Future<Map<String, String>> locationNames();

  /// Downloads the instance XML of a submission.
  Future<String> downloadInstance(String submissionId);

  /// Sets the review state; [comment] is the note for "has issues" and
  /// "rejected".
  Future<SubmissionRow> setReview(
    SubmissionRow row,
    ReviewState state, {
    String? comment,
  });
}
