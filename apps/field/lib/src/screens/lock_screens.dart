import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/platform/device_authenticator.dart';
import 'package:obhijatra_field/src/platform/sign_in_browser.dart';
import 'package:obhijatra_field/src/providers/app_lock_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/screens/sign_in_screen.dart';
import 'package:obhijatra_field/src/screens/splash_screen.dart';
import 'package:obhijatra_field/src/screens/startup_problem_screen.dart';
import 'package:obhijatra_field/src/widgets/labeled_field.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Shows the app ([child], with its own navigation) only while the app lock
/// lets the data open; otherwise the lock screens, in a navigator of their
/// own. Swapping [child] out drops every open screen, so nothing of the data
/// stays on screen or in memory while the app is locked.
class LockLayer extends ConsumerWidget {
  /// Creates the layer around the app's navigator [child].
  const LockLayer({required this.child, super.key});

  /// The app's navigator.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opens = ref.watch(
      appLockProvider.select((lock) => lock.value?.opensData ?? false),
    );
    if (opens) return child;
    return Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const LockGate()),
    );
  }
}

/// The lock screen that fits the app lock's state.
class LockGate extends ConsumerWidget {
  /// Creates the gate.
  const LockGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    return lock.when(
      loading: () => const SplashScreen(),
      error: (error, _) => StartupProblemScreen(
        code: problemOf(error),
        onRetry: () => ref.invalidate(appLockProvider),
      ),
      data: (state) => switch (state) {
        LockLocked(method: UnlockMethod.device) => const DeviceUnlockScreen(
          key: ValueKey<String>('unlock-device'),
        ),
        LockLocked(method: UnlockMethod.pin) => const PinUnlockScreen(
          key: ValueKey<String>('unlock-pin'),
        ),
        LockNeedsSignIn(:final reason) => OnlineSignInScreen(
          reason: reason,
          key: ValueKey<String>('sign-in-$reason'),
        ),
        LockNeedsPin() => const SetPinScreen(key: ValueKey<String>('set-pin')),
        // The app itself is shown; never reached.
        LockFresh() || LockOpen() => const SplashScreen(),
      },
    );
  }
}

/// A lock screen: the app mark, a lock icon, a title and a short text,
/// then whatever the screen needs, with its buttons at the bottom.
class _LockFrame extends StatelessWidget {
  const _LockFrame({
    required this.title,
    required this.body,
    required this.actions,
    this.icon = LucideIcons.lock,
    this.children = const <Widget>[],
  });

  final String title;
  final String body;
  final IconData icon;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return ScreenFrame(
      topBar: TopBar(title: l.appTitle, showMark: true),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          // Kept compact, so the PIN field stays near the top even with the
          // largest text.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: Sizes.touch + Spacing.space2,
              height: Sizes.touch + Spacing.space2,
              decoration: BoxDecoration(
                color: p.actionSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: Sizes.iconLg, color: p.action),
            ),
          ),
          const SizedBox(height: Spacing.space3),
          Semantics(header: true, child: Text(title, style: text.titleLarge)),
          const SizedBox(height: Spacing.space2),
          Text(body, style: text.bodyLarge),
          ...children,
        ],
      ),
      bottom: BottomActions(children: actions),
    );
  }
}

/// A plain notice under a lock screen's text; spoken when it appears.
class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.space4),
      child: Panel(
        color: p.warningSubtle,
        borderColor: p.warning,
        child: Semantics(
          liveRegion: true,
          container: true,
          label: message,
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.space1),
                  child: Icon(LucideIcons.triangleAlert, color: p.warning),
                ),
                const SizedBox(width: Spacing.space3),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Six digits, hidden, typed on the number keyboard (Bangla digits too).
class _PinField extends StatelessWidget {
  const _PinField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    this.errorText,
    this.action = TextInputAction.done,
    this.onSubmitted,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => LabeledField(
    fieldKey: fieldKey,
    label: label,
    controller: controller,
    errorText: errorText,
    obscureText: true,
    keyboardType: TextInputType.number,
    textInputAction: action,
    onSubmitted: onSubmitted,
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp('[0-9০-৯]')),
      LengthLimitingTextInputFormatter(appPinLength),
    ],
  );
}

/// The words of the phone's own unlock prompt.
DevicePromptText _promptText(AppLocalizations l) => DevicePromptText(
  title: l.lockPromptTitle,
  reason: l.lockDeviceReason,
  cancel: l.actionCancel,
);

/// Locked on a phone with a screen lock: the phone's own prompt opens it.
/// The prompt appears by itself once; the button asks again.
class DeviceUnlockScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DeviceUnlockScreen({super.key});

  @override
  ConsumerState<DeviceUnlockScreen> createState() => _DeviceUnlockState();
}

class _DeviceUnlockState extends ConsumerState<DeviceUnlockScreen> {
  bool _busy = false;
  DeviceUnlockResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_unlock());
    });
  }

  Future<void> _unlock() async {
    if (_busy) return;
    final text = _promptText(AppLocalizations.of(context));
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await ref
        .read(appLockProvider.notifier)
        .unlockWithDevice(text);
    if (mounted) {
      setState(() {
        _busy = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final message = switch (_result) {
      DeviceUnlockResult.cancelled ||
      DeviceUnlockResult.failed => l.lockDeviceCancelled,
      DeviceUnlockResult.lockedOut => l.lockDeviceLockedOut,
      _ => null,
    };
    return _LockFrame(
      title: l.lockTitle,
      body: l.lockDeviceBody,
      children: <Widget>[if (message != null) _Notice(message)],
      actions: <Widget>[
        PrimaryButton(
          label: l.lockUnlock,
          icon: LucideIcons.lockOpen,
          busy: _busy,
          onPressed: _unlock,
        ),
      ],
    );
  }
}

/// Locked on a phone without a screen lock: the app PIN opens it. Wrong PINs
/// are counted; after five, each try waits (see [AppLock]).
class PinUnlockScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockState();
}

class _PinUnlockState extends ConsumerState<PinUnlockScreen> {
  final TextEditingController _pin = TextEditingController();
  bool _busy = false;
  String? _fieldError;
  int? _triesLeft;
  DateTime? _waitUntil;
  int _seconds = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWait());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadWait() async {
    final until = await ref.read(appLockProvider.notifier).pinWaitUntil();
    if (mounted && until != null) _startWait(until);
  }

  void _startWait(DateTime until) {
    _ticker?.cancel();
    setState(() {
      _waitUntil = until;
      _triesLeft = null;
      _seconds = _secondsLeft();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final seconds = _secondsLeft();
      if (seconds == 0) {
        _ticker?.cancel();
        setState(() => _waitUntil = null);
      } else if (seconds != _seconds) {
        setState(() => _seconds = seconds); // The count goes down.
      }
    });
  }

  int _secondsLeft() {
    final until = _waitUntil;
    if (until == null) return 0;
    final left = until.difference(ref.read(nowProvider)());
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  Future<void> _unlock() async {
    final l = AppLocalizations.of(context);
    if (_busy || _waitUntil != null) return;
    if (normaliseAppPin(_pin.text) == null) {
      setState(() => _fieldError = l.pinNeedsSixDigits);
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
      _triesLeft = null;
    });
    final result = await ref
        .read(appLockProvider.notifier)
        .unlockWithPin(_pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case PinAccepted():
        break;
      case PinRejected(:final triesLeft):
        _pin.clear();
        setState(() => _triesLeft = triesLeft);
      case PinWait(:final until):
        _pin.clear();
        _startWait(until);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final waiting = _waitUntil != null;
    final seconds = _seconds;
    final String? message;
    if (waiting) {
      message = seconds > 90
          ? l.pinWaitMinutes((seconds / 60).ceil())
          : l.pinWaitSeconds(seconds);
    } else if (_triesLeft != null) {
      message = l.pinWrong(_triesLeft!);
    } else {
      message = null;
    }
    return _LockFrame(
      title: l.lockTitle,
      body: l.lockPinBody,
      children: <Widget>[
        const SizedBox(height: Spacing.space5),
        _PinField(
          fieldKey: const Key('pin-field'),
          label: l.pinLabel,
          controller: _pin,
          errorText: _fieldError,
          onSubmitted: (_) => _unlock(),
        ),
        if (message != null) _Notice(message),
        const SizedBox(height: Spacing.space4),
        PrimaryButton(
          label: l.pinForgot,
          variant: PrimaryButtonVariant.ghost,
          onPressed: _busy
              ? null
              : () => ref.read(appLockProvider.notifier).forgotPin(),
        ),
      ],
      actions: <Widget>[
        PrimaryButton(
          label: _busy ? l.pinChecking : l.lockUnlock,
          icon: LucideIcons.lockOpen,
          busy: _busy,
          onPressed: waiting ? null : _unlock,
        ),
      ],
    );
  }
}

/// Right after an online sign-in on a phone without a screen lock: choose
/// the 6-digit app PIN (typed twice).
class SetPinScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinState();
}

class _SetPinState extends ConsumerState<SetPinScreen> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();
  bool _busy = false;
  String? _firstError;
  String? _secondError;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_busy) return;
    final pin = normaliseAppPin(_first.text);
    final again = normaliseAppPin(_second.text);
    setState(() {
      _firstError = pin == null ? l.pinNeedsSixDigits : null;
      _secondError = pin != null && pin != again ? l.pinMismatch : null;
    });
    if (pin == null || pin != again) {
      if (pin != null) _second.clear();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(appLockProvider.notifier).choosePin(pin);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _LockFrame(
      title: l.pinSetTitle,
      body: l.pinSetBody,
      icon: LucideIcons.keyRound,
      children: <Widget>[
        const SizedBox(height: Spacing.space5),
        _PinField(
          fieldKey: const Key('new-pin-field'),
          label: l.pinNew,
          controller: _first,
          errorText: _firstError,
          action: TextInputAction.next,
        ),
        const SizedBox(height: Spacing.space5),
        _PinField(
          fieldKey: const Key('confirm-pin-field'),
          label: l.pinConfirm,
          controller: _second,
          errorText: _secondError,
          onSubmitted: (_) => _save(),
        ),
      ],
      actions: <Widget>[
        PrimaryButton(
          label: _busy ? l.pinSaving : l.pinSave,
          icon: LucideIcons.check,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// Sign in with the server while the data stays closed: after 30 days
/// offline, on a phone with no way to unlock, or when the PIN is forgotten.
/// Only the account that last signed in on this phone is accepted.
class OnlineSignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [reason].
  const OnlineSignInScreen({required this.reason, super.key});

  /// Why the person must sign in.
  final OnlineSignInReason reason;

  @override
  ConsumerState<OnlineSignInScreen> createState() => _OnlineSignInState();
}

class _OnlineSignInState extends ConsumerState<OnlineSignInScreen> {
  String? _host;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(appLockProvider.notifier).serverAddress().then((address) {
        if (mounted) setState(() => _host = address?.host);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final forgot = widget.reason == OnlineSignInReason.forgotPin;
    return SignInForm(
      host: _host,
      actions: _LockSignIn(ref),
      notice: switch (widget.reason) {
        OnlineSignInReason.expired => l.reSignInExpired,
        OnlineSignInReason.noUnlockMethod => l.reSignInNoLock,
        OnlineSignInReason.forgotPin => l.reSignInForgotPin,
      },
      secondaryLabel: forgot ? l.reSignInBack : null,
      onSecondary: forgot
          ? () => ref.read(appLockProvider.notifier).backToPin()
          : null,
    );
  }
}

/// The app lock's online sign-in, with the remembered server while the
/// data stays closed: every way ends in
/// [AppLockController.signInOnlineWith], which accepts only the account
/// that last used this phone.
class _LockSignIn implements SignInActions {
  _LockSignIn(this._ref);

  final WidgetRef _ref;

  AppLockController get _lock => _ref.read(appLockProvider.notifier);

  @override
  Future<SignInMethods> methods() =>
      _lock.withServer((server) => server.fetchSignInMethods());

  @override
  Future<void> withPassword(String email, String password) =>
      _lock.signInOnline(email: email, password: password);

  @override
  Future<PhoneCodeRequest> requestPhoneCode(String phone) =>
      _lock.withServer((server) => server.requestPhoneCode(phone));

  @override
  Future<void> withPhoneCode(PhoneCodeRequest request, String code) =>
      _lock.signInOnlineWith(
        (server) =>
            server.signInWithPhoneCode(codeId: request.codeId, code: code),
      );

  @override
  Future<void> withGoogle(SignInCancellation cancellation) {
    final browser = _ref.read(signInBrowserProvider);
    return _lock.signInOnlineWith(
      (server) => signInWithGoogleIn(server, browser, cancellation),
    );
  }
}
