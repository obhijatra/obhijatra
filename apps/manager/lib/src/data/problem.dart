import 'dart:async';

import 'package:flutter/foundation.dart';
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
}

/// An error that carries a [ProblemKind]. Raw exceptions never reach a screen.
@immutable
class AppProblem implements Exception {
  /// Creates a problem.
  const AppProblem(this.kind, {this.statusCode});

  /// What went wrong.
  final ProblemKind kind;

  /// The HTTP status, for diagnostics only.
  final int? statusCode;

  /// The single action offered for this problem.
  ProblemAction get action => switch (kind) {
    ProblemKind.offline ||
    ProblemKind.timeout ||
    ProblemKind.serverBusy ||
    ProblemKind.serverError ||
    ProblemKind.signInFailed ||
    ProblemKind.formUnavailable ||
    ProblemKind.unknown => ProblemAction.tryAgain,
    ProblemKind.signInRequired => ProblemAction.signInAgain,
    ProblemKind.unreadableFile => ProblemAction.chooseFile,
    ProblemKind.notAllowed ||
    ProblemKind.notFound ||
    ProblemKind.tooLarge ||
    ProblemKind.rejected ||
    ProblemKind.versionExists ||
    ProblemKind.commentNotSaved => ProblemAction.close,
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
  if (error is ClientException) {
    // The SDK reports every failed connection (no network, refused, reset)
    // as an aborted request with status 0.
    final status = error.statusCode;
    final kind = switch (status) {
      0 => ProblemKind.offline,
      401 => ProblemKind.signInRequired,
      403 => ProblemKind.notAllowed,
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

bool _isNotUnique(ClientException error) {
  final data = error.response['data'];
  if (data is! Map<String, dynamic>) return false;
  return data.values.any(
    (field) =>
        field is Map<String, dynamic> &&
        field['code'] == 'validation_not_unique',
  );
}
