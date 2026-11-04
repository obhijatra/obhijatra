import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A white panel with the design system's outline, radius and soft shadow.
class ObPanel extends StatelessWidget {
  /// Creates a panel.
  const ObPanel({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.strongBorder = false,
    super.key,
  });

  /// The panel's content.
  final Widget child;

  /// Space between the outline and [child].
  final EdgeInsetsGeometry padding;

  /// Use the stronger outline (the open side panel).
  final bool strongBorder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: strongBorder ? palette.borderStrong : palette.border,
        ),
        boxShadow: Shadows.sm(palette.brightness),
      ),
      child: child,
    );
  }
}
