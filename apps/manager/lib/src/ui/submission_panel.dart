import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/src/ui/review_note_dialog.dart';
import 'package:obhijatra_manager/widgets/answer_list.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_manager/widgets/review_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The details panel: answers parsed from the instance XML and the review
/// actions.
class SubmissionPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const SubmissionPanel({
    required this.row,
    required this.locationName,
    required this.canReview,
    required this.onClose,
    super.key,
  });

  /// The submission.
  final SubmissionRow row;

  /// The location's name, or empty.
  final String locationName;

  /// Whether the signed-in role may change the review state.
  final bool canReview;

  /// Closes the panel.
  final VoidCallback onClose;

  @override
  ConsumerState<SubmissionPanel> createState() => _SubmissionPanelState();
}

class _SubmissionPanelState extends ConsumerState<SubmissionPanel> {
  bool _busy = false;
  AppProblem? _problem;

  Future<void> _review(ReviewState state) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? note;
    if (state != ReviewState.approved) {
      note = await showReviewNoteDialog(context, state);
      if (note == null || !mounted) return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await trackedUi(
        ref,
        () => ref.read(apiProvider).setReview(widget.row, state, comment: note),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reviewSaved(reviewStateWord(l10n, state)))),
      );
      _refreshLists();
    } on AppProblem catch (problem) {
      // The state change itself may have been saved (a server that cannot
      // keep notes); show the lists as they are now either way.
      if (problem.kind == ProblemKind.commentNotSaved) _refreshLists();
      if (mounted) setState(() => _problem = problem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshLists() {
    ref
      ..invalidate(submissionsProvider)
      ..invalidate(submissionCountsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final row = widget.row;
    final lang = Localizations.localeOf(context).languageCode;
    final unknown = l10n.unknownValue;
    final meta = l10n.detailMeta(
      row.collector.isEmpty ? unknown : row.collector,
      widget.locationName.isEmpty ? unknown : widget.locationName,
      Format.when(context, row.receivedAt),
    );
    final answers = ref.watch(
      answersProvider(
        AnswersRequest(
          submissionId: row.id,
          versionId: row.formVersionId,
          formRecordId: row.formRecordId,
          lang: lang,
        ),
      ),
    );

    final hasNote =
        row.comment.isNotEmpty &&
        (row.state == ReviewState.hasIssues ||
            row.state == ReviewState.rejected);

    return Semantics(
      container: true,
      label: row.formTitle,
      child: ObPanel(
        strongBorder: true,
        padding: const EdgeInsets.fromLTRB(
          Spacing.space5,
          Spacing.space4,
          Spacing.space5,
          Spacing.space5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          row.formTitle.isEmpty ? unknown : row.formTitle,
                          style: text.titleLarge,
                        ),
                      ),
                      Text(
                        meta,
                        style: text.bodySmall!.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.detailClose,
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: Spacing.space3),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ReviewBadge(row.state),
                    ),
                    if (hasNote) ...<Widget>[
                      const SizedBox(height: Spacing.space3),
                      _NoteAlert(state: row.state, note: row.comment),
                    ],
                    const SizedBox(height: Spacing.space3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.info_outline,
                            size: Sizes.iconSm,
                            color: palette.textMuted,
                          ),
                        ),
                        const SizedBox(width: Spacing.space2),
                        Expanded(
                          child: Text(
                            l10n.detailProtectedNote,
                            style: text.bodySmall!.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.space3),
                    Semantics(
                      header: true,
                      child: Text(l10n.detailAnswers, style: text.titleSmall),
                    ),
                    answers.when(
                      loading: () => const SizedBox(
                        height: 120,
                        child: LoadingBlock(compact: true),
                      ),
                      error: (error, _) {
                        final problem = problemFrom(error);
                        return ProblemView(
                          compact: true,
                          problem: problem,
                          onAction: () {
                            if (problem.action == ProblemAction.signInAgain) {
                              ref.read(sessionProvider.notifier).signOut();
                            } else {
                              ref.invalidate(answersProvider);
                              ref.invalidate(formsProvider);
                            }
                          },
                        );
                      },
                      data: (list) => AnswerList(answers: list),
                    ),
                  ],
                ),
              ),
            ),
            if (_problem != null) ...<Widget>[
              const SizedBox(height: Spacing.space3),
              ProblemBanner(
                problem: _problem!,
                onAction: () => setState(() => _problem = null),
              ),
            ],
            const SizedBox(height: Spacing.space3),
            if (!widget.canReview)
              Text(
                l10n.reviewReadOnly,
                style: text.bodySmall!.copyWith(color: palette.textMuted),
              )
            else
              Wrap(
                spacing: Spacing.space2,
                runSpacing: Spacing.space2,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _busy || row.state == ReviewState.approved
                        ? null
                        : () => _review(ReviewState.approved),
                    icon: const Icon(Icons.check),
                    label: Text(_busy ? l10n.reviewSaving : l10n.actionApprove),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || row.state == ReviewState.hasIssues
                        ? null
                        : () => _review(ReviewState.hasIssues),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: Text(l10n.actionHasIssues),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || row.state == ReviewState.rejected
                        ? null
                        : () => _review(ReviewState.rejected),
                    icon: const Icon(Icons.close),
                    label: Text(l10n.actionReject),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteAlert extends StatelessWidget {
  const _NoteAlert({required this.state, required this.note});

  final ReviewState state;
  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final tone = reviewStateTone(state);
    return Container(
      padding: const EdgeInsets.all(Spacing.space3),
      decoration: BoxDecoration(
        color: tone.background(palette),
        borderRadius: Radii.smAll,
        border: Border.all(color: tone.foreground(palette)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            reviewStateIcon(state),
            size: Sizes.icon,
            color: tone.foreground(palette),
          ),
          const SizedBox(width: Spacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.detailComment,
                  style: text.labelLarge!.copyWith(
                    color: tone.foreground(palette),
                  ),
                ),
                Text(note, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
