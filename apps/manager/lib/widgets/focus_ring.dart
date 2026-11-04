import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Draws the design system's focus ring (2 px, 2 px away) around [child]
/// while the child, or anything inside it, has keyboard focus.
class FocusRing extends StatefulWidget {
  /// Creates a focus ring around [child].
  const FocusRing({
    required this.child,
    this.borderRadius = Radii.smAll,
    super.key,
  });

  /// The control to outline.
  final Widget child;

  /// Corner radius of the ring (the control's own radius).
  final BorderRadius borderRadius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.focus;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (mounted && focused != _focused) setState(() => _focused = focused);
      },
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: _focused ? Border.all(color: color, width: 2) : null,
        ),
        child: widget.child,
      ),
    );
  }
}
