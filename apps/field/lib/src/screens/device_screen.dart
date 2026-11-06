import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/data_providers.dart';
import 'package:obhijatra_field/src/providers/device_providers.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/screens/main_shell.dart';
import 'package:obhijatra_field/src/screens/settings_screen.dart';
import 'package:obhijatra_field/src/screens/splash_screen.dart';
import 'package:obhijatra_field/src/screens/startup_problem_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// How often the device screen asks the server again while it is visible
/// and the phone waits for approval.
const Duration deviceCheckInterval = Duration(seconds: 15);

/// Shows the app once this phone is approved, or once the person chose to
/// fill in forms meanwhile; until then the [DeviceTrustScreen]. Uses the
/// last answer kept on the phone, so it works offline.
class DeviceGate extends ConsumerWidget {
  /// Creates the gate.
  const DeviceGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trust = ref.watch(deviceTrustProvider);
    return trust.when(
      skipLoadingOnReload: true,
      loading: () => const SplashScreen(),
      error: (error, _) => StartupProblemScreen(
        code: problemOf(error),
        onRetry: () => ref.invalidate(deviceIdentityProvider),
      ),
      data: (state) => state.phase == DevicePhase.approved || state.deferred
          ? const MainShell()
          : const DeviceTrustScreen(),
    );
  }
}

/// Opens the [DeviceTrustScreen] over the app (from the Today screen, when
/// the person fills in forms before the phone is approved). It closes by
/// itself once the phone is approved.
Future<void> openDeviceScreen(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DeviceTrustScreen(pushed: true),
      ),
    );

/// Where this phone stands with the organisation's server, and what to do:
///
/// - setting up: enrolling, with "Try again" when it did not work;
/// - after the server no longer knew the phone: the same, saying so (the
///   phone enrols again with the same keys and numbers);
/// - waiting for approval, or approval run out: the 18 numbers in six
///   groups of three for the approver, who approves, how to give them the
///   numbers (in person or on a call, never by message), "Check again", and
///   a check every [deviceCheckInterval] while the screen is visible (also
///   while setting up could not reach the server);
/// - switched off: what happened, and "Set up this phone again" after a
///   confirmation.
///
/// Every state offers "Sign out"; all but switched off offer "Fill in
/// forms on this phone for now" when there are forms on the phone.
class DeviceTrustScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [pushed] when it was opened over the app.
  const DeviceTrustScreen({this.pushed = false, super.key});

  /// Whether it was opened over the app (it then has a back button and
  /// closes once the phone is approved).
  final bool pushed;

  @override
  ConsumerState<DeviceTrustScreen> createState() => _DeviceTrustState();
}

class _DeviceTrustState extends ConsumerState<DeviceTrustScreen> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  DeviceTrustNotifier get _trust => ref.read(deviceTrustProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Checks run only while the app is in front: hidden, the timer stops;
    // back in front, the phone asks at once and the timer starts again.
    _lifecycle = AppLifecycleListener(
      onHide: _stopChecking,
      onShow: () {
        _startChecking();
        _checkIfUseful();
      },
    );
    // Ask at once (or enrol, when the phone is not set up: that shows), then
    // every 15 seconds while it is useful, quietly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final phase = ref.read(deviceTrustProvider).value?.phase;
      unawaited(_trust.check(quietly: phase != DevicePhase.settingUp));
    });
    _startChecking();
  }

  void _startChecking() {
    _timer?.cancel();
    _timer = Timer.periodic(deviceCheckInterval, (_) => _checkIfUseful());
  }

  void _stopChecking() {
    _timer?.cancel();
    _timer = null;
  }

  /// Asks the server again while the answer can change by itself: the
  /// phone waits for an approval, or could not be set up for lack of a
  /// connection. Not while a dialog covers the screen, and not when only
  /// the person can help (signing in again, setting the phone up again).
  void _checkIfUseful() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final state = ref.read(deviceTrustProvider).value;
    if (state == null) return;
    final problem = state.problem;
    if (problem != null && problem.needsSignInAgain) return;
    final useful = switch (state.phase) {
      DevicePhase.waiting || DevicePhase.renewal => true,
      DevicePhase.settingUp =>
        problem == ProblemCode.offline || problem == ProblemCode.timeout,
      DevicePhase.approved || DevicePhase.switchedOff => false,
    };
    if (useful) unawaited(_trust.check(quietly: true));
  }

  @override
  void dispose() {
    _stopChecking();
    _lifecycle.dispose();
    super.dispose();
  }

  void _leave() {
    final navigator = Navigator.of(context);
    if (widget.pushed && navigator.canPop()) navigator.pop();
  }

  void _signInAgain() {
    // Read before leaving: a pushed screen is gone afterwards.
    final session = ref.read(sessionProvider.notifier);
    _leave();
    session.signOut();
  }

  Future<void> _setUpAgain() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deviceSetUpAgainTitle),
        content: Text(l.deviceSetUpAgainBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.deviceSetUpAgainConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final trust = _trust; // read before leaving, as above
    _leave();
    await trust.setUpAgain();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pushed) {
      // Opened over the app: close once the phone is approved.
      ref.listen(deviceTrustProvider, (previous, next) {
        if (next.value?.phase == DevicePhase.approved) _leave();
      });
    }
    final state = ref.watch(deviceTrustProvider).value;
    if (state == null) return const SplashScreen();
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final hasForms =
        (ref.watch(cachedFormsProvider).value ?? const <CachedForm>[])
            .isNotEmpty;
    final problem = state.problem;
    final signInAgain = problem != null && problem.needsSignInAgain;

    final (icon, iconColor, iconBackground, title) = switch (state.phase) {
      DevicePhase.settingUp => (
        LucideIcons.smartphone,
        p.info,
        p.infoSubtle,
        l.deviceSettingUpTitle,
      ),
      DevicePhase.waiting || DevicePhase.approved => (
        LucideIcons.hourglass,
        p.info,
        p.infoSubtle,
        l.deviceWaitingTitle,
      ),
      DevicePhase.renewal => (
        LucideIcons.calendarClock,
        p.warning,
        p.warningSubtle,
        l.deviceRenewalTitle,
      ),
      DevicePhase.switchedOff => (
        LucideIcons.ban,
        p.danger,
        p.dangerSubtle,
        l.deviceSwitchedOffTitle,
      ),
    };
    final showsCode =
        state.phase == DevicePhase.waiting ||
        state.phase == DevicePhase.renewal;
    final checked = state.checkedAt;

    final body = <Widget>[
      ResultHeader(
        icon: icon,
        iconColor: iconColor,
        iconBackground: iconBackground,
        title: title,
      ),
      const SizedBox(height: Spacing.space4),
      ...switch (state.phase) {
        DevicePhase.settingUp => <Widget>[
          Text(l.deviceSettingUpBody, style: text.bodyLarge),
          if (state.serverForgot) ...<Widget>[
            const SizedBox(height: Spacing.space3),
            _Point(icon: LucideIcons.serverOff, text: l.deviceServerForgot),
          ],
          if (state.checking) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            _Working(text: l.deviceSettingUpWorking),
          ],
        ],
        DevicePhase.waiting || DevicePhase.approved => <Widget>[
          Text(l.deviceWaitingBody, style: text.bodyLarge),
          if (state.serverForgot) ...<Widget>[
            const SizedBox(height: Spacing.space3),
            _Point(icon: LucideIcons.serverOff, text: l.deviceServerForgot),
          ],
        ],
        DevicePhase.renewal => <Widget>[
          Text(l.deviceRenewalBody, style: text.bodyLarge),
        ],
        DevicePhase.switchedOff => <Widget>[
          Text(l.deviceSwitchedOffBody, style: text.bodyLarge),
          const SizedBox(height: Spacing.space3),
          _Point(icon: LucideIcons.fileCheck, text: l.deviceSwitchedOffKept),
          const SizedBox(height: Spacing.space3),
          _Point(icon: LucideIcons.rotateCcw, text: l.deviceSwitchedOffNext),
        ],
      },
      if (showsCode) ...<Widget>[
        const SizedBox(height: Spacing.space5),
        Panel(
          color: p.surfaceSunken,
          child: Column(
            children: <Widget>[
              Text(
                l.deviceCodeHeading,
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.space3),
              DeviceCodeView(code: state.code),
            ],
          ),
        ),
        const SizedBox(height: Spacing.space4),
        _Point(icon: LucideIcons.users, text: l.deviceShowInPerson),
        const SizedBox(height: Spacing.space3),
        _Point(icon: LucideIcons.messageSquareOff, text: l.deviceNeverSend),
        const SizedBox(height: Spacing.space4),
        Text(
          l.deviceAutoCheck,
          style: text.bodySmall!.copyWith(color: p.textMuted),
        ),
        if (checked != null)
          Text(
            l.deviceLastChecked(
              fmt.when(checked, bangla: bangla, now: ref.watch(nowProvider)()),
            ),
            key: const Key('device-last-checked'),
            style: text.bodySmall!.copyWith(color: p.textMuted),
          ),
      ],
      if (problem != null) ...<Widget>[
        const SizedBox(height: Spacing.space4),
        _ProblemNotice(
          text: problem == ProblemCode.offline || problem == ProblemCode.timeout
              ? l.deviceCheckOffline
              : problemText(l, problem),
          connection:
              problem == ProblemCode.offline || problem == ProblemCode.timeout,
        ),
      ],
    ];

    final main = signInAgain
        ? PrimaryButton(
            label: l.actionSignInAgain,
            icon: LucideIcons.logIn,
            onPressed: _signInAgain,
          )
        : switch (state.phase) {
            DevicePhase.switchedOff => PrimaryButton(
              label: l.deviceSetUpAgain,
              icon: LucideIcons.rotateCcw,
              onPressed: _setUpAgain,
            ),
            DevicePhase.settingUp => PrimaryButton(
              label: state.checking
                  ? l.deviceSettingUpWorking
                  : l.actionTryAgain,
              icon: LucideIcons.refreshCw,
              busy: state.checking,
              onPressed: _trust.check,
            ),
            _ => PrimaryButton(
              label: state.checking ? l.deviceChecking : l.deviceCheckAgain,
              icon: LucideIcons.refreshCw,
              busy: state.checking,
              onPressed: _trust.check,
            ),
          };

    return ScreenFrame(
      topBar: TopBar(
        title: l.appTitle,
        showMark: !widget.pushed,
        leadingIcon: widget.pushed ? LucideIcons.arrowLeft : null,
        leadingLabel: widget.pushed ? l.actionBack : null,
        onLeading: widget.pushed ? _leave : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: body,
      ),
      bottom: BottomActions(
        children: <Widget>[
          main,
          // Not on a phone that was switched off: it may not be used.
          if (hasForms &&
              !widget.pushed &&
              state.phase != DevicePhase.switchedOff)
            PrimaryButton(
              label: l.deviceFillInForms,
              icon: LucideIcons.clipboardList,
              variant: PrimaryButtonVariant.secondary,
              onPressed: _trust.fillInFormsMeanwhile,
            ),
          if (!widget.pushed && !signInAgain)
            PrimaryButton(
              label: l.settingsSignOut,
              variant: PrimaryButtonVariant.ghost,
              onPressed: () => confirmSignOut(context, ref),
            ),
        ],
      ),
    );
  }
}

/// A phone's 18-digit check code in six groups of three, large enough to
/// read at arm's length, in Bangla digits when the app is in Bangla. A
/// screen reader reads it digit by digit, group by group.
class DeviceCodeView extends StatelessWidget {
  /// Creates the view of [code] (18 digits); [compact] for Settings.
  const DeviceCodeView({required this.code, this.compact = false, super.key});

  /// The 18 digits.
  final String code;

  /// Whether to show it smaller.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final bangla = Localizations.localeOf(context).languageCode == 'bn';
    String shown(String digits) => bangla ? fmt.toBanglaDigits(digits) : digits;
    final groups = <String>[
      for (var i = 0; i + 3 <= code.length; i += 3)
        shown(code.substring(i, i + 3)),
    ];
    final spoken = groups.map((g) => g.split('').join(' ')).join(', ');
    // The body family (Noto Sans) at heading size, with figures of one
    // width, so the groups line up and read like a number plate.
    final size = compact ? text.titleLarge! : text.headlineLarge!;
    final style = size.copyWith(
      fontFamily: text.bodyLarge!.fontFamily,
      fontFamilyFallback: text.bodyLarge!.fontFamilyFallback,
      fontWeight: FontWeight.w700,
      letterSpacing: compact ? 1 : 3,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      color: context.palette.text,
    );
    return Semantics(
      container: true,
      label: l.deviceCodeSpoken(spoken),
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          key: const Key('device-code'),
          alignment: compact ? WrapAlignment.start : WrapAlignment.center,
          spacing: compact ? Spacing.space3 : Spacing.space5,
          runSpacing: Spacing.space2,
          children: <Widget>[
            for (final group in groups) Text(group, style: style),
          ],
        ),
      ),
    );
  }
}

/// One line of advice with an icon.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: Spacing.space1),
          child: Icon(icon, size: Sizes.icon, color: p.action),
        ),
        const SizedBox(width: Spacing.space3),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// A progress ring with a line of text, spoken when it appears.
class _Working extends StatelessWidget {
  const _Working({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: Sizes.icon,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: Spacing.space3),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// A problem in plain words, spoken when it appears. Connection problems
/// are shown as information, the others as a warning.
class _ProblemNotice extends StatelessWidget {
  const _ProblemNotice({required this.text, required this.connection});

  final String text;
  final bool connection;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Panel(
      color: connection ? p.infoSubtle : p.warningSubtle,
      borderColor: connection ? p.info : p.warning,
      child: Semantics(
        liveRegion: true,
        container: true,
        label: text,
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: Icon(
                  connection ? LucideIcons.wifiOff : LucideIcons.triangleAlert,
                  color: connection ? p.info : p.warning,
                ),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: Text(
                  text,
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
