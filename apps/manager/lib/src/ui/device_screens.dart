import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_device/obhijatra_device.dart'
    show groupCheckCode, toBanglaDigits;
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/devices.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/widgets/brand_mark.dart';
import 'package:obhijatra_manager/widgets/code_text.dart';
import 'package:obhijatra_manager/widgets/language_switch.dart';
import 'package:obhijatra_manager/widgets/notice_box.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

// The screens shown instead of the app while this device is not approved
// (docs/decisions/0008-device-trust.md). Each lets the person sign out.

/// How often the waiting screen asks the server again while it is visible.
const Duration devicePollEvery = Duration(seconds: 15);

/// The command the person who runs the server types to approve the very
/// first org admin's first device. Always in English digits.
String serverApproveCommand(String deviceId, String checkCode) =>
    'obhijatra-server device approve $deviceId "${groupCheckCode(checkCode)}"';

/// Runs a problem's one action on a device screen: sign in again, or check
/// the device again.
void _onDeviceProblem(WidgetRef ref, AppProblem problem) {
  if (problem.action == ProblemAction.signInAgain) {
    ref.read(sessionProvider.notifier).signOut();
  } else {
    ref.read(deviceGateProvider.notifier).checkAgain();
  }
}

/// The frame every device screen shares: the language switch, a panel with
/// the brand mark and [title], who is signed in, [children], the latest
/// problem with the device check, and "Sign out".
class _DeviceFrame extends ConsumerWidget {
  const _DeviceFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final user = ref.watch(sessionProvider);
    final gate = ref.watch(deviceGateProvider);
    final error = gate.hasError && !gate.isLoading
        ? problemFrom(gate.error!)
        : null;
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(Spacing.space4),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: LanguageSwitch(),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Spacing.space4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ObPanel(
                      padding: const EdgeInsets.all(Spacing.space6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const BrandMark(size: 40),
                              const SizedBox(width: Spacing.space3),
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    title,
                                    style: text.headlineMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (user != null) ...<Widget>[
                            const SizedBox(height: Spacing.space2),
                            Text(
                              l10n.deviceSignedInAs(user.displayName),
                              style: text.bodySmall!.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: Spacing.space4),
                          ...children,
                          if (error != null) ...<Widget>[
                            const SizedBox(height: Spacing.space4),
                            ProblemBanner(
                              problem: error,
                              onAction: () => _onDeviceProblem(ref, error),
                            ),
                          ],
                          const SizedBox(height: Spacing.space3),
                          TextButton.icon(
                            onPressed: () =>
                                ref.read(sessionProvider.notifier).signOut(),
                            icon: const Icon(Icons.logout),
                            label: Text(l10n.menuSignOut),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A paragraph in the body style.
class _Para extends StatelessWidget {
  const _Para(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.space3),
      child: Text(
        text,
        style: muted ? style.copyWith(color: context.palette.textMuted) : style,
      ),
    );
  }
}

/// "Check again". It shows "Checking…" only for a check the person asked
/// for, so the automatic check every 15 seconds does not make it flicker.
class _CheckAgainButton extends ConsumerStatefulWidget {
  const _CheckAgainButton();

  @override
  ConsumerState<_CheckAgainButton> createState() => _CheckAgainButtonState();
}

class _CheckAgainButtonState extends ConsumerState<_CheckAgainButton> {
  /// The person pressed the button and the check has not finished yet.
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(
      deviceGateProvider.select((gate) => gate.isLoading),
    );
    ref.listen(deviceGateProvider.select((gate) => gate.isLoading), (
      _,
      loading,
    ) {
      if (!loading && _asked) setState(() => _asked = false);
    });
    final busy = _asked && loading;
    return FilledButton.icon(
      key: const ValueKey<String>('device-check-again'),
      onPressed: busy
          ? null
          : () {
              setState(() => _asked = true);
              // An automatic check already running gives the answer.
              if (!loading) ref.read(deviceGateProvider.notifier).checkAgain();
            },
      icon: const Icon(Icons.refresh),
      label: Text(busy ? l10n.deviceCheckingNow : l10n.deviceCheckAgain),
    );
  }
}

/// "Set up this device again", after a confirmation.
class _SetUpAgainButton extends ConsumerWidget {
  const _SetUpAgainButton({this.filled = true});

  final bool filled;

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deviceSetUpAgainTitle),
        content: Text(l10n.deviceSetUpAgainBody),
        actions: <Widget>[
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('device-set-up-again-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deviceSetUpAgainConfirm),
          ),
        ],
      ),
    );
    if (sure ?? false) {
      await ref.read(deviceGateProvider.notifier).setUpAgain();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(deviceGateProvider.select((gate) => gate.isLoading));
    final onPressed = busy ? null : () => unawaited(_confirm(context, ref));
    final label = Text(l10n.deviceSetUpAgain);
    const icon = Icon(Icons.restart_alt);
    return filled
        ? FilledButton.icon(onPressed: onPressed, icon: icon, label: label)
        : OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label);
  }
}

/// Shown while the device is checked with the server after sign-in.
class DeviceCheckingScreen extends StatelessWidget {
  /// Creates the screen.
  const DeviceCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).deviceChecking;
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: Center(
        child: Semantics(
          label: label,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: Spacing.space3),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the device check itself failed (offline, the session ended,
/// too many devices waiting, keys that could not be kept).
class DeviceProblemScreen extends ConsumerWidget {
  /// Creates the screen for [problem].
  const DeviceProblemScreen({required this.problem, super.key});

  /// What went wrong.
  final AppProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(Spacing.space4),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: LanguageSwitch(),
              ),
            ),
            Expanded(
              child: ProblemView(
                problem: problem,
                onAction: () => _onDeviceProblem(ref, problem),
              ),
            ),
            if (problem.action != ProblemAction.signInAgain)
              Padding(
                padding: const EdgeInsets.all(Spacing.space4),
                child: TextButton.icon(
                  onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.menuSignOut),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The device's 18-digit check code, large, in six groups of three, with
/// Bangla digits when the app is in Bangla. Screen readers read it digit
/// by digit.
class DeviceCodeDisplay extends StatelessWidget {
  /// Shows [code] (18 English digits).
  const DeviceCodeDisplay({required this.code, super.key});

  /// The code, as [deviceCheckCode] gives it.
  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final bangla = Localizations.localeOf(context).languageCode == 'bn';
    String shown(String digits) => bangla ? toBanglaDigits(digits) : digits;
    final groups = groupCheckCode(code).split(' ').map(shown).toList();
    final style = text.headlineMedium!.copyWith(
      fontFamily: text.bodyLarge!.fontFamily,
      fontFamilyFallback: text.bodyLarge!.fontFamilyFallback,
      fontWeight: FontWeight.w600,
      letterSpacing: 2,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      color: palette.text,
    );
    final spoken = groups.map((group) => group.split('').join(' ')).join(', ');
    return Semantics(
      label: '${l10n.deviceCodeLabel}: $spoken',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('device-code'),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space4,
          vertical: Spacing.space4,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: Radii.mdAll,
          border: Border.all(color: palette.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.deviceCodeLabel, style: text.labelLarge),
            const SizedBox(height: Spacing.space2),
            Wrap(
              spacing: Spacing.space4,
              runSpacing: Spacing.space2,
              children: <Widget>[
                for (final group in groups) Text(group, style: style),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while this device waits for approval, or for approval again after
/// a year: the check code, who approves, "Check again", and a check every
/// 15 seconds while the window can be seen (none while it is minimised or
/// its browser tab is hidden, and one at once when it is shown again).
class DeviceWaitingScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [gate].
  const DeviceWaitingScreen({required this.gate, super.key});

  /// The device check's answer.
  final DeviceGate gate;

  @override
  ConsumerState<DeviceWaitingScreen> createState() =>
      _DeviceWaitingScreenState();
}

class _DeviceWaitingScreenState extends ConsumerState<DeviceWaitingScreen> {
  Timer? _poll;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onShow: _shown, onHide: _stop);
    if (_visible) _start();
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Whether the window can be seen: in front, or behind another window
  /// but not minimised (a hidden browser tab or a minimised window is not).
  static bool get _visible => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    _ => false,
  };

  void _start() {
    _poll?.cancel();
    _poll = Timer.periodic(devicePollEvery, (_) => _check());
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
  }

  /// Shown again: asks at once, then every 15 seconds.
  void _shown() {
    _check();
    _start();
  }

  /// Asks the server again, unless a check is running already.
  void _check() {
    if (!mounted || ref.read(deviceGateProvider).isLoading) return;
    ref.read(deviceGateProvider.notifier).checkAgain();
  }

  Future<void> _copy(String command) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: command));
    messenger.showSnackBar(SnackBar(content: Text(l10n.deviceCommandCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final gate = widget.gate;
    final renewal = gate.stage == DeviceStage.expired;
    final isAdmin = ref.watch(
      sessionProvider.select((user) => user?.isOrgAdmin ?? false),
    );
    final deviceId = gate.deviceId;
    return _DeviceFrame(
      title: renewal ? l10n.deviceRenewTitle : l10n.deviceWaitingTitle,
      children: <Widget>[
        if (gate.serverForgot)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.space3),
            child: NoticeBox(
              key: const ValueKey<String>('device-server-forgot'),
              message: l10n.deviceServerForgot,
              tone: Tone.info,
            ),
          ),
        _Para(renewal ? l10n.deviceRenewIntro : l10n.deviceWaitingIntro),
        if (gate.checkCode.isNotEmpty) DeviceCodeDisplay(code: gate.checkCode),
        const SizedBox(height: Spacing.space2),
        if (gate.label.isNotEmpty)
          _Para(l10n.deviceThisDevice(gate.label), muted: true),
        const SizedBox(height: Spacing.space2),
        if (!isAdmin)
          _Para(l10n.deviceWhoStaff)
        else ...<Widget>[
          _Para(l10n.deviceWhoAdmin),
          if (gate.needsSecondApproval)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.space3),
              child: NoticeBox(
                message: l10n.deviceWhoAdminSecond,
                tone: Tone.info,
              ),
            ),
        ],
        _Para(l10n.deviceNoMessages, muted: true),
        // Only before any approval: once an admin has approved, there are
        // other admins, so the server command is not needed.
        if (isAdmin &&
            !gate.needsSecondApproval &&
            deviceId != null &&
            gate.checkCode.isNotEmpty) ...<Widget>[
          const SizedBox(height: Spacing.space2),
          Text(l10n.deviceFirstAdminTitle, style: text.titleMedium),
          const SizedBox(height: Spacing.space1),
          _Para(l10n.deviceFirstAdminBody),
          _CommandBox(
            command: serverApproveCommand(deviceId, gate.checkCode),
            onCopy: (command) => unawaited(_copy(command)),
          ),
          const SizedBox(height: Spacing.space4),
        ],
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: _CheckAgainButton(),
        ),
        const SizedBox(height: Spacing.space2),
        Text(
          <String>[
            l10n.deviceAutoCheck,
            if (gate.checkedAt case final DateTime checked)
              l10n.deviceLastChecked(Format.clock(context, checked)),
          ].join(' '),
          key: const ValueKey<String>('device-last-checked'),
          style: text.bodySmall!.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}

/// The server command in a fixed-width box, with a button that copies it.
class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command, required this.onCopy});

  final String command;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: Spacing.space3,
        top: Spacing.space1,
        bottom: Spacing.space1,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: Radii.smAll,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            // The command is always left to right, also in Bangla.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                command,
                key: const ValueKey<String>('device-command'),
                style: codeStyle(Theme.of(context).textTheme.bodyMedium!),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.actionCopy,
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => onCopy(command),
          ),
        ],
      ),
    );
  }
}

/// Shown when this device has been switched off.
class DeviceRevokedScreen extends StatelessWidget {
  /// Creates the screen.
  const DeviceRevokedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DeviceFrame(
      title: l10n.deviceRevokedTitle,
      children: <Widget>[
        _Para(l10n.deviceRevokedBody),
        const SizedBox(height: Spacing.space2),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: _SetUpAgainButton(),
        ),
      ],
    );
  }
}

/// Shown when the server does not recognise this device's keys.
class DeviceNotRecognisedScreen extends StatelessWidget {
  /// Creates the screen.
  const DeviceNotRecognisedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DeviceFrame(
      title: l10n.deviceNotRecognisedTitle,
      children: <Widget>[
        _Para(l10n.deviceNotRecognisedBody),
        const SizedBox(height: Spacing.space2),
        const Wrap(
          spacing: Spacing.space3,
          runSpacing: Spacing.space3,
          children: <Widget>[
            _CheckAgainButton(),
            _SetUpAgainButton(filled: false),
          ],
        ),
      ],
    );
  }
}

/// Shown when this computer's clock is too far from the server's.
class DeviceClockScreen extends StatelessWidget {
  /// Creates the screen.
  const DeviceClockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DeviceFrame(
      title: l10n.deviceClockTitle,
      children: <Widget>[
        _Para(l10n.deviceClockBody),
        const SizedBox(height: Spacing.space2),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: _CheckAgainButton(),
        ),
      ],
    );
  }
}

/// Shown when this browser cannot keep device keys: too old, or the page
/// was not opened at a secure address. There is no weaker fallback.
class DeviceUnsupportedScreen extends StatelessWidget {
  /// Creates the screen; [secureAddress] when the page needs `https`.
  const DeviceUnsupportedScreen({required this.secureAddress, super.key});

  /// The page was opened at a plain `http` address.
  final bool secureAddress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DeviceFrame(
      title: secureAddress
          ? l10n.deviceSecureAddressTitle
          : l10n.deviceUpdateBrowserTitle,
      children: <Widget>[
        _Para(
          secureAddress
              ? l10n.deviceSecureAddressBody
              : l10n.deviceUpdateBrowserBody,
        ),
      ],
    );
  }
}
