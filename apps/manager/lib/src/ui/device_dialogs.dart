import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_device/obhijatra_device.dart' show checkCodeDigits;
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/devices.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/device_words.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/widgets/code_text.dart';
import 'package:obhijatra_manager/widgets/notice_box.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

bool _isDigit(int rune) =>
    (rune >= 0x30 && rune <= 0x39) || (rune >= 0x09E6 && rune <= 0x09EF);

/// Keeps only the digits typed (English or Bangla, as typed), at most 18,
/// in groups of three: "225 142 753 …". The cursor stays after the same
/// digit.
class CheckCodeFormatter extends TextInputFormatter {
  /// Creates the formatter.
  const CheckCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    final out = StringBuffer();
    var digits = 0;
    var digitsBeforeCursor = 0;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (!_isDigit(unit) || digits == checkCodeDigits) continue;
      if (digits > 0 && digits % 3 == 0) out.write(' ');
      out.writeCharCode(unit);
      digits++;
      if (i < cursor) digitsBeforeCursor = digits;
    }
    final formatted = out.toString();
    // The position just after the digitsBeforeCursor-th digit.
    var offset = 0;
    for (
      var seen = 0;
      offset < formatted.length && seen < digitsBeforeCursor;
      offset++
    ) {
      if (formatted.codeUnitAt(offset) != 0x20) seen++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

// ---------------------------------------------------------------- approve

/// Asks for the 18 numbers on [device]'s own screen and approves it when
/// they match, then says what came of it: approved until a date, or
/// waiting for one more organisation admin. The list of devices is
/// reloaded as soon as the server has approved it. Returns the device as
/// the server now has it, or null when nothing was approved.
Future<DeviceView?> showApproveDeviceDialog(
  BuildContext context, {
  required DeviceRecord device,
}) => showDialog<DeviceView>(
  context: context,
  builder: (context) => _ApproveDialog(device: device),
);

class _ApproveDialog extends ConsumerStatefulWidget {
  const _ApproveDialog({required this.device});

  final DeviceRecord device;

  @override
  ConsumerState<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends ConsumerState<_ApproveDialog> {
  final _code = TextEditingController();
  String? _error;
  AppProblem? _problem;
  bool _busy = false;

  /// The server's answer once the device is approved.
  DeviceView? _result;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final device = widget.device;
    final name = ownerName(l10n, device);
    // The numbers are compared with the device's keys here first: on a
    // mismatch nothing is sent. The server checks them again anyway.
    final error = switch (checkTypedCode(device, _code.text)) {
      CodeCheck.incomplete => l10n.approveCodeIncomplete,
      CodeCheck.mismatch => l10n.approveMismatch(name),
      CodeCheck.unreadableKeys => l10n.approveUnreadable(name),
      CodeCheck.match => null,
    };
    setState(() {
      _error = error;
      _problem = null;
    });
    if (error != null) return;
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    try {
      final view = await trackedUi(
        ref,
        () => api.approveDevice(device.id, _code.text),
      );
      if (!mounted) return;
      // The list behind the dialog shows the new state at once.
      ref.invalidate(devicesProvider);
      setState(() => _result = view);
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        if (problem.kind == ProblemKind.deviceCodeMismatch) {
          _error = l10n.approveMismatch(name);
        } else {
          _problem = problem;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onProblem(AppProblem problem) {
    switch (problem.action) {
      case ProblemAction.signInAgain:
        Navigator.of(context).pop();
        ref.read(sessionProvider.notifier).signOut();
      case ProblemAction.tryAgain:
        unawaited(_approve());
      case ProblemAction.reload:
        Navigator.of(context).pop();
        ref.invalidate(devicesProvider);
      case ProblemAction.close || ProblemAction.chooseFile:
        setState(() => _problem = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    // Not closed half way: the answer to a request already sent is shown.
    return PopScope(
      canPop: !_busy,
      child: result == null ? _askForCode(context) : _outcome(context, result),
    );
  }

  /// What came of the approval, in words: approved until a date, or
  /// waiting for one more organisation admin.
  Widget _outcome(BuildContext context, DeviceView view) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final name = ownerName(l10n, widget.device);
    final first = view.needsSecondApproval;
    final expires = view.expires;
    final title = first
        ? l10n.approveDoneFirstTitle
        : expires == null
        ? l10n.approveDoneTitle
        : l10n.approveDoneUntil(Format.day(context, expires));
    return AlertDialog(
      key: const ValueKey<String>('approve-result'),
      icon: Icon(
        first ? Icons.how_to_reg_outlined : Icons.verified_user_outlined,
        color: first ? palette.info : palette.success,
      ),
      title: Semantics(liveRegion: true, child: Text(title)),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Text(
          first ? l10n.approveDoneFirst(name) : l10n.approveDone(name),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      actions: <Widget>[
        FilledButton(
          key: const ValueKey<String>('approve-done'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(view),
          child: Text(l10n.actionDone),
        ),
      ],
    );
  }

  Widget _askForCode(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final device = widget.device;
    final name = ownerName(l10n, device);
    final now = ref.watch(deviceClockProvider)();
    final unreadable = !device.keysReadable;
    return AlertDialog(
      title: Text(l10n.approveTitle(name)),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.approveHow(name), style: text.bodyMedium),
            const SizedBox(height: Spacing.space3),
            Row(
              children: <Widget>[
                Icon(
                  platformIcon(device.platform),
                  size: Sizes.icon,
                  color: palette.textMuted,
                ),
                const SizedBox(width: Spacing.space2),
                Expanded(
                  child: Text(
                    deviceAndPlatform(l10n, device),
                    style: text.bodySmall!.copyWith(color: palette.textMuted),
                  ),
                ),
              ],
            ),
            if (device.ownerIsOrgAdmin) ...<Widget>[
              const SizedBox(height: Spacing.space3),
              NoticeBox(
                message: device.needsSecondApproval
                    ? l10n.approveAdminSecond
                    : l10n.approveAdminDevice,
                tone: Tone.info,
              ),
            ],
            if (device.approvalExpiredAt(now)) ...<Widget>[
              const SizedBox(height: Spacing.space3),
              NoticeBox(message: l10n.approveRenewal, tone: Tone.info),
            ],
            const SizedBox(height: Spacing.space4),
            if (unreadable)
              NoticeBox(message: l10n.approveUnreadable(name))
            else
              TextField(
                key: const ValueKey<String>('approve-code'),
                controller: _code,
                autofocus: true,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: const <TextInputFormatter>[
                  CheckCodeFormatter(),
                ],
                style: codeStyle(text.titleLarge!),
                decoration: InputDecoration(
                  labelText: l10n.approveCodeLabel,
                  helperText: l10n.approveCodeHelp,
                  helperMaxLines: 3,
                  errorText: _error,
                  errorMaxLines: 5,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => unawaited(_approve()),
              ),
            if (_problem case final AppProblem problem) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              ProblemBanner(
                problem: problem,
                onAction: () => _onProblem(problem),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('approve-confirm'),
          onPressed: _busy || unreadable ? null : () => unawaited(_approve()),
          child: Text(_busy ? l10n.approveWorking : l10n.approveButton),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- switch off

/// Asks before switching [device] off, naming the person and the device and
/// saying they are signed out at once. [mine] when it is the signed-in
/// person's own; [current] when it is the device in use. Returns true once
/// it is switched off.
Future<bool?> showSwitchOffDeviceDialog(
  BuildContext context, {
  required DeviceRecord device,
  required bool mine,
  required bool current,
}) => showDialog<bool>(
  context: context,
  builder: (context) =>
      _SwitchOffDialog(device: device, mine: mine, current: current),
);

class _SwitchOffDialog extends ConsumerStatefulWidget {
  const _SwitchOffDialog({
    required this.device,
    required this.mine,
    required this.current,
  });

  final DeviceRecord device;
  final bool mine;
  final bool current;

  @override
  ConsumerState<_SwitchOffDialog> createState() => _SwitchOffDialogState();
}

class _SwitchOffDialogState extends ConsumerState<_SwitchOffDialog> {
  AppProblem? _problem;
  bool _busy = false;

  Future<void> _switchOff() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    final api = ref.read(apiProvider);
    try {
      await trackedUi(ref, () => api.revokeDevice(widget.device.id));
      if (mounted) Navigator.of(context).pop(true);
    } on AppProblem catch (problem) {
      if (mounted) setState(() => _problem = problem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onProblem(AppProblem problem) {
    switch (problem.action) {
      case ProblemAction.signInAgain:
        Navigator.of(context).pop();
        ref.read(sessionProvider.notifier).signOut();
      case ProblemAction.tryAgain:
        unawaited(_switchOff());
      case ProblemAction.reload:
        Navigator.of(context).pop();
        ref.invalidate(devicesProvider);
      case ProblemAction.close || ProblemAction.chooseFile:
        setState(() => _problem = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final device = widget.device;
    final name = deviceName(l10n, device);
    // Not closed half way: the answer to a request already sent is shown.
    return PopScope(
      canPop: !_busy,
      child: _dialog(l10n, palette, device, name),
    );
  }

  Widget _dialog(
    AppLocalizations l10n,
    ObhijatraPalette palette,
    DeviceRecord device,
    String name,
  ) {
    return AlertDialog(
      title: Text(l10n.switchOffTitle),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.current)
              NoticeBox(message: l10n.switchOffCurrent, tone: Tone.warning)
            else
              Text(
                widget.mine
                    ? l10n.switchOffMine(name)
                    : l10n.switchOffBody(ownerName(l10n, device), name),
              ),
            if (_problem case final AppProblem problem) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              ProblemBanner(
                problem: problem,
                onAction: () => _onProblem(problem),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('switch-off-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: palette.danger,
            foregroundColor: palette.onAction,
          ),
          onPressed: _busy ? null : () => unawaited(_switchOff()),
          child: Text(_busy ? l10n.switchOffWorking : l10n.deviceSwitchOff),
        ),
      ],
    );
  }
}
