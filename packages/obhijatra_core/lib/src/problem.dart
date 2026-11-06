/// Plain-language problem codes shared by every part of the core.
///
/// The UI translates a [ProblemCode] into Bangla or English; raw exceptions
/// never reach the screen or the database. Codes are stored by [name], so
/// renaming a value is a data migration: add new values, never rename.
library;

/// What went wrong, in terms a field officer can act on.
enum ProblemCode {
  /// The phone has no connection, or the server cannot be reached.
  offline,

  /// The server took too long to answer.
  timeout,

  /// The server had an internal error (HTTP 5xx).
  serverError,

  /// The server asked the app to slow down (HTTP 429).
  serverBusy,

  /// The user must sign in again (no session, or the session expired).
  signInRequired,

  /// The email or password is wrong, or the account is not active.
  signInFailed,

  /// The account may not do this (HTTP 403), for example a deactivated user.
  accountNotPermitted,

  /// Unsent submissions on this device were made by another user, who must
  /// sign in to send them.
  differentUser,

  /// This app is older than the server accepts; it must be updated to sync.
  appUpdateRequired,

  /// The server speaks a different API version than this app.
  serverIncompatible,

  /// The server has not been set up with `obhijatra-server init` yet.
  serverNotSetUp,

  /// The phone's clock differs from the server's by more than
  /// `maxClockSkew` (10 minutes), seen from the server's `Date` header when
  /// syncing starts. Nothing is sent until the person sets the phone's date
  /// and time; finished forms stay queued and new ones can still be queued.
  clockSkew,

  /// The server already holds a different submission with this instance ID.
  duplicateInstance,

  /// The server does not have, or has not published, this form version.
  formNotOnServer,

  /// The server could not accept the submission as sent (HTTP 400).
  submissionInvalid,

  /// The submission or one of its files is larger than the server allows.
  submissionTooLarge,

  /// A photo or other file of the submission is missing on this phone.
  attachmentMissing,

  /// The downloaded form could not be read or does not match its record.
  formInvalid,

  /// The device database key is missing although the database exists.
  databaseKeyMissing,

  /// The device database could not be opened with the stored key.
  databaseKeyRejected,

  /// The device database was written by a newer version of the app.
  databaseFromNewerApp,

  /// The device database could not be opened for another reason.
  databaseUnavailable,

  /// The server answered in a way this app does not understand.
  unexpectedResponse,

  /// The server address answered by sending the app to another address
  /// (an HTTP redirect), which the app never follows: a public Wi-Fi sign-in
  /// page, or a server that has moved. Nothing was sent; it is tried again
  /// later.
  redirected,

  /// The mobile number is not one the server can send a sign-in code to
  /// (not in international form, or not a mobile number).
  phoneNumberInvalid,

  /// Too many sign-in codes were asked for this number (3 in 15 minutes,
  /// 10 a day) or from this connection; waiting helps.
  tooManySignInCodes,

  /// The SMS sign-in code is wrong, has expired, was already used, or had
  /// too many wrong tries. The same answer covers every case, so nobody
  /// learns which numbers have accounts.
  signInCodeWrong,

  /// Too many sign-in codes were checked from this connection; waiting
  /// helps.
  tooManyCodeTries,

  /// This way to sign in (SMS code or Google) is switched off on the
  /// server, or the server does not offer it.
  signInMethodOff,

  /// The server refused a Google sign-in: no account here uses that Google
  /// email, the admin has not confirmed it, the account is not active, or
  /// Google shared no confirmed email.
  googleSignInRefused,

  /// The person stopped a sign-in that was waiting for them (for example,
  /// on Google's page). Not an error to show.
  signInCancelled,

  /// The phone could not open a web page for signing in (no browser).
  browserUnavailable,

  /// An organisation admin gave this account a one-time password: the
  /// person must choose their own password before anything else works (the
  /// server answers HTTP 403 with the reason `password_change_required`).
  /// Finished forms stay queued until they have.
  passwordChangeRequired,

  /// The current password typed while choosing a new one (usually the
  /// one-time password) is not right. Nothing was changed.
  currentPasswordWrong,

  /// The new password cannot be used: it is shorter than 12 or longer than
  /// 71 characters, or the server refused it. Nothing was changed.
  newPasswordInvalid,

  /// The new password is saved, but signing in with it straight afterwards
  /// did not work (for example, the connection dropped). Every earlier
  /// session has ended; the person signs in again with the new password.
  passwordChangedSignInAgain,

  /// This phone is not enrolled with the server yet, so its requests carry
  /// no device signature (the server's reason `device_signature_required`).
  /// The app enrols it; nothing is sent before.
  deviceNotEnrolled,

  /// The server could not check this phone's signature (the reason
  /// `device_signature_invalid`: for example a request repeated, or a server
  /// restart in the same second). Trying again usually works.
  deviceSignatureInvalid,

  /// The server no longer knows this phone's device (the reason
  /// `device_unknown`; for example, it was restored from a backup older
  /// than the enrolment). The phone forgets its device id, keeps its keys
  /// and enrols again with them: it must be approved again. Finished forms
  /// stay queued.
  deviceUnknown,

  /// The server refused the phone's signed request because the phone's
  /// clock is more than 5 minutes from the server's (the reason
  /// `device_clock`). The person sets the date and time, then tries again.
  deviceClockWrong,

  /// This phone is waiting for a branch manager or an organisation admin to
  /// approve it (the reason `device_not_approved`). Finished forms stay
  /// queued and are sent once it is approved.
  deviceNotApproved,

  /// This phone's approval (one year) has run out; it must be approved again
  /// with the same check code (the reason `device_expired`). Finished forms
  /// stay queued.
  deviceApprovalExpired,

  /// This phone has been switched off for Obhijatra by the organisation (the
  /// reason `device_revoked`). It must be set up again as a new device.
  /// Finished forms stay on the phone.
  deviceRevoked,

  /// The server has ended this session (the reason `session_revoked`): the
  /// person signs in again. Finished forms stay queued.
  sessionEnded,

  /// This session belongs to another device (the reason
  /// `session_other_device`): the person signs in again on this phone.
  sessionOnOtherDevice,

  /// Enrolling refused: this phone's key is already in use (by another
  /// person, or by a device that was switched off; HTTP 409). New keys
  /// solve it.
  deviceKeyInUse,

  /// Enrolling refused: 3 of this person's devices are already waiting for
  /// approval (HTTP 429). An approver must approve or switch them off first.
  tooManyDevicesWaiting,

  /// Something unexpected happened inside the app.
  unknown;

  /// Parses a stored code; unknown or missing names give [unknown].
  static ProblemCode fromName(String? name) {
    for (final code in values) {
      if (code.name == name) return code;
    }
    return unknown;
  }

  /// Whether trying again later may succeed without anyone changing anything.
  bool get isTransient => switch (this) {
    offline ||
    timeout ||
    serverError ||
    serverBusy ||
    unexpectedResponse ||
    redirected ||
    deviceSignatureInvalid ||
    unknown => true,
    _ => false,
  };

  /// Whether the problem stops all syncing (not just one submission) until
  /// the user or an administrator acts.
  bool get blocksSync => switch (this) {
    signInRequired ||
    accountNotPermitted ||
    differentUser ||
    appUpdateRequired ||
    serverIncompatible ||
    serverNotSetUp ||
    clockSkew ||
    passwordChangeRequired ||
    deviceNotEnrolled ||
    deviceUnknown ||
    deviceClockWrong ||
    deviceNotApproved ||
    deviceApprovalExpired ||
    deviceRevoked ||
    sessionEnded ||
    sessionOnOtherDevice => true,
    _ => false,
  };

  /// Whether the server refused the request because of this phone's device
  /// trust (docs/decisions/0008-device-trust.md): never a fault of the data
  /// sent, so no submission is ever marked as failed for it.
  bool get isDeviceProblem => switch (this) {
    deviceNotEnrolled ||
    deviceSignatureInvalid ||
    deviceUnknown ||
    deviceClockWrong ||
    deviceNotApproved ||
    deviceApprovalExpired ||
    deviceRevoked ||
    sessionEnded ||
    sessionOnOtherDevice => true,
    _ => false,
  };

  /// Whether only signing in again helps: the session has run out, has been
  /// ended, or belongs to another device.
  bool get needsSignInAgain =>
      this == signInRequired ||
      this == sessionEnded ||
      this == sessionOnOtherDevice;
}

/// An exception carrying a [ProblemCode] for the UI and details for logs.
final class ObhijatraException implements Exception {
  /// Creates an exception with a [code] and optional diagnostic details.
  const ObhijatraException(
    this.code, {
    this.statusCode,
    this.serverMessage,
    this.cause,
  });

  /// The plain-language problem code.
  final ProblemCode code;

  /// The HTTP status code, when the problem came from the server.
  final int? statusCode;

  /// The server's own plain-language message, if it sent one.
  final String? serverMessage;

  /// The underlying error, for diagnostics only; never shown to users.
  final Object? cause;

  @override
  String toString() {
    final parts = <String>[
      'ObhijatraException(${code.name}',
      if (statusCode != null) 'status: $statusCode',
      if (serverMessage != null) 'message: $serverMessage',
    ];
    return '${parts.join(', ')})';
  }
}
