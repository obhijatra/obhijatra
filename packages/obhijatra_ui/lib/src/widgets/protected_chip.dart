import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// A dark chip with a padlock that marks an answer only the organisation
/// can read.
///
/// Show it only where the answer really is protected. Field-level
/// encryption arrives in a later milestone; until then no screen shows it.
class ProtectedChip extends StatelessWidget {
  /// Creates the chip with the words [label].
  const ProtectedChip({required this.label, this.inline = false, super.key});

  /// The words, for example "Only your organisation can read this".
  final String label;

  /// A smaller chip for use inside a row of a list.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: p.textOnBrand);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minHeight: inline ? 0 : 32),
          padding: EdgeInsets.symmetric(
            horizontal: inline ? Spacing.space2 : Spacing.space3,
            vertical: inline ? 2 : Spacing.space1,
          ),
          decoration: BoxDecoration(
            color: p.surfaceBrand,
            borderRadius: Radii.smAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(LucideIcons.lock, size: Sizes.iconSm, color: p.textOnBrand),
              const SizedBox(width: Spacing.space2),
              Flexible(child: Text(label, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}
