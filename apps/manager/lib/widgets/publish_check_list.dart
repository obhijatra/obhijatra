import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/xform/publish_checks.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The one-sentence summary above the checks.
String publishSummary(BuildContext context, PublishReport report) {
  final l10n = AppLocalizations.of(context);
  final parts = <String>[
    if (report.questionCount > 0 || report.problemCount == 0)
      l10n.publishCheckedQuestions(report.questionCount),
    if (report.problemCount > 0)
      l10n.publishFixCount(report.problemCount)
    else
      l10n.publishAllClear,
  ];
  return parts.join(' ');
}

String _kindLabel(AppLocalizations l10n, CheckKind kind) => switch (kind) {
  CheckKind.problem => l10n.checkKindFix,
  CheckKind.protectedAnswers => l10n.checkKindProtected,
  CheckKind.passed => l10n.checkKindPassed,
  CheckKind.note => l10n.checkKindNote,
};

Tone _tone(CheckKind kind) => switch (kind) {
  CheckKind.problem => Tone.danger,
  CheckKind.protectedAnswers || CheckKind.passed => Tone.success,
  CheckKind.note => Tone.info,
};

IconData _icon(CheckKind kind) => switch (kind) {
  CheckKind.problem => Icons.cancel_outlined,
  CheckKind.protectedAnswers => Icons.verified_user_outlined,
  CheckKind.passed => Icons.check_circle_outline,
  CheckKind.note => Icons.info_outline,
};

String _text(AppLocalizations l10n, PublishCheck check) {
  final names = check.items.join(', ');
  return switch (check.code) {
    CheckCode.unreadable => l10n.checkUnreadable,
    CheckCode.notXForm => l10n.checkNotXForm,
    CheckCode.wellFormed => l10n.checkWellFormed,
    CheckCode.versionMissing => l10n.checkVersionMissing,
    CheckCode.versionOk => l10n.checkVersionOk(check.value),
    CheckCode.formIdMissing => l10n.checkFormIdMissing,
    CheckCode.formIdOk => l10n.checkFormIdOk(check.value),
    CheckCode.versionExists => l10n.checkVersionExists(check.value),
    CheckCode.koboMatrix => l10n.checkKoboMatrix,
    CheckCode.koboScore => l10n.checkKoboScore,
    CheckCode.koboRank => l10n.checkKoboRank,
    CheckCode.protectedList => l10n.checkProtectedList(check.count, names),
    CheckCode.languagesOk => l10n.checkLanguagesOk,
    CheckCode.languagesPartial => l10n.checkLanguagesPartial(check.count),
    CheckCode.singleLanguage => l10n.checkSingleLanguage,
  };
}

/// The publish checks, each as a coloured line with a word, an icon and a
/// plain sentence.
class PublishCheckList extends StatelessWidget {
  /// Creates the list.
  const PublishCheckList({
    required this.report,
    this.horizontalPadding = 0,
    super.key,
  });

  /// What to show.
  final PublishReport report;

  /// Space at each side, so the dividers can run edge to edge.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        for (final check in report.checks)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: Spacing.space3,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _icon(check.kind),
                    size: Sizes.iconLg,
                    color: _tone(check.kind).foreground(palette),
                  ),
                ),
                const SizedBox(width: Spacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _kindLabel(l10n, check.kind),
                        style: text.labelLarge!.copyWith(
                          color: _tone(check.kind).foreground(palette),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(_text(l10n, check), style: text.bodyMedium),
                      if (check.code == CheckCode.koboMatrix ||
                          check.code == CheckCode.koboScore ||
                          check.code == CheckCode.koboRank)
                        Text(
                          l10n.checkWhere(check.count, check.items.join(', ')),
                          style: text.bodySmall!.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
