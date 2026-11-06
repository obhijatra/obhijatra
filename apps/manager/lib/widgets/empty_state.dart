import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A calm message for "nothing here": an icon, a title and a sentence.
class EmptyState extends StatelessWidget {
  /// Creates the message.
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  /// The icon above the title.
  final IconData icon;

  /// A short title.
  final String title;

  /// One plain sentence.
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    // Scrolls when the room is short (for example with large text).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.space6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.content),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 40, color: palette.textMuted),
              const SizedBox(height: Spacing.space3),
              Text(title, style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Spacing.space2),
              Text(
                body,
                style: text.bodyMedium!.copyWith(color: palette.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
