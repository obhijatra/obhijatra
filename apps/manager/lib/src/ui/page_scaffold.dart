import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The padding and heading every screen shares.
class PageScaffold extends StatelessWidget {
  /// Creates a page with [title] and [child].
  const PageScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// The page heading.
  final String title;

  /// A line of muted text under the heading.
  final String? subtitle;

  /// Something at the right of the heading (for example a button).
  final Widget? trailing;

  /// The page body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.space6,
        Spacing.space6,
        Spacing.space6,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(title, style: text.headlineMedium),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: text.bodyMedium!.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: Spacing.space4),
          Expanded(child: child),
        ],
      ),
    );
  }
}
