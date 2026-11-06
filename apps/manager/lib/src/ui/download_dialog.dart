import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_device/obhijatra_device.dart' show normaliseCheckCode;
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/export.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/files/download_saver.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/state/url_opener.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/widgets/notice_box.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_manager/widgets/review_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

// Downloading a form's submissions (docs/decisions/0009-data-export.md).

/// Opens the download dialog, starting from the Submissions screen's
/// [query]: its form, days and review state.
Future<void> showDownloadDialog(
  BuildContext context, {
  required SubmissionQuery query,
}) => showDialog<void>(
  context: context,
  builder: (context) => DownloadDialog(query: query),
);

enum _Step { choose, working, confirm, done }

/// Chooses what to download, downloads it with its progress, asks the
/// person to confirm it is them when their sign-in is too old (then tries
/// once more), and says where the file went.
class DownloadDialog extends ConsumerStatefulWidget {
  /// Creates the dialog, starting from [query].
  const DownloadDialog({required this.query, super.key});

  /// The Submissions screen's filter when the dialog opened.
  final SubmissionQuery query;

  @override
  ConsumerState<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<DownloadDialog> {
  _Step _step = _Step.choose;
  String? _formRecordId;
  DateTime? _firstDay;
  DateTime? _lastDay;
  late Set<ReviewState> _states;
  bool _media = true;

  /// Why the choices cannot be downloaded, by part.
  String? _formError;
  String? _daysError;
  String? _statesError;

  /// What went wrong with the last try.
  AppProblem? _problem;

  /// The download waiting for "Confirm it's you", and where it goes.
  SubmissionExport? _pending;
  DownloadTarget? _target;

  /// Whether the download was already tried again after a confirmation.
  bool _retried = false;

  /// Who opened the dialog.
  String? _userId;

  int _received = 0;
  bool _flowing = false;
  Completer<void>? _stop;
  String _savedName = '';

  @override
  void initState() {
    super.initState();
    final query = widget.query;
    _formRecordId = query.formRecordId;
    _firstDay = query.from;
    _lastDay = query.to?.subtract(const Duration(days: 1));
    _states = query.state == null
        ? <ReviewState>{...ReviewState.values}
        : <ReviewState>{query.state!};
    _userId = ref.read(sessionProvider)?.id;
  }

  @override
  void dispose() {
    // A download chosen but never finished leaves no empty file behind.
    final target = _target;
    if (target != null) unawaited(target.discard());
    final stop = _stop;
    if (stop != null && !stop.isCompleted) stop.complete();
    super.dispose();
  }

  // ------------------------------------------------------------ actions

  Future<void> _download(List<FormSummary> forms) async {
    final l10n = AppLocalizations.of(context);
    final form = forms.where((f) => f.id == _formRecordId).firstOrNull;
    final first = _firstDay;
    final last = _lastDay;
    setState(() {
      _problem = null;
      _formError = form == null ? l10n.downloadChooseForm : null;
      _daysError = first != null && last != null && last.isBefore(first)
          ? l10n.downloadDaysWrong
          : null;
      _statesError = _states.isEmpty ? l10n.downloadStatesNone : null;
    });
    if (form == null || _daysError != null || _statesError != null) return;

    final export = SubmissionExport(
      formRecordId: form.id,
      formId: form.formId,
      firstDay: first,
      lastDay: last,
      reviewStates: _states,
      includeMedia: _media,
    );
    final DownloadTarget? target;
    try {
      target = await ref
          .read(downloadSaverProvider)
          .choose(suggestedExportName(form.formId, DateTime.now()));
    } on AppProblem catch (problem) {
      if (mounted) setState(() => _problem = problem);
      return;
    }
    if (target == null) return; // The person cancelled the Save dialog.
    if (!mounted) {
      unawaited(target.discard());
      return;
    }
    _retried = false;
    await _run(export, target);
  }

  Future<void> _run(SubmissionExport export, DownloadTarget target) async {
    final stop = Completer<void>();
    setState(() {
      _step = _Step.working;
      _problem = null;
      _received = 0;
      _flowing = false;
      _stop = stop;
      _target = target;
    });
    final api = ref.read(apiProvider);
    try {
      final serverName = await trackedUi(
        ref,
        () => api.downloadSubmissions(
          export,
          stop: stop.future,
          onChunk: (chunk) async {
            await target.add(chunk);
            if (mounted) {
              setState(() {
                _flowing = true;
                _received += chunk.length;
              });
            }
          },
        ),
      );
      final name = await target.finish(serverName: serverName);
      _target = null;
      if (mounted) {
        setState(() {
          _step = _Step.done;
          _savedName = name;
        });
      }
    } on DownloadStopped {
      await _discard();
      if (mounted) setState(() => _step = _Step.choose);
    } on AppProblem catch (problem) {
      if (problem.kind == ProblemKind.recentSignInRequired && !_retried) {
        // Nothing has been written yet: the same file is used after the
        // person has confirmed it is them.
        if (mounted) {
          setState(() {
            _pending = export;
            _step = _Step.confirm;
          });
        }
        return;
      }
      await _discard();
      if (mounted) {
        setState(() {
          _step = _Step.choose;
          _problem = problem;
        });
      }
    } finally {
      if (identical(_stop, stop)) _stop = null;
    }
  }

  Future<void> _discard() async {
    final target = _target;
    _target = null;
    if (target != null) await target.discard();
  }

  /// After "Confirm it's you": tries the same download once more, unless
  /// someone else signed in (another Google account).
  void _confirmed(StaffUser user) {
    final export = _pending;
    final target = _target;
    _pending = null;
    if (user.id != _userId || export == null || target == null) {
      Navigator.of(context).pop();
      return;
    }
    _retried = true;
    unawaited(_run(export, target));
  }

  void _onProblem(AppProblem problem, List<FormSummary> forms) {
    switch (problem.action) {
      case ProblemAction.signInAgain:
        Navigator.of(context).pop();
        ref.read(sessionProvider.notifier).signOut();
      case ProblemAction.tryAgain:
        unawaited(_download(forms));
      case ProblemAction.reload ||
          ProblemAction.close ||
          ProblemAction.chooseFile:
        setState(() => _problem = null);
    }
  }

  Future<void> _pickDay({required bool first}) async {
    final today = DateTime.now();
    final current = first ? _firstDay : _lastDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(today.year - 10),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (first) {
        _firstDay = picked;
      } else {
        _lastDay = picked;
      }
      _daysError = null;
    });
  }

  // -------------------------------------------------------------- views

  @override
  Widget build(BuildContext context) {
    final forms =
        ref.watch(formsProvider).asData?.value ?? const <FormSummary>[];
    // A single form needs no choosing.
    if (_formRecordId == null && forms.length == 1) {
      _formRecordId = forms.single.id;
    }
    return PopScope(
      // While the file arrives, "Stop" ends it; it is not closed by mistake.
      canPop: _step != _Step.working,
      child: switch (_step) {
        _Step.choose => _choose(context, forms),
        _Step.working => _working(context),
        _Step.confirm => _confirm(context),
        _Step.done => _done(context),
      },
    );
  }

  Widget _choose(BuildContext context, List<FormSummary> forms) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);
    final error = text.bodySmall!.copyWith(color: palette.danger);
    final inMemory = ref.watch(downloadSaverProvider).holdsInMemory;
    return AlertDialog(
      key: const ValueKey<String>('download-dialog'),
      title: Text(l10n.downloadTitle),
      scrollable: true,
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.downloadIntro, style: text.bodyMedium),
            const SizedBox(height: Spacing.space4),
            if (forms.isEmpty)
              NoticeBox(message: l10n.downloadNoForms, tone: Tone.info)
            else
              DropdownMenu<String>(
                key: const ValueKey<String>('download-form'),
                label: Text(l10n.filterForm),
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: false,
                initialSelection: _formRecordId,
                errorText: _formError,
                onSelected: (value) => setState(() {
                  _formRecordId = value;
                  _formError = null;
                }),
                dropdownMenuEntries: <DropdownMenuEntry<String>>[
                  for (final form in forms)
                    DropdownMenuEntry<String>(
                      value: form.id,
                      label: form.displayTitle,
                    ),
                ],
              ),
            const SizedBox(height: Spacing.space4),
            Wrap(
              spacing: Spacing.space3,
              runSpacing: Spacing.space3,
              children: <Widget>[
                _DayField(
                  key: const ValueKey<String>('download-first-day'),
                  label: l10n.downloadFirstDay,
                  day: _firstDay,
                  onPick: () => unawaited(_pickDay(first: true)),
                  onClear: () => setState(() => _firstDay = null),
                ),
                _DayField(
                  key: const ValueKey<String>('download-last-day'),
                  label: l10n.downloadLastDay,
                  day: _lastDay,
                  onPick: () => unawaited(_pickDay(first: false)),
                  onClear: () => setState(() => _lastDay = null),
                ),
              ],
            ),
            const SizedBox(height: Spacing.space2),
            Text(l10n.downloadDaysHelp, style: muted),
            if (_daysError case final String message)
              Text(message, style: error),
            const SizedBox(height: Spacing.space4),
            Semantics(
              header: true,
              child: Text(l10n.downloadStates, style: text.titleSmall),
            ),
            const SizedBox(height: Spacing.space2),
            Wrap(
              spacing: Spacing.space2,
              runSpacing: Spacing.space2,
              children: <Widget>[
                for (final state in ReviewState.values)
                  FilterChip(
                    key: ValueKey<String>('download-state-${state.wire}'),
                    label: Text(reviewStateWord(l10n, state)),
                    selected: _states.contains(state),
                    onSelected: (on) => setState(() {
                      _states = <ReviewState>{..._states};
                      if (on) {
                        _states.add(state);
                      } else {
                        _states.remove(state);
                      }
                      _statesError = null;
                    }),
                  ),
              ],
            ),
            if (_statesError case final String message)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: Text(message, style: error),
              ),
            const SizedBox(height: Spacing.space3),
            SwitchListTile(
              key: const ValueKey<String>('download-media'),
              contentPadding: EdgeInsets.zero,
              value: _media,
              onChanged: (on) => setState(() => _media = on),
              title: Text(l10n.downloadMedia),
              subtitle: Text(l10n.downloadMediaNote),
            ),
            const SizedBox(height: Spacing.space3),
            NoticeBox(message: l10n.downloadPersonalData, tone: Tone.warning),
            if (inMemory) ...<Widget>[
              const SizedBox(height: Spacing.space3),
              NoticeBox(message: l10n.downloadBrowserMemory, tone: Tone.info),
            ],
            if (_problem case final AppProblem problem) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              ProblemBanner(
                problem: problem,
                onAction: () => _onProblem(problem, forms),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton.icon(
          key: const ValueKey<String>('download-start'),
          onPressed: forms.isEmpty ? null : () => unawaited(_download(forms)),
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.actionDownload),
        ),
      ],
    );
  }

  Widget _working(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const ValueKey<String>('download-working'),
      title: Text(l10n.downloadTitle),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const LinearProgressIndicator(),
            const SizedBox(height: Spacing.space3),
            Semantics(
              liveRegion: !_flowing,
              child: Text(
                _flowing
                    ? l10n.downloadReceived(Format.bytes(context, _received))
                    : l10n.downloadPreparing,
                key: const ValueKey<String>('download-progress'),
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('download-stop'),
          onPressed: () {
            final stop = _stop;
            if (stop != null && !stop.isCompleted) stop.complete();
          },
          child: Text(l10n.actionStop),
        ),
      ],
    );
  }

  Widget _confirm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey<String>('download-confirm'),
      title: Text(l10n.confirmTitle),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: ConfirmSignIn(onConfirmed: _confirmed),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final inMemory = ref.watch(downloadSaverProvider).holdsInMemory;
    return AlertDialog(
      key: const ValueKey<String>('download-done'),
      icon: Icon(Icons.download_done, color: palette.success),
      title: Semantics(liveRegion: true, child: Text(l10n.downloadDoneTitle)),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              inMemory
                  ? l10n.downloadSavedBrowser(_savedName)
                  : l10n.downloadSaved(_savedName),
              style: text.bodyMedium,
            ),
            const SizedBox(height: Spacing.space3),
            Text(l10n.downloadDoneReminder, style: text.bodyMedium),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          key: const ValueKey<String>('download-close'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionDone),
        ),
      ],
    );
  }
}

/// A day, or "Any day", that opens a calendar; with a button that clears
/// it.
class _DayField extends StatelessWidget {
  const _DayField({
    required this.label,
    required this.day,
    required this.onPick,
    required this.onClear,
    super.key,
  });

  final String label;
  final DateTime? day;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final chosen = day;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: '$label: ', style: text.labelLarge),
                  TextSpan(
                    text: chosen == null
                        ? l10n.downloadAnyDay
                        : Format.day(context, chosen),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (chosen != null)
          IconButton(
            tooltip: l10n.downloadClearDay,
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// "Confirm it's you": signs the person in again (password, Google or an
/// SMS code, as their account and the server allow), then calls
/// [onConfirmed] with whoever is signed in now. Nothing keeps the password.
class ConfirmSignIn extends ConsumerStatefulWidget {
  /// Creates the step.
  const ConfirmSignIn({required this.onConfirmed, super.key});

  /// Called once the person has signed in again.
  final ValueChanged<StaffUser> onConfirmed;

  @override
  ConsumerState<ConfirmSignIn> createState() => _ConfirmSignInState();
}

class _ConfirmSignInState extends ConsumerState<ConfirmSignIn> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  AppProblem? _problem;
  String? _fieldError;
  PhoneCodeRequest? _codeSent;
  Completer<void>? _googleCancel;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    final cancel = _googleCancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    super.dispose();
  }

  /// Runs [confirm]; on success the typed secrets are wiped and
  /// [ConfirmSignIn.onConfirmed] is called.
  Future<void> _attempt(Future<StaffUser?> Function() confirm) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
      _fieldError = null;
    });
    try {
      final user = await confirm();
      _password.clear();
      _code.clear();
      if (user != null && mounted) widget.onConfirmed(user);
    } on AppProblem catch (problem) {
      if (mounted) setState(() => _problem = problem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmPassword() {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _fieldError = AppLocalizations.of(context).fieldRequired);
      return;
    }
    unawaited(
      _attempt(
        () => ref.read(sessionProvider.notifier).confirmWithPassword(password),
      ),
    );
  }

  Future<void> _sendCode(String phone) => _attempt(() async {
    final sent = await trackedUi(
      ref,
      () => ref.read(apiProvider).requestPhoneCode(phone),
    );
    if (mounted) setState(() => _codeSent = sent);
    return null;
  });

  void _confirmCode() {
    final sent = _codeSent;
    final code = normaliseCheckCode(_code.text);
    if (sent == null) return;
    if (code.isEmpty) {
      setState(() => _fieldError = AppLocalizations.of(context).fieldRequired);
      return;
    }
    unawaited(
      _attempt(
        () => ref
            .read(sessionProvider.notifier)
            .confirmWithPhoneCode(sent.codeId, code),
      ),
    );
  }

  Future<void> _google() async {
    final cancel = Completer<void>();
    setState(() => _googleCancel = cancel);
    try {
      await _attempt(
        () => ref
            .read(sessionProvider.notifier)
            .confirmWithGoogle(
              openUrl: (url) => ref.read(urlOpenerProvider)(url),
              cancelled: cancel.future,
            ),
      );
    } finally {
      if (mounted) setState(() => _googleCancel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final user = ref.watch(sessionProvider);
    final methods =
        ref.watch(signInMethodsProvider).asData?.value ??
        SignInMethods.passwordOnly;
    if (user == null) return const SizedBox.shrink();
    final password = user.email.isNotEmpty;
    final google = methods.google && user.email.isNotEmpty;
    // The server refuses SMS sign-in to org admins.
    final sms = methods.phone && user.phone.isNotEmpty && !user.isOrgAdmin;
    final waitingForGoogle = _googleCancel != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.confirmIntro, style: text.bodyMedium),
        const SizedBox(height: Spacing.space4),
        if (waitingForGoogle) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: Text(l10n.confirmGoogleWaiting, style: text.bodyMedium),
          ),
          const SizedBox(height: Spacing.space3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: () => _googleCancel?.complete(),
              child: Text(l10n.actionCancel),
            ),
          ),
        ] else ...<Widget>[
          if (password) ...<Widget>[
            TextField(
              key: const ValueKey<String>('confirm-password'),
              controller: _password,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              enabled: !_busy,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.confirmPassword,
                errorText: _codeSent == null ? _fieldError : null,
              ),
              onSubmitted: (_) => _confirmPassword(),
            ),
            const SizedBox(height: Spacing.space3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                key: const ValueKey<String>('confirm-password-button'),
                onPressed: _busy ? null : _confirmPassword,
                child: Text(_busy ? l10n.confirmWorking : l10n.confirmButton),
              ),
            ),
          ],
          if (google) ...<Widget>[
            const SizedBox(height: Spacing.space3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const ValueKey<String>('confirm-google'),
                onPressed: _busy ? null : () => unawaited(_google()),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.confirmGoogle),
              ),
            ),
          ],
          if (sms) ...<Widget>[
            const SizedBox(height: Spacing.space3),
            if (_codeSent case final PhoneCodeRequest sent) ...<Widget>[
              Text(l10n.confirmSmsSent(sent.phone), style: text.bodyMedium),
              const SizedBox(height: Spacing.space2),
              TextField(
                key: const ValueKey<String>('confirm-code'),
                controller: _code,
                autofocus: !password,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: InputDecoration(
                  labelText: l10n.smsCodeLabel,
                  errorText: _fieldError,
                ),
                onSubmitted: (_) => _confirmCode(),
              ),
              const SizedBox(height: Spacing.space3),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  key: const ValueKey<String>('confirm-code-button'),
                  onPressed: _busy ? null : _confirmCode,
                  child: Text(_busy ? l10n.confirmWorking : l10n.confirmButton),
                ),
              ),
            ] else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('confirm-sms'),
                  onPressed: _busy
                      ? null
                      : () => unawaited(_sendCode(user.phone)),
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(l10n.confirmSms(user.phone)),
                ),
              ),
          ],
          if (!password && !google && !sms) ...<Widget>[
            Text(l10n.confirmNoWay, style: text.bodyMedium),
            const SizedBox(height: Spacing.space3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(sessionProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout),
                label: Text(l10n.menuSignOut),
              ),
            ),
          ],
        ],
        if (_problem case final AppProblem problem) ...<Widget>[
          const SizedBox(height: Spacing.space4),
          ProblemBanner(
            problem: problem,
            onAction: () {
              if (problem.action == ProblemAction.signInAgain) {
                Navigator.of(context).pop();
                ref.read(sessionProvider.notifier).signOut();
              } else {
                setState(() => _problem = null);
              }
            },
          ),
        ],
      ],
    );
  }
}
