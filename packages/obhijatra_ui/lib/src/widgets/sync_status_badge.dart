import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// What a [SyncStatusBadge] reports.
enum SyncVisualState {
  /// The server has it.
  synced,

  /// Safe on this phone, not sent yet.
  local,

  /// Being sent now.
  sending,

  /// No connection; waiting for signal.
  offline,

  /// The server refused it, or someone must act.
  problem,
}

/// A rounded chip that says where a piece of work is: sent, only on this
/// phone, being sent, waiting for signal or in trouble.
///
/// Colour is never alone: every state has its own icon and its own words.
/// This is the Flutter counterpart of the design's `as-sync` component and
/// is separate from the core's `SyncStatus` data class, which the app maps
/// onto a [SyncVisualState].
class SyncStatusBadge extends StatelessWidget {
  /// Creates the badge showing [state] with the words [label].
  const SyncStatusBadge({required this.state, required this.label, super.key});

  /// What to show.
  final SyncVisualState state;

  /// The words, for example "Sent today at 10:32".
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (IconData icon, Color fg, Color bg) = switch (state) {
      SyncVisualState.synced => (
        LucideIcons.cloudCheck,
        p.success,
        p.successSubtle,
      ),
      SyncVisualState.local => (LucideIcons.smartphone, p.text, p.surface),
      SyncVisualState.sending => (
        LucideIcons.cloudUpload,
        p.info,
        p.infoSubtle,
      ),
      SyncVisualState.offline => (LucideIcons.cloudOff, p.info, p.infoSubtle),
      SyncVisualState.problem => (
        LucideIcons.triangleAlert,
        p.warning,
        p.warningSubtle,
      ),
    };
    final border = state == SyncVisualState.local ? p.borderStrong : fg;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: Spacing.space8),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space3,
            vertical: Spacing.space1,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: Radii.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: Sizes.iconSm, color: fg),
              const SizedBox(width: Spacing.space2),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge!
                      .copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
