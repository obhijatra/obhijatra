import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';
import 'package:obhijatra_ui/src/widgets/question_frame.dart';

/// One option of a [QuestionChoice].
@immutable
class ChoiceOption {
  /// Creates an option with a stored [value] and the words [label].
  const ChoiceOption(this.value, this.label);

  /// What is stored when this option is chosen.
  final String value;

  /// What the person reads.
  final String label;
}

/// A "choose one" or "choose any" question shown as large tiles.
///
/// A chosen tile has a thicker edge, a tinted background and a mark inside
/// its circle or box, so it never relies on colour alone.
class QuestionChoice extends StatelessWidget {
  /// Creates the question. [selected] holds the chosen values; for a single
  /// choice it has at most one. [onChanged] gets the new set.
  const QuestionChoice({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiple = false,
    this.number,
    this.requiredLabel,
    this.help,
    this.errorText,
    super.key,
  });

  /// The question.
  final String label;

  /// The options, in order.
  final List<ChoiceOption> options;

  /// The values chosen now.
  final Set<String> selected;

  /// Whether more than one option may be chosen.
  final bool multiple;

  /// Called with the new set of chosen values.
  final ValueChanged<Set<String>> onChanged;

  /// The question number to show, for example "4.".
  final String? number;

  /// The "required" word, or `null` when optional.
  final String? requiredLabel;

  /// Help text.
  final String? help;

  /// Why the answer was not accepted.
  final String? errorText;

  void _tap(String value) {
    if (multiple) {
      final next = <String>{...selected};
      if (!next.remove(value)) next.add(value);
      onChanged(next);
    } else {
      onChanged(<String>{value});
    }
  }

  @override
  Widget build(BuildContext context) {
    return QuestionFrame(
      label: label,
      number: number,
      requiredLabel: requiredLabel,
      help: help,
      errorText: errorText,
      child: Semantics(
        container: true,
        child: Column(
          children: <Widget>[
            for (var i = 0; i < options.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: Spacing.space2),
              _ChoiceTile(
                option: options[i],
                selected: selected.contains(options[i].value),
                multiple: multiple,
                onTap: () => _tap(options[i].value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.option,
    required this.selected,
    required this.multiple,
    required this.onTap,
  });

  final ChoiceOption option;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme.bodyMedium!;
    return Semantics(
      container: true,
      label: option.label,
      checked: selected,
      inMutuallyExclusiveGroup: !multiple,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? p.actionSubtle : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.smAll,
          side: BorderSide(
            color: selected ? p.action : p.borderStrong,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.touch + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.space4,
                vertical: Spacing.space3,
              ),
              child: Row(
                children: <Widget>[
                  _Mark(selected: selected, multiple: multiple),
                  const SizedBox(width: Spacing.space3),
                  Expanded(
                    child: Text(
                      option.label,
                      style: text.copyWith(
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.selected, required this.multiple});

  final bool selected;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: Sizes.iconLg,
      height: Sizes.iconLg,
      decoration: BoxDecoration(
        color: selected ? p.action : p.surface,
        shape: multiple ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multiple ? Radii.xsAll : null,
        border: Border.all(
          color: selected ? p.action : p.borderStrong,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(LucideIcons.check, size: Sizes.iconSm, color: p.onAction)
          : null,
    );
  }
}
