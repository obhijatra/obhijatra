import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/screens/finish_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Fills in one form, one question per screen.
///
/// Every answer is saved on the phone as it is given; closing the form keeps
/// it as a draft.
class FormEntryScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [args].
  const FormEntryScreen({required this.args, super.key});

  /// Which form (or draft) to fill.
  final FormEntryArgs args;

  @override
  ConsumerState<FormEntryScreen> createState() => _FormEntryScreenState();
}

class _FormEntryScreenState extends ConsumerState<FormEntryScreen> {
  final ScrollController _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  FormEntryController get _controller =>
      ref.read(formEntryProvider(widget.args).notifier);

  Future<void> _close() async {
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    try {
      await _controller.saveNow();
    } on Object {
      // Closing must always work; the last debounced save also runs on exit.
    }
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _next() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final moved = await _controller.next();
      if (!mounted) return;
      if (!moved) {
        if (_scroll.hasClients) {
          unawaited(
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
          );
        }
        return;
      }
      if (ref.read(formEntryProvider(widget.args)).value?.screen
          is EndOfFormScreen) {
        await _openFinish();
      } else if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFinish() async {
    final result = await Navigator.of(context).push<FinishExit>(
      MaterialPageRoute<FinishExit>(
        builder: (_) => FinishScreen(args: widget.args),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case FinishExit.fix:
        if (_scroll.hasClients) _scroll.jumpTo(0);
      case FinishExit.draftKept:
        Navigator.of(context).pop();
      case FinishExit.back || null:
        final s = ref.read(formEntryProvider(widget.args)).value;
        if (s?.screen is EndOfFormScreen) await _controller.back();
    }
  }

  Future<void> _back() async {
    FocusScope.of(context).unfocus();
    await _controller.back();
    if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(formEntryProvider(widget.args));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: switch (async) {
        AsyncData(:final value) => _buildForm(context, l, value),
        AsyncError(:final error) => _buildError(context, l, error),
        _ => ScreenFrame(
          topBar: TopBar(
            title: l.appTitle,
            leadingIcon: LucideIcons.x,
            leadingLabel: l.closeForm,
            onLeading: () => Navigator.of(context).maybePop(),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l, Object error) {
    final p = context.palette;
    final message = error is FormNotOnPhone
        ? l.formNotOnPhone
        : problemText(l, problemOf(error));
    return ScreenFrame(
      topBar: TopBar(
        title: l.appTitle,
        leadingIcon: LucideIcons.x,
        leadingLabel: l.actionClose,
        onLeading: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          const SizedBox(height: Spacing.space8),
          ResultHeader(
            icon: LucideIcons.triangleAlert,
            iconColor: p.warning,
            iconBackground: p.warningSubtle,
            title: l.formOpenFailedTitle,
          ),
          const SizedBox(height: Spacing.space4),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
      bottom: BottomActions(
        children: <Widget>[
          PrimaryButton(
            label: l.entryBackToToday,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l,
    FormEntryState state,
  ) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final screen = state.screen;
    final progressLabel = l.questionProgress(state.step, state.total);
    final value = state.total == 0
        ? 0.0
        : (state.step / state.total).clamp(0.0, 1.0);

    final children = <Widget>[];
    switch (screen) {
      case QuestionScreen(:final questions, :final groupLabel):
        if (groupLabel != null && groupLabel.isNotEmpty) {
          children.add(
            Text(
              groupLabel,
              style: text.labelLarge!.copyWith(color: p.textMuted),
            ),
          );
          children.add(const SizedBox(height: Spacing.space3));
        }
        for (var i = 0; i < questions.length; i++) {
          if (i > 0) children.add(const SizedBox(height: Spacing.space8));
          children.add(
            _QuestionView(
              key: ValueKey<String>('q-${questions[i].key}'),
              question: questions[i],
              number: fmt.digits(state.step + i, bangla: bangla),
              message: state.errors[questions[i].key],
              args: widget.args,
              bangla: bangla,
            ),
          );
        }
      case RepeatPromptScreen(:final repeatLabel):
        children.add(
          Semantics(
            header: true,
            child: Text(
              repeatLabel == null || repeatLabel.isEmpty
                  ? l.repeatPromptTitleNoLabel
                  : l.repeatPromptTitle(repeatLabel),
              style: text.headlineMedium,
            ),
          ),
        );
      case EndOfFormScreen():
        children.add(
          Semantics(
            header: true,
            child: Text(l.finishTitle, style: text.headlineMedium),
          ),
        );
    }

    final List<Widget> actions;
    if (screen is RepeatPromptScreen) {
      actions = <Widget>[
        PrimaryButton(
          label: l.repeatAdd,
          icon: LucideIcons.plus,
          onPressed: () => _controller.addRepeat(),
        ),
        PrimaryButton(
          label: l.repeatNoMore,
          variant: PrimaryButtonVariant.secondary,
          onPressed: _busy ? null : _next,
        ),
      ];
    } else {
      actions = <Widget>[
        PrimaryButton(
          label: l.entryBack,
          icon: LucideIcons.chevronLeft,
          variant: PrimaryButtonVariant.secondary,
          onPressed: state.canGoBack && !_busy ? _back : null,
        ),
        PrimaryButton(
          label: screen is EndOfFormScreen ? l.entryFinish : l.entryNext,
          trailingIcon: LucideIcons.chevronRight,
          busy: _busy,
          onPressed: _next,
        ),
      ];
    }

    return ScreenFrame(
      topBar: TopBar(
        title: state.title ?? l.appTitle,
        leadingIcon: LucideIcons.x,
        leadingLabel: l.closeForm,
        onLeading: () => unawaited(_close()),
      ),
      // The progress line scrolls with the question: at the largest text
      // sizes only the top bar and the buttons stay pinned, so most of the
      // screen is left for the question.
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          Spacing.space4,
          Spacing.space3,
          Spacing.space4,
          Spacing.space6,
        ),
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.space3,
            runSpacing: Spacing.space1,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  progressLabel,
                  style: text.titleSmall!.copyWith(
                    fontSize: text.bodyMedium!.fontSize,
                  ),
                ),
              ),
              if (state.savedAt != null) _SavedBadge(label: l.savedBadge),
            ],
          ),
          const SizedBox(height: Spacing.space2),
          Semantics(
            label: progressLabel,
            value: '${(value * 100).round()}%',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: Radii.pillAll,
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: p.surfaceSunken,
                color: p.action,
              ),
            ),
          ),
          const SizedBox(height: Spacing.space5),
          ...children,
        ],
      ),
      bottom: BottomActions(row: true, children: actions),
    );
  }
}

class _SavedBadge extends StatelessWidget {
  const _SavedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(LucideIcons.check, size: Sizes.iconSm, color: p.success),
            const SizedBox(width: Spacing.space1),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge!
                    .copyWith(color: p.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({
    required this.question,
    required this.number,
    required this.message,
    required this.args,
    required this.bangla,
    super.key,
  });

  final Question question;
  final String number;
  final ValidationMessage? message;
  final FormEntryArgs args;
  final bool bangla;

  String? _errorText(AppLocalizations l) {
    final m = message;
    if (m == null) return null;
    if (m.formMessage != null && m.formMessage!.trim().isNotEmpty) {
      return m.formMessage;
    }
    return switch (m.issue) {
      ValidationIssue.required => l.issueRequired,
      ValidationIssue.constraint => l.issueConstraint,
      ValidationIssue.invalidValue => switch (question.kind) {
        QuestionKind.integer => l.issueInvalidInteger,
        QuestionKind.decimal => l.issueInvalidDecimal,
        QuestionKind.date => l.issueInvalidDate,
        QuestionKind.selectOne ||
        QuestionKind.selectMultiple => l.issueInvalidChoice,
        _ => l.issueInvalidText,
      },
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = ref.read(formEntryProvider(args).notifier);
    final q = question;
    final label = q.label ?? '';
    final error = _errorText(l);
    final requiredLabel = q.isRequired ? l.requiredMark : null;
    final numeric =
        q.kind == QuestionKind.integer || q.kind == QuestionKind.decimal;

    switch (q.kind) {
      case QuestionKind.selectOne:
        return QuestionChoice(
          label: label,
          number: '$number.',
          requiredLabel: requiredLabel,
          help: q.hint ?? l.helpChooseOne,
          errorText: error,
          options: <ChoiceOption>[
            for (final c in q.choices) ChoiceOption(c.value, c.label),
          ],
          selected: q.value == null ? const <String>{} : <String>{q.value!},
          onChanged: (values) => controller.answer(q, values.firstOrNull),
        );
      case QuestionKind.selectMultiple:
        return QuestionChoice(
          label: label,
          number: '$number.',
          multiple: true,
          requiredLabel: requiredLabel,
          help: q.hint ?? l.helpChooseMany,
          errorText: error,
          options: <ChoiceOption>[
            for (final c in q.choices) ChoiceOption(c.value, c.label),
          ],
          selected: (q.value ?? '')
              .split(' ')
              .where((v) => v.isNotEmpty)
              .toSet(),
          onChanged: (values) => controller.answer(
            q,
            values.isEmpty
                ? null
                : <String>[
                    for (final c in q.choices)
                      if (values.contains(c.value)) c.value,
                  ].join(' '),
          ),
        );
      case QuestionKind.text || QuestionKind.integer || QuestionKind.decimal:
        return QuestionText(
          label: label,
          number: '$number.',
          kind: switch (q.kind) {
            QuestionKind.integer => QuestionTextKind.integer,
            QuestionKind.decimal => QuestionTextKind.decimal,
            _ => QuestionTextKind.text,
          },
          requiredLabel: requiredLabel,
          help: q.hint,
          errorText: error,
          value: numeric && bangla && q.value != null
              ? fmt.toBanglaDigits(q.value!)
              : q.value,
          onChanged: (text) => controller.answer(q, text),
        );
      case QuestionKind.date:
        final date = q.value == null ? null : DateTime.tryParse(q.value!);
        return QuestionDate(
          label: label,
          number: '$number.',
          requiredLabel: requiredLabel,
          help: q.hint,
          errorText: error,
          pickLabel: l.pickDate,
          value: date,
          valueText: date == null ? null : fmt.shortDate(date, bangla: bangla),
          onChanged: (d) => controller.answer(
            q,
            '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
          ),
        );
      case QuestionKind.note:
        return _NoteCard(label: label, hint: q.hint);
      case QuestionKind.time ||
          QuestionKind.dateTime ||
          QuestionKind.location ||
          QuestionKind.media ||
          QuestionKind.barcode ||
          QuestionKind.acknowledge ||
          QuestionKind.other:
        return _UnsupportedCard(
          label: label,
          requiredLabel: requiredLabel,
          isRequired: q.isRequired,
          error: error,
        );
    }
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.label, this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Panel(
      color: p.infoSubtle,
      borderColor: p.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: text.bodyLarge),
          if (hint != null) ...<Widget>[
            const SizedBox(height: Spacing.space2),
            Text(hint!, style: text.bodySmall!.copyWith(color: p.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _UnsupportedCard extends StatelessWidget {
  const _UnsupportedCard({
    required this.label,
    required this.requiredLabel,
    required this.isRequired,
    required this.error,
  });

  final String label;
  final String? requiredLabel;
  final bool isRequired;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Panel(
        color: p.warningSubtle,
        borderColor: p.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.space1),
                  child: Icon(
                    LucideIcons.triangleAlert,
                    size: Sizes.icon,
                    color: p.warning,
                  ),
                ),
                const SizedBox(width: Spacing.space2),
                Expanded(
                  child: Text(l.unsupportedTitle, style: text.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: Spacing.space3),
            Text(
              requiredLabel == null ? label : '$label  $requiredLabel',
              style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Spacing.space2),
            Text(
              isRequired ? l.unsupportedRequiredBody : l.unsupportedBody,
              style: text.bodyMedium,
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: Spacing.space2),
              Text(
                error!,
                style: text.bodyMedium!.copyWith(
                  color: p.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
