import 'package:flutter/material.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A short message in a coloured box with an icon, announced to screen
/// readers when it appears: a refusal inside a dialog, a problem with a
/// file, or a note. Colour is never the only signal: the icon and the
/// words say it too.
class NoticeBox extends StatelessWidget {
  /// Creates the box.
  const NoticeBox({
    required this.message,
    this.tone = Tone.danger,
    this.icon,
    this.actions = const <Widget>[],
    super.key,
  });

  /// What to say.
  final String message;

  /// The colour role.
  final Tone tone;

  /// The icon; by default one that fits [tone].
  final IconData? icon;

  /// Buttons under the message, for example "See who works here".
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = tone.foreground(palette);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.space3),
        decoration: BoxDecoration(
          color: tone.background(palette),
          borderRadius: Radii.smAll,
          border: Border.all(color: fg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  icon ??
                      switch (tone) {
                        Tone.danger => Icons.error_outline,
                        Tone.warning => Icons.warning_amber_rounded,
                        Tone.success => Icons.check_circle_outline,
                        Tone.info || Tone.neutral => Icons.info_outline,
                      },
                  size: Sizes.icon,
                  color: fg,
                ),
                const SizedBox(width: Spacing.space2),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.space2),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: Spacing.space2,
                  runSpacing: Spacing.space1,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
