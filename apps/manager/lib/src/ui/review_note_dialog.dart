import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The longest review note.
const int maxReviewNote = 500;

/// Asks for the comment (has issues) or the reason (rejected). Returns the
/// text, or null when the person cancels.
Future<String?> showReviewNoteDialog(BuildContext context, ReviewState state) =>
    showDialog<String>(
      context: context,
      builder: (context) => ReviewNoteDialog(state: state),
    );

/// A small dialog with one required text box.
class ReviewNoteDialog extends StatefulWidget {
  /// Creates the dialog for [state] ([ReviewState.hasIssues] or
  /// [ReviewState.rejected]).
  const ReviewNoteDialog({required this.state, super.key});

  /// The decision being made.
  final ReviewState state;

  @override
  State<ReviewNoteDialog> createState() => _ReviewNoteDialogState();
}

class _ReviewNoteDialogState extends State<ReviewNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rejecting = widget.state == ReviewState.rejected;
    return AlertDialog(
      title: Text(rejecting ? l10n.reviewRejectTitle : l10n.reviewIssuesTitle),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: rejecting
                  ? l10n.reviewRejectLabel
                  : l10n.reviewIssuesLabel,
              helperText: l10n.reviewCommentHelp,
              helperMaxLines: 2,
              alignLabelWithHint: true,
            ),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return l10n.reviewCommentRequired;
              if (text.length > maxReviewNote) {
                return l10n.reviewCommentTooLong(maxReviewNote);
              }
              return null;
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: rejecting
              ? FilledButton.styleFrom(
                  backgroundColor: context.palette.danger,
                  foregroundColor: context.palette.onAction,
                )
              : null,
          onPressed: _confirm,
          child: Text(rejecting ? l10n.actionReject : l10n.reviewConfirmIssues),
        ),
      ],
    );
  }
}
