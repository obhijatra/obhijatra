import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Shown when the saved data on the phone cannot be opened. Nothing is
/// deleted; the person is told plainly what to do.
class StartupProblemScreen extends StatelessWidget {
  /// Creates the screen for [code]; [onRetry] tries to open the data again.
  const StartupProblemScreen({
    required this.code,
    required this.onRetry,
    super.key,
  });

  /// What went wrong.
  final ProblemCode code;

  /// Tries again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return ScreenFrame(
      topBar: TopBar(title: l.appTitle, showMark: true),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          const SizedBox(height: Spacing.space8),
          ResultHeader(
            icon: LucideIcons.triangleAlert,
            iconColor: p.warning,
            iconBackground: p.warningSubtle,
            title: l.startupProblemTitle,
          ),
          const SizedBox(height: Spacing.space4),
          Text(
            problemText(l, code),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
      bottom: BottomActions(
        children: <Widget>[
          PrimaryButton(
            label: l.actionRetryStartup,
            icon: LucideIcons.refreshCw,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
