import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The answers of one submission, one row each.
///
/// A protected answer is drawn as the sealed [ProtectedChip]. An [Answer]
/// that is protected has no value to draw, so this widget could not show one
/// even by mistake, on any platform.
class AnswerList extends StatelessWidget {
  /// Creates the list.
  const AnswerList({required this.answers, super.key});

  /// The answers to show.
  final List<Answer> answers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    if (answers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.space3),
        child: Text(
          l10n.detailNoAnswers,
          style: text.bodyMedium!.copyWith(color: palette.textMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final answer in answers)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  answer.label,
                  style: text.bodySmall!.copyWith(color: palette.textMuted),
                ),
                const SizedBox(height: 2),
                if (answer.isProtected)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.space1),
                    child: ProtectedChip(label: l10n.protectedAnswer),
                  )
                else
                  Text(
                    answer.value ?? '',
                    style: text.titleSmall!.copyWith(
                      fontSize: text.bodyMedium!.fontSize,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
