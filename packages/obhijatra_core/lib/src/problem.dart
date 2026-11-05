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
    clockSkew => true,
    _ => false,
  };
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
