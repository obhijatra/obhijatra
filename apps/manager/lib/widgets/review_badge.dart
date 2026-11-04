import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';

/// The localised word for a review state.
String reviewStateWord(AppLocalizations l10n, ReviewState state) =>
    switch (state) {
      ReviewState.received => l10n.stateReceived,
      ReviewState.edited => l10n.stateEdited,
      ReviewState.hasIssues => l10n.stateHasIssues,
      ReviewState.approved => l10n.stateApproved,
      ReviewState.rejected => l10n.stateRejected,
    };

/// The colour role of a review state.
Tone reviewStateTone(ReviewState state) => switch (state) {
  ReviewState.received || ReviewState.edited => Tone.info,
  ReviewState.hasIssues => Tone.warning,
  ReviewState.approved => Tone.success,
  ReviewState.rejected => Tone.danger,
};

/// The icon of a review state.
IconData reviewStateIcon(ReviewState state) => switch (state) {
  ReviewState.received => Icons.inbox_outlined,
  ReviewState.edited => Icons.edit_outlined,
  ReviewState.hasIssues => Icons.warning_amber_rounded,
  ReviewState.approved => Icons.check_rounded,
  ReviewState.rejected => Icons.close_rounded,
};

/// A review state as a badge: a word, a colour and an icon.
class ReviewBadge extends StatelessWidget {
  /// Creates the badge for [state].
  const ReviewBadge(this.state, {super.key});

  /// The state to show.
  final ReviewState state;

  @override
  Widget build(BuildContext context) => ObBadge(
    label: reviewStateWord(AppLocalizations.of(context), state),
    tone: reviewStateTone(state),
    icon: reviewStateIcon(state),
  );
}
