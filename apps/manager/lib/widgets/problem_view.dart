import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The plain sentence for a problem.
String problemMessage(AppLocalizations l10n, ProblemKind kind) =>
    switch (kind) {
      ProblemKind.offline => l10n.problemOffline,
      ProblemKind.timeout => l10n.problemTimeout,
      ProblemKind.serverBusy => l10n.problemServerBusy,
      ProblemKind.serverError => l10n.problemServerError,
      ProblemKind.signInRequired => l10n.problemSignInRequired,
      ProblemKind.signInFailed => l10n.problemSignInFailed,
      ProblemKind.notAllowed => l10n.problemNotAllowed,
      ProblemKind.notFound => l10n.problemNotFound,
      ProblemKind.tooLarge => l10n.problemTooLarge,
      ProblemKind.rejected => l10n.problemRejected,
      ProblemKind.versionExists => l10n.problemVersionExists,
      ProblemKind.commentNotSaved => l10n.problemCommentNotSaved,
      ProblemKind.unreadableFile => l10n.problemUnreadableFile,
      ProblemKind.formUnavailable => l10n.problemFormUnavailable,
      ProblemKind.googleNoAccount => l10n.problemGoogleNoAccount,
      ProblemKind.googleUnconfirmed => l10n.problemGoogleUnconfirmed,
      ProblemKind.googleNotAllowed => l10n.problemGoogleNotAllowed,
      ProblemKind.googleNoEmail => l10n.problemGoogleNoEmail,
      ProblemKind.googleUnmanaged => l10n.problemGoogleUnmanaged,
      ProblemKind.googleUnavailable => l10n.problemGoogleUnavailable,
      ProblemKind.googleFailed => l10n.problemGoogleFailed,
      ProblemKind.smsOff => l10n.problemSmsOff,
      ProblemKind.phoneInvalid => l10n.problemPhoneInvalid,
      ProblemKind.codeWrong => l10n.problemCodeWrong,
      ProblemKind.tooManyCodes => l10n.problemTooManyCodes,
      ProblemKind.tooManyTries => l10n.problemTooManyTries,
      ProblemKind.tooManyTests => l10n.problemTooManyTests,
      ProblemKind.settingsInvalid => l10n.problemSettingsInvalid,
      ProblemKind.detailsInvalid => l10n.problemDetailsInvalid,
      ProblemKind.passwordChangeRequired => l10n.problemPasswordChangeRequired,
      ProblemKind.passwordSavedSignIn => l10n.problemPasswordSavedSignIn,
      ProblemKind.personChanged => l10n.problemPersonChanged,
      ProblemKind.sessionOtherDevice => l10n.problemSessionOtherDevice,
      ProblemKind.deviceNotSetUp => l10n.problemDeviceNotSetUp,
      ProblemKind.deviceCheckFailed => l10n.problemDeviceCheckFailed,
      ProblemKind.deviceUnknown => l10n.problemDeviceUnknown,
      ProblemKind.deviceClock => l10n.problemDeviceClock,
      ProblemKind.deviceNotApproved => l10n.problemDeviceNotApproved,
      ProblemKind.deviceRevoked => l10n.problemDeviceRevoked,
      ProblemKind.deviceExpired => l10n.problemDeviceExpired,
      ProblemKind.deviceKeysUnavailable => l10n.problemDeviceKeysUnavailable,
      ProblemKind.deviceKeyInUse => l10n.problemDeviceKeyInUse,
      ProblemKind.tooManyWaitingDevices => l10n.problemTooManyWaitingDevices,
      ProblemKind.deviceCodeMismatch => l10n.problemDeviceCodeMismatch,
      ProblemKind.deviceNotWaiting => l10n.problemDeviceNotWaiting,
      ProblemKind.unknown => l10n.problemUnknown,
    };

/// The label of the single button offered for a problem.
String problemActionLabel(AppLocalizations l10n, ProblemAction action) =>
    switch (action) {
      ProblemAction.tryAgain => l10n.actionTryAgain,
      ProblemAction.signInAgain => l10n.actionSignInAgain,
      ProblemAction.close => l10n.actionClose,
      ProblemAction.chooseFile => l10n.actionChooseFile,
      ProblemAction.reload => l10n.actionReload,
    };

/// A problem as a sentence with its one action, filling the space it is
/// given (used when a whole screen or panel could not load).
class ProblemView extends StatelessWidget {
  /// Creates the view. [onAction] runs when the button is pressed.
  const ProblemView({
    required this.problem,
    required this.onAction,
    this.compact = false,
    super.key,
  });

  /// Less padding, for small spaces such as a side panel.
  final bool compact;

  /// What went wrong.
  final AppProblem problem;

  /// Runs the action: retry, sign in again, close or choose a file.
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Spacing.space2 : Spacing.space6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.content),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                problem.kind == ProblemKind.offline
                    ? Icons.cloud_off_outlined
                    : Icons.error_outline,
                size: 40,
                color: problem.kind == ProblemKind.offline
                    ? palette.info
                    : palette.danger,
              ),
              const SizedBox(height: Spacing.space3),
              Semantics(
                liveRegion: true,
                child: Text(
                  problemMessage(l10n, problem.kind),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: Spacing.space4),
              FilledButton(
                onPressed: onAction,
                child: Text(problemActionLabel(l10n, problem.action)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A problem as a coloured message inside a form or panel, with its action.
class ProblemBanner extends StatelessWidget {
  /// Creates the banner.
  const ProblemBanner({
    required this.problem,
    required this.onAction,
    super.key,
  });

  /// What went wrong.
  final AppProblem problem;

  /// Runs the action.
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    const tone = Tone.danger;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.space3),
        decoration: BoxDecoration(
          color: tone.background(palette),
          borderRadius: Radii.smAll,
          border: Border.all(color: tone.foreground(palette)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: Sizes.icon,
                  color: tone.foreground(palette),
                ),
                const SizedBox(width: Spacing.space2),
                Expanded(
                  child: Text(
                    problemMessage(l10n, problem.kind),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.space2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onAction,
                child: Text(problemActionLabel(l10n, problem.action)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
