import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The colour role of a badge or message.
enum Tone {
  /// Plain grey.
  neutral,

  /// Success: green.
  success,

  /// Warning: brown on cream.
  warning,

  /// Danger: red.
  danger,

  /// Information: blue.
  info,
}

/// Foreground and background of a [Tone] in the current theme.
extension ToneColors on Tone {
  /// Text and icon colour.
  Color foreground(ObhijatraPalette p) => switch (this) {
    Tone.neutral => p.text,
    Tone.success => p.success,
    Tone.warning => p.warning,
    Tone.danger => p.danger,
    Tone.info => p.info,
  };

  /// Soft background colour.
  Color background(ObhijatraPalette p) => switch (this) {
    Tone.neutral => p.surfaceSunken,
    Tone.success => p.successSubtle,
    Tone.warning => p.warningSubtle,
    Tone.danger => p.dangerSubtle,
    Tone.info => p.infoSubtle,
  };
}

/// A small label with a word, a colour and an icon. Colour is never the only
/// signal: the word is always there.
class ObBadge extends StatelessWidget {
  /// Creates a badge.
  const ObBadge({
    required this.label,
    this.tone = Tone.neutral,
    this.icon,
    super.key,
  });

  /// The word shown.
  final String label;

  /// The colour role.
  final Tone tone;

  /// An optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = tone.foreground(palette);
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(color: fg);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: tone.background(palette),
        borderRadius: Radii.xsAll,
        border: Border.all(
          color: tone == Tone.neutral
              ? palette.border
              : tone.background(palette),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: Sizes.iconSm, color: fg),
            const SizedBox(width: Spacing.space1),
          ],
          Flexible(child: Text(label, style: style)),
        ],
      ),
    );
  }
}
