import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';
import 'package:obhijatra_ui/src/widgets/question_frame.dart';

/// A question answered with a calendar date.
///
/// Shows a large button with the chosen date (already written in the
/// person's language by the caller in [valueText]); pressing it opens the
/// calendar.
class QuestionDate extends StatelessWidget {
  /// Creates the question.
  const QuestionDate({
    required this.label,
    required this.valueText,
    required this.pickLabel,
    required this.onChanged,
    this.value,
    this.firstDate,
    this.lastDate,
    this.number,
    this.requiredLabel,
    this.help,
    this.errorText,
    super.key,
  });

  /// The question.
  final String label;

  /// The chosen date, or `null`.
  final DateTime? value;

  /// The chosen date written for reading, for example "4 November 2026";
  /// `null` while no date is chosen.
  final String? valueText;

  /// What the button says before a date is chosen, for example "Choose a date".
  final String pickLabel;

  /// The earliest date the calendar offers.
  final DateTime? firstDate;

  /// The latest date the calendar offers.
  final DateTime? lastDate;

  /// Called with the date the person picks.
  final ValueChanged<DateTime> onChanged;

  /// The question number, for example "4.".
  final String? number;

  /// The "required" word, or `null` when optional.
  final String? requiredLabel;

  /// Help text.
  final String? help;

  /// Why the answer was not accepted.
  final String? errorText;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 100);
    final last = lastDate ?? DateTime(now.year + 5, 12, 31);
    var initial = value ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      // The calendar is a fixed grid: at the very largest text sizes it
      // would spill out of the dialog, so inside it text is capped at 1.15x
      // (still larger than normal). Everything else keeps the person's size.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.15),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme.bodyLarge!;
    final chosen = valueText != null;
    final shown = valueText ?? pickLabel;
    return QuestionFrame(
      label: label,
      number: number,
      requiredLabel: requiredLabel,
      help: help,
      errorText: errorText,
      child: Semantics(
        button: true,
        label: '$label: $shown',
        excludeSemantics: true,
        onTap: () => _pick(context),
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.smAll,
            side: BorderSide(
              color: errorText != null ? p.danger : p.borderStrong,
              width: errorText != null ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => _pick(context),
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
                    Icon(
                      LucideIcons.calendar,
                      size: Sizes.iconLg,
                      color: p.action,
                    ),
                    const SizedBox(width: Spacing.space3),
                    Expanded(
                      child: Text(
                        shown,
                        style: text.copyWith(
                          color: chosen ? p.text : p.textMuted,
                          fontWeight: chosen ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
