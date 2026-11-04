import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/screens/outcome_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// How the finish screen was left.
enum FinishExit {
  /// Back to the last question.
  back,

  /// To the question that needs fixing.
  fix,

  /// The form was kept as a draft and should close.
  draftKept,
}

/// The last screen of a form: a summary, what still needs fixing, and the
/// button that sends.
class FinishScreen extends ConsumerStatefulWidget {
  /// Creates the screen for the form [args].
  const FinishScreen({required this.args, super.key});

  /// The form being finished.
  final FormEntryArgs args;

  @override
  ConsumerState<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends ConsumerState<FinishScreen> {
  bool _sending = false;
  // The questions to fix, after Send found some; null before.
  List<FailedQuestion>? _failures;

  FormEntryController get _controller =>
      ref.read(formEntryProvider(widget.args).notifier);

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final result = await _controller.finish();
      if (!mounted) return;
      switch (result) {
        case FinishBlocked(:final failures):
          if (failures.isEmpty) {
            // The form already shows the question to fix.
            Navigator.of(context).pop(FinishExit.fix);
          } else {
            setState(() => _failures = failures);
          }
        case FinishQueued(:final instanceId):
          final outcome = await _syncAndJudge(instanceId);
          if (!mounted) return;
          final title = ref.read(formEntryProvider(widget.args)).value?.title;
          unawaited(
            Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (_) => OutcomeScreen(
                  outcome: outcome,
                  formTitle: title,
                  formId: widget.args.formId,
                ),
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Sends the form now, but never makes the person wait long: a slow
  /// connection counts as "waiting for signal" and sending goes on by itself.
  Future<SendOutcome> _syncAndJudge(String instanceId) async {
    final db = await ref.read(deviceDatabaseProvider.future);
    final engine = await ref.read(syncEngineProvider.future);
    if (engine != null) {
      await engine
          .syncNow(ignoreBackoff: true)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => const SyncReport(),
          );
    }
    final entry = await OutboxRepository(db).find(instanceId);
    final now = ref.read(nowProvider)();
    if (entry != null) {
      if (entry.state == OutboxState.sent) {
        return SendOutcome.sent(entry.sentAt?.toLocal() ?? now);
      }
      if (entry.state == OutboxState.problem) {
        return SendOutcome.problem(ProblemCode.fromName(entry.lastError));
      }
    }
    final blocked = engine?.status.blockedBy;
    if (blocked != null && blocked.blocksSync) {
      return SendOutcome.problem(blocked);
    }
    final counts = await OutboxRepository(db).watchCounts().first;
    return SendOutcome.waiting(counts.pending);
  }

  Future<void> _keepDraft() async {
    await _controller.saveNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).finishDraftKept)),
    );
    Navigator.of(context).pop(FinishExit.draftKept);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final state = ref.watch(formEntryProvider(widget.args)).value;
    final title = state?.title;

    final failures = _failures;
    ValidationSummary? summary;
    if (failures != null && failures.isNotEmpty) {
      summary = ValidationSummary(
        title: l.validationTitle(failures.length),
        message: l.validationMessage(failures.length),
        items: <ValidationSummaryItem>[
          for (final failure in failures)
            ValidationSummaryItem(
              label: l.validationItem(
                failure.question.label ?? '',
                _reason(l, failure.message),
              ),
              // Straight to that question, with its message showing.
              onTap: () {
                _controller.jumpTo(failure.question.key);
                Navigator.of(context).pop(FinishExit.fix);
              },
            ),
        ],
      );
    }

    return ScreenFrame(
      topBar: TopBar(
        title: l.finishTitle,
        subtitle: title,
        leadingIcon: LucideIcons.arrowLeft,
        leadingLabel: l.finishBackToQuestions,
        onLeading: () => Navigator.of(context).pop(FinishExit.back),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          if (summary != null) ...<Widget>[
            summary,
            const SizedBox(height: Spacing.space4),
          ] else ...<Widget>[
            Text(l.summaryReady, style: text.bodyLarge),
            const SizedBox(height: Spacing.space4),
          ],
          if (state != null)
            Panel(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.space4,
                vertical: Spacing.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(l.summaryTitle, style: text.titleMedium),
                  ),
                  const SizedBox(height: Spacing.space2),
                  _Row(
                    label: l.summaryAnswered,
                    value: l.summaryAnsweredValue(
                      state.answered,
                      state.answerable,
                    ),
                  ),
                  Divider(color: p.border),
                  _Row(
                    label: l.summaryStarted,
                    value: fmt.when(
                      state.startedAt,
                      bangla: bangla,
                      now: ref.watch(nowProvider)(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottom: BottomActions(
        children: <Widget>[
          PrimaryButton(
            label: _sending ? l.finishSending : l.finishSend,
            icon: LucideIcons.send,
            busy: _sending,
            onPressed: _send,
          ),
          PrimaryButton(
            label: l.finishKeepDraft,
            variant: PrimaryButtonVariant.ghost,
            onPressed: _sending ? null : _keepDraft,
          ),
        ],
      ),
    );
  }
}

/// Why a question failed, in plain words: the form's own message when it
/// has one.
String _reason(AppLocalizations l, ValidationMessage message) {
  final own = message.formMessage?.trim();
  if (own != null && own.isNotEmpty) return own;
  return switch (message.issue) {
    ValidationIssue.required => l.issueRequired,
    ValidationIssue.constraint => l.issueConstraint,
    ValidationIssue.invalidValue => l.issueInvalidText,
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.space1),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: Spacing.space3,
          children: <Widget>[
            Text(label, style: text.bodyMedium!.copyWith(color: p.textMuted)),
            Text(
              value,
              style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
