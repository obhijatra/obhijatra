import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// The frame every question widget shares: the question (with its number and
/// an "answer required" word), help text, the answer and a message in plain
/// words when the answer is not accepted.
class QuestionFrame extends StatelessWidget {
  /// Creates the frame around [child].
  const QuestionFrame({
    required this.label,
    required this.child,
    this.number,
    this.requiredLabel,
    this.help,
    this.errorText,
    super.key,
  });

  /// The question.
  final String label;

  /// The question number to show before the label, for example "4.".
  final String? number;

  /// The word shown when an answer is required, for example "Required".
  /// `null` for an optional question.
  final String? requiredLabel;

  /// Help text under the question.
  final String? help;

  /// Why the answer was not accepted, in plain words.
  final String? errorText;

  /// The place to answer.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context).textTheme;
    final labelStyle = theme.titleSmall!.copyWith(
      fontSize: theme.bodyMedium!.fontSize,
      height: theme.bodyMedium!.height,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          label: <String>[
            ?number,
            label,
            ?requiredLabel,
          ].join(' '),
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                if (number != null)
                  TextSpan(
                    text: '$number ',
                    style: TextStyle(color: p.textMuted),
                  ),
                TextSpan(text: label),
                if (requiredLabel != null)
                  TextSpan(
                    text: '  $requiredLabel',
                    style: theme.labelSmall!.copyWith(
                      color: p.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            style: labelStyle.copyWith(color: p.text),
          ),
        ),
        if (help != null) ...<Widget>[
          const SizedBox(height: Spacing.space1),
          Text(help!, style: theme.bodySmall!.copyWith(color: p.textMuted)),
        ],
        const SizedBox(height: Spacing.space3),
        child,
        if (errorText != null) ...<Widget>[
          const SizedBox(height: Spacing.space2),
          Semantics(
            liveRegion: true,
            container: true,
            label: errorText,
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.circleAlert,
                      size: Sizes.iconSm,
                      color: p.danger,
                    ),
                  ),
                  const SizedBox(width: Spacing.space2),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: theme.bodySmall!.copyWith(
                        color: p.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
