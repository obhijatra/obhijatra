import 'package:flutter/material.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// How prominent a [PrimaryButton] is.
enum PrimaryButtonVariant {
  /// The one main action on a screen (filled).
  primary,

  /// A second action (outlined).
  secondary,

  /// A quiet action (text only).
  ghost,
}

/// A full-width, 48 dp high button with a word on it and an optional icon.
///
/// The label wraps instead of being cut off, so it stays whole in Bangla and
/// at the largest text size. While [busy] the button cannot be pressed and
/// shows a progress ring next to the word.
class PrimaryButton extends StatelessWidget {
  /// Creates a button.
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PrimaryButtonVariant.primary,
    this.busy = false,
    this.expand = true,
    super.key,
  });

  /// The words on the button.
  final String label;

  /// Called on press; `null` disables the button.
  final VoidCallback? onPressed;

  /// An icon before the label.
  final IconData? icon;

  /// An icon after the label.
  final IconData? trailingIcon;

  /// How prominent the button is.
  final PrimaryButtonVariant variant;

  /// Whether the button is working (disables it and shows a progress ring).
  final bool busy;

  /// Whether the button fills the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final callback = busy ? null : onPressed;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          const SizedBox.square(
            dimension: Sizes.icon,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        else if (icon != null)
          Icon(icon, size: Sizes.icon),
        if (busy || icon != null) const SizedBox(width: Spacing.space2),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: Spacing.space2),
          Icon(trailingIcon, size: Sizes.icon),
        ],
      ],
    );
    final button = switch (variant) {
      PrimaryButtonVariant.primary => FilledButton(
        onPressed: callback,
        child: child,
      ),
      PrimaryButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        child: child,
      ),
      PrimaryButtonVariant.ghost => TextButton(
        onPressed: callback,
        child: child,
      ),
    };
    return Semantics(
      container: true,
      button: true,
      enabled: callback != null,
      label: label,
      excludeSemantics: true,
      onTap: callback,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: Sizes.touch,
          minWidth: expand ? double.infinity : Sizes.touch,
        ),
        child: button,
      ),
    );
  }
}
