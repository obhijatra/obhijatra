import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/screens/form_entry_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The three things that can happen when a form is finished.
sealed class SendOutcome {
  const SendOutcome();

  /// The server has the form.
  const factory SendOutcome.sent(DateTime at) = SentOutcome;

  /// The form is safe on the phone and will be sent when there is signal.
  const factory SendOutcome.waiting(int count) = WaitingOutcome;

  /// The form is safe on the phone but cannot be sent until something
  /// changes.
  const factory SendOutcome.problem(ProblemCode code) = ProblemOutcome;
}

/// See [SendOutcome.sent].
final class SentOutcome extends SendOutcome {
  /// Creates the outcome.
  const SentOutcome(this.at);

  /// When the server confirmed it.
  final DateTime at;
}

/// See [SendOutcome.waiting].
final class WaitingOutcome extends SendOutcome {
  /// Creates the outcome.
  const WaitingOutcome(this.count);

  /// How many forms are waiting to be sent, including this one.
  final int count;
}

/// See [SendOutcome.problem].
final class ProblemOutcome extends SendOutcome {
  /// Creates the outcome.
  const ProblemOutcome(this.code);

  /// Why it cannot be sent.
  final ProblemCode code;
}

/// What happened to the form just finished: sent, waiting for signal, or a
/// problem. In every case the answers are safe.
class OutcomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const OutcomeScreen({
    required this.outcome,
    required this.formId,
    this.formTitle,
    super.key,
  });

  /// What happened.
  final SendOutcome outcome;

  /// The form that was finished.
  final String formId;

  /// The form title.
  final String? formTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final now = ref.watch(nowProvider)();

    final IconData icon;
    final Color iconColor;
    final Color iconBackground;
    final String title;
    final List<Widget> body;
    switch (outcome) {
      case SentOutcome(:final at):
        icon = LucideIcons.circleCheck;
        iconColor = p.success;
        iconBackground = p.successSubtle;
        title = l.outcomeSentTitle;
        body = <Widget>[
          Text(l.outcomeSentBody, style: text.bodyLarge),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SyncStatusBadge(
              state: SyncVisualState.synced,
              label: l.outcomeSentChip(fmt.when(at, bangla: bangla, now: now)),
            ),
          ),
        ];
      case WaitingOutcome(:final count):
        icon = LucideIcons.cloudOff;
        iconColor = p.info;
        iconBackground = p.infoSubtle;
        title = l.outcomeWaitingTitle;
        body = <Widget>[
          Text(l.outcomeWaitingBody, style: text.bodyLarge),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SyncStatusBadge(
              state: SyncVisualState.local,
              label: l.stateOnPhone,
            ),
          ),
          Text(
            l.outcomeWaitingCount(count),
            style: text.bodyMedium!.copyWith(color: p.textMuted),
          ),
        ];
      case ProblemOutcome(:final code):
        icon = LucideIcons.triangleAlert;
        iconColor = p.warning;
        iconBackground = p.warningSubtle;
        title = l.outcomeProblemTitle;
        body = <Widget>[
          Text(problemText(l, code), style: text.bodyLarge),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: Icon(
                  LucideIcons.smartphone,
                  size: Sizes.icon,
                  color: p.success,
                ),
              ),
              const SizedBox(width: Spacing.space2),
              Expanded(
                child: Text(l.outcomeProblemSafe, style: text.bodyMedium),
              ),
            ],
          ),
        ];
    }

    final signInNeeded =
        outcome is ProblemOutcome &&
        (outcome as ProblemOutcome).code == ProblemCode.signInRequired;
    final canStartNext = outcome is! ProblemOutcome || !signInNeeded;

    return ScreenFrame(
      topBar: TopBar(
        title: formTitle ?? l.appTitle,
        leadingIcon: LucideIcons.x,
        leadingLabel: l.actionClose,
        onLeading: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space6),
        children: <Widget>[
          Semantics(
            liveRegion: true,
            container: true,
            child: ResultHeader(
              icon: icon,
              iconColor: iconColor,
              iconBackground: iconBackground,
              title: title,
            ),
          ),
          for (final w in body) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            w,
          ],
        ],
      ),
      bottom: BottomActions(
        children: <Widget>[
          if (signInNeeded)
            PrimaryButton(
              label: l.outcomeSignIn,
              icon: LucideIcons.logIn,
              onPressed: () {
                ref.read(sessionProvider.notifier).signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            )
          else if (canStartNext)
            PrimaryButton(
              label: l.outcomeNext,
              icon: LucideIcons.plus,
              onPressed: () => Navigator.of(context).pushAndRemoveUntil<void>(
                MaterialPageRoute<void>(
                  builder: (_) => FormEntryScreen(
                    args: FormEntryArgs(
                      formId: formId,
                      token: DateTime.now().microsecondsSinceEpoch,
                    ),
                  ),
                ),
                (route) => route.isFirst,
              ),
            ),
          PrimaryButton(
            label: l.outcomeBackToToday,
            variant: signInNeeded
                ? PrimaryButtonVariant.secondary
                : PrimaryButtonVariant.secondary,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }
}
