import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// One line of a [ValidationSummary]: a question that needs attention.
@immutable
class ValidationSummaryItem {
  /// Creates an item. [onTap] jumps to the question.
  const ValidationSummaryItem({required this.label, required this.onTap});

  /// For example "Question 9: How many people live here?"
  final String label;

  /// Takes the person to the question.
  final VoidCallback onTap;
}

/// A red-edged box that lists what must be fixed before sending, each line
/// a link that jumps to the question.
class ValidationSummary extends StatelessWidget {
  /// Creates the summary.
  const ValidationSummary({
    required this.title,
    required this.message,
    required this.items,
    super.key,
  });

  /// For example "One answer is missing".
  final String title;

  /// For example "Answer it, then send again."
  final String message;

  /// The questions to fix.
  final List<ValidationSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.space4),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.danger, width: 2),
          borderRadius: Radii.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.space1),
                  child: Icon(
                    LucideIcons.circleAlert,
                    size: Sizes.icon,
                    color: p.danger,
                  ),
                ),
                const SizedBox(width: Spacing.space2),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: theme.titleMedium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.space2),
            Text(message, style: theme.bodyMedium),
            for (final item in items)
              Semantics(
                link: true,
                button: true,
                label: item.label,
                excludeSemantics: true,
                onTap: item.onTap,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: Radii.xsAll,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Sizes.touch),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        item.label,
                        style: theme.labelLarge!.copyWith(
                          color: p.danger,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
