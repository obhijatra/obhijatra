import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obhijatra_device/obhijatra_device.dart'
    show DeviceReason, RedirectNotFollowed;
import 'package:obhijatra_manager/src/device/identity_store.dart'
    show DeviceKeysUnavailable;
import 'package:pocketbase/pocketbase.dart';
import 'package:xml/xml.dart';

/// What went wrong, in terms a manager can act on.
enum ProblemKind {
  /// No connection to the server.
  offline,

  /// The server took too long.
  timeout,

  /// HTTP 429.
  serverBusy,

  /// HTTP 5xx.
  serverError,

  /// HTTP 401: the session ended.
  signInRequired,

  /// The email or password was refused.
  signInFailed,

  /// HTTP 403.
  notAllowed,

  /// HTTP 404.
  notFound,

  /// HTTP 413, or a file over 10 MB.
  tooLarge,

  /// HTTP 400 without a more specific cause.
  rejected,

  /// The form version was already uploaded.
  versionExists,

  /// The decision was saved but this server has nowhere to keep the note.
  commentNotSaved,

  /// The chosen file is not readable XML.
  unreadableFile,

  /// The form definition needed to show answers safely is not available.
  formUnavailable,

  /// Google sign-in: no account here uses that Google email address.
  googleNoAccount,

  /// Google sign-in: an admin has not confirmed the account's email address.
  googleUnconfirmed,

  /// Google sign-in: the account may not sign in (switched off).
  googleNotAllowed,

  /// Google sign-in: Google shared no confirmed email address.
  googleNoEmail,

  /// Google sign-in: the address is neither Gmail nor Google Workspace, so
  /// Google cannot vouch that it still belongs to the person.
  googleUnmanaged,

  /// Google sign-in is not switched on for this server.
  googleUnavailable,

  /// Google sign-in did not finish (the browser step failed or was lost).
  googleFailed,

  /// SMS-code sign-in is switched off on this server.
  smsOff,

  /// The mobile number is not in a usable form.
  phoneInvalid,

  /// The SMS code is wrong, expired or already used.
  codeWrong,

  /// Too many codes were asked for this number.
  tooManyCodes,

  /// Too many code checks from this connection.
  tooManyTries,

  /// Too many test messages from this admin.
  tooManyTests,

  /// Some submitted settings were refused; see [AppProblem.fields].
  settingsInvalid,

  /// Some details about a person (or a new password) were refused; see
  /// [AppProblem.fields] and [AppProblem.codes].
  detailsInvalid,

  /// HTTP 403 with reason `password_change_required`: the person signed
  /// in with a one-time password and must choose their own first.
  passwordChangeRequired,

  /// The new password was saved, but signing in again with it failed.
  passwordSavedSignIn,

  /// HTTP 409 on a change to a person: someone changed the record between
  /// loading and saving it.
  personChanged,

  /// HTTP 401 `session_other_device`: the session belongs to another
  /// device. (`session_revoked` is [signInRequired].)
  sessionOtherDevice,

  /// HTTP 403 `device_signature_required`: the request was not signed by a
  /// device.
  deviceNotSetUp,

  /// HTTP 403 `device_signature_invalid`: the signature could not be
  /// checked, even when sent again.
  deviceCheckFailed,

  /// HTTP 403 `device_unknown`: the server does not know this device (for
  /// example, it was restored from a backup older than the enrolment). The
  /// device check enrols the same keys again; it needs approval again.
  deviceUnknown,

  /// HTTP 403 `device_clock`: this computer's clock is more than 5 minutes
  /// from the server's.
  deviceClock,

  /// HTTP 403 `device_not_approved`: the device waits for approval.
  deviceNotApproved,

  /// HTTP 403 `device_revoked`: the device has been switched off.
  deviceRevoked,

  /// HTTP 403 `device_expired`: the device's approval has run out.
  deviceExpired,

  /// The device's keys could not be made or kept on this computer or in
  /// this browser.
  deviceKeysUnavailable,

  /// HTTP 409 at enrolment: the keys belong to another device, or to one
  /// that was switched off.
  deviceKeyInUse,

  /// HTTP 429 at enrolment: 3 of the person's devices already wait.
  tooManyWaitingDevices,

  /// HTTP 400 `validation_device_code_mismatch`: the numbers typed are not
  /// the device's.
  deviceCodeMismatch,

  /// HTTP 409 on an approval: the device no longer waits for this
  /// approver (approved already, or needing a different org admin).
  deviceNotWaiting,

  /// HTTP 403 `recent_sign_in_required`: downloading data needs a sign-in
  /// within the last 15 minutes (docs/decisions/0009-data-export.md).
  recentSignInRequired,

  /// HTTP 400 `validation_form_has_no_version` on a download: the form has
  /// no version, so it has no submissions.
  exportNoVersion,

  /// The downloaded file could not be written where the person chose.
  saveFailed,

  /// Anything else.
  unknown,
}

/// The one thing a person can do about a problem.
enum ProblemAction {
  /// Run the same request again.
  tryAgain,

  /// Go back to the sign-in screen.
  signInAgain,

  /// Dismiss the message.
  close,

  /// Pick a different file.
  chooseFile,

  /// Load the record again from the server.
  reload,
}

/// An error that carries a [ProblemKind]. Raw exceptions never reach a screen.
@immutable
class AppProblem implements Exception {
  /// Creates a problem.
  const AppProblem(
    this.kind, {
    this.statusCode,
    this.fields = const <String, String>{},
    this.codes = const <String, String>{},
  });

  /// What went wrong.
  final ProblemKind kind;

  /// The HTTP status, for diagnostics only.
  final int? statusCode;

  /// Problems with single submitted fields, by the server's dotted field
  /// name (for example `phone.sms.url`), in the server's plain words.
  final Map<String, String> fields;

  /// The server's reason codes for [fields], by the same field names (for
  /// example `validation_not_unique`), so screens can show their own
  /// translated sentence for the codes they know.
  final Map<String, String> codes;

  /// The single action offered for this problem.
  ProblemAction get action => switch (kind) {
    ProblemKind.offline ||
    ProblemKind.timeout ||
    ProblemKind.serverBusy ||
    ProblemKind.serverError ||
    ProblemKind.signInFailed ||
    ProblemKind.formUnavailable ||
    ProblemKind.googleFailed ||
    ProblemKind.passwordChangeRequired ||
    ProblemKind.deviceCheckFailed ||
    ProblemKind.deviceUnknown ||
    ProblemKind.deviceClock ||
    ProblemKind.deviceNotApproved ||
    ProblemKind.deviceRevoked ||
    ProblemKind.deviceExpired ||
    ProblemKind.deviceKeysUnavailable ||
    ProblemKind.deviceKeyInUse ||
    ProblemKind.tooManyWaitingDevices ||
    ProblemKind.saveFailed ||
    ProblemKind.unknown => ProblemAction.tryAgain,
    ProblemKind.signInRequired ||
    ProblemKind.sessionOtherDevice ||
    ProblemKind.deviceNotSetUp ||
    ProblemKind.passwordSavedSignIn => ProblemAction.signInAgain,
    ProblemKind.unreadableFile => ProblemAction.chooseFile,
    ProblemKind.personChanged ||
    ProblemKind.deviceNotWaiting => ProblemAction.reload,
    ProblemKind.notAllowed ||
    ProblemKind.notFound ||
    ProblemKind.tooLarge ||
    ProblemKind.rejected ||
    ProblemKind.versionExists ||
    ProblemKind.commentNotSaved ||
    ProblemKind.googleNoAccount ||
    ProblemKind.googleUnconfirmed ||
    ProblemKind.googleNotAllowed ||
    ProblemKind.googleNoEmail ||
    ProblemKind.googleUnmanaged ||
    ProblemKind.googleUnavailable ||
    ProblemKind.smsOff ||
    ProblemKind.phoneInvalid ||
    ProblemKind.codeWrong ||
    ProblemKind.tooManyCodes ||
    ProblemKind.tooManyTries ||
    ProblemKind.tooManyTests ||
    ProblemKind.settingsInvalid ||
    ProblemKind.detailsInvalid ||
    ProblemKind.deviceCodeMismatch ||
    ProblemKind.recentSignInRequired ||
    ProblemKind.exportNoVersion => ProblemAction.close,
  };

  @override
  String toString() => 'AppProblem(${kind.name}, status: $statusCode)';
}

/// Turns any error into an [AppProblem].
AppProblem problemFrom(Object error) {
  if (error is AppProblem) return error;
  if (error is TimeoutException) {
    return const AppProblem(ProblemKind.timeout);
  }
  if (error is FormatException || error is XmlException) {
    return const AppProblem(ProblemKind.unreadableFile);
  }
  if (error is DeviceKeysUnavailable) {
    return const AppProblem(ProblemKind.deviceKeysUnavailable);
  }
  // A redirect is never followed (it may be a Wi-Fi sign-in page): the
  // server was not reached.
  if (error is RedirectNotFollowed) {
    return const AppProblem(ProblemKind.offline);
  }
  if (error is ClientException) {
    // The SDK reports every failed connection (no network, refused, reset)
    // as an aborted request with status 0.
    final status = error.statusCode;
    final kind = switch (status) {
      0 => ProblemKind.offline,
      401 =>
        _reasonCode(error) == DeviceReason.sessionOtherDevice
            ? ProblemKind.sessionOtherDevice
            : ProblemKind.signInRequired,
      403 => switch (_reasonCode(error)) {
        passwordChangeRequiredReason => ProblemKind.passwordChangeRequired,
        recentSignInRequiredReason => ProblemKind.recentSignInRequired,
        DeviceReason.signatureRequired => ProblemKind.deviceNotSetUp,
        DeviceReason.signatureInvalid => ProblemKind.deviceCheckFailed,
        DeviceReason.unknown => ProblemKind.deviceUnknown,
        DeviceReason.clock => ProblemKind.deviceClock,
        DeviceReason.notApproved => ProblemKind.deviceNotApproved,
        DeviceReason.revoked => ProblemKind.deviceRevoked,
        DeviceReason.expired => ProblemKind.deviceExpired,
        _ => ProblemKind.notAllowed,
      },
      404 => ProblemKind.notFound,
      413 => ProblemKind.tooLarge,
      429 => ProblemKind.serverBusy,
      400 =>
        _isNotUnique(error) ? ProblemKind.versionExists : ProblemKind.rejected,
      >= 500 => ProblemKind.serverError,
      _ => ProblemKind.unknown,
    };
    return AppProblem(kind, statusCode: status);
  }
  return const AppProblem(ProblemKind.unknown);
}

/// The server's per-field problems in a 400 answer, by dotted field name.
Map<String, String> fieldProblems(ClientException error) {
  final data = error.response['data'];
  if (data is! Map<String, dynamic>) return const <String, String>{};
  return <String, String>{
    for (final entry in data.entries)
      if (entry.value is Map<String, dynamic>)
        entry.key: switch ((entry.value as Map<String, dynamic>)['message']) {
          final String message => message,
          _ => '',
        },
  };
}

/// The server's reason codes per field in a 400 answer, by field name.
Map<String, String> fieldCodes(ClientException error) {
  final data = error.response['data'];
  if (data is! Map<String, dynamic>) return const <String, String>{};
  return <String, String>{
    for (final entry in data.entries)
      if (entry.value case {'code': final String code}) entry.key: code,
  };
}

/// The reason code the server gives a person who must choose a new
/// password before anything else (HTTP 403).
const String passwordChangeRequiredReason = 'password_change_required';

/// Whether [kind] is a refusal of this device (not of the person): the app
/// then checks the device again and shows what to do about it (or, for a
/// device the server no longer knows, enrols it again).
bool isDeviceRefusal(ProblemKind kind) =>
    kind == ProblemKind.deviceUnknown ||
    kind == ProblemKind.deviceClock ||
    kind == ProblemKind.deviceNotApproved ||
    kind == ProblemKind.deviceRevoked ||
    kind == ProblemKind.deviceExpired;

/// `data.reason.code` of a 403 answer when downloading data needs a sign-in
/// within the last 15 minutes (a session refresh does not count).
const String recentSignInRequiredReason = 'recent_sign_in_required';

/// `data.reason.code` of an error answer, or an empty string.
String _reasonCode(ClientException error) => switch (error.response['data']) {
  {'reason': {'code': final String code}} => code,
  _ => '',
};

/// The server's own sentence in an error answer, or an empty string.
String serverMessage(ClientException error) =>
    switch (error.response['message']) {
      final String message => message,
      _ => '',
    };

bool _isNotUnique(ClientException error) {
  final data = error.response['data'];
  if (data is! Map<String, dynamic>) return false;
  return data.values.any(
    (field) =>
        field is Map<String, dynamic> &&
        field['code'] == 'validation_not_unique',
  );
}
