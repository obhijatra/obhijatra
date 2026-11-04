import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';

/// Translates a [ProblemCode] into plain words in the language of [l10n].
///
/// The switch has no default on purpose: when the core adds a code, the
/// build fails here until the new code has an English and a Bangla sentence
/// in `lib/l10n/app_en.arb` and `app_bn.arb`.
///
/// DRAFT: the Bangla sentences (`problem_*` in `app_bn.arb`) are drafts
/// written by the engineering assistant; the owner must check each one.
String problemText(AppLocalizations l10n, ProblemCode code) => switch (code) {
  ProblemCode.offline => l10n.problem_offline,
  ProblemCode.timeout => l10n.problem_timeout,
  ProblemCode.serverError => l10n.problem_serverError,
  ProblemCode.serverBusy => l10n.problem_serverBusy,
  ProblemCode.signInRequired => l10n.problem_signInRequired,
  ProblemCode.signInFailed => l10n.problem_signInFailed,
  ProblemCode.accountNotPermitted => l10n.problem_accountNotPermitted,
  ProblemCode.differentUser => l10n.problem_differentUser,
  ProblemCode.appUpdateRequired => l10n.problem_appUpdateRequired,
  ProblemCode.serverIncompatible => l10n.problem_serverIncompatible,
  ProblemCode.serverNotSetUp => l10n.problem_serverNotSetUp,
  ProblemCode.clockSkew => l10n.problem_clockSkew,
  ProblemCode.duplicateInstance => l10n.problem_duplicateInstance,
  ProblemCode.formNotOnServer => l10n.problem_formNotOnServer,
  ProblemCode.submissionInvalid => l10n.problem_submissionInvalid,
  ProblemCode.submissionTooLarge => l10n.problem_submissionTooLarge,
  ProblemCode.attachmentMissing => l10n.problem_attachmentMissing,
  ProblemCode.formInvalid => l10n.problem_formInvalid,
  ProblemCode.databaseKeyMissing => l10n.problem_databaseKeyMissing,
  ProblemCode.databaseKeyRejected => l10n.problem_databaseKeyRejected,
  ProblemCode.databaseFromNewerApp => l10n.problem_databaseFromNewerApp,
  ProblemCode.databaseUnavailable => l10n.problem_databaseUnavailable,
  ProblemCode.unexpectedResponse => l10n.problem_unexpectedResponse,
  ProblemCode.unknown => l10n.problem_unknown,
};

/// The problem code behind any error that reached the screen; anything that
/// is not an [ObhijatraException] counts as [ProblemCode.unknown].
ProblemCode problemOf(Object error) =>
    error is ObhijatraException ? error.code : ProblemCode.unknown;
