import 'dart:async';
import 'dart:typed_data';

import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';

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

  /// The ways to sign in this server offers. An older server that does not
  /// say offers email and password only.
  Future<SignInMethods> signInMethods();

  /// Asks the server to send a sign-in code by SMS to [phone] (international
  /// form). The answer is the same whether or not the number has an
  /// account that may use SMS codes.
  Future<PhoneCodeRequest> requestPhoneCode(String phone);

  /// Signs in with the code from the SMS.
  Future<StaffUser> signInWithPhoneCode(String codeId, String code);

  /// Signs in with Google in the person's web browser.
  ///
  /// [openUrl] is called once with the address of Google's sign-in page;
  /// the screen opens it (and offers it as a button, in case the browser
  /// blocked it). The future completes when the browser comes back, or
  /// with null as soon as [cancelled] completes or the person turns Google
  /// down.
  Future<StaffUser?> signInWithGoogle({
    required FutureOr<void> Function(Uri url) openUrl,
    required Future<void> cancelled,
  });

  /// The sign-in settings (organisation admins only).
  Future<SignInSettings> loadSignInSettings();

  /// Saves the sign-in settings and returns them as the server now has
  /// them. Refused fields come back as [ProblemKind.settingsInvalid].
  Future<SignInSettings> saveSignInSettings(SignInSettingsUpdate update);

  /// Sends a test SMS to [phone] with [sms], saved or not.
  Future<SmsSendResult> sendTestSms(String phone, SmsProviderDraft sms);

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
