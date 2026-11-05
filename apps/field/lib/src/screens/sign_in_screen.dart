import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/platform/sign_in_browser.dart';
import 'package:obhijatra_field/src/providers/app_lock_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/util/bangla.dart';
import 'package:obhijatra_field/src/widgets/labeled_field.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Sign in as a field user. Needs the internet once; after that the app
/// works offline.
class SignInScreen extends ConsumerWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return SignInForm(
      host: ref.watch(serverProvider).value?.address.host,
      actions: _SessionSignIn(ref),
      secondaryLabel: l.signInChangeServer,
      onSecondary: () => ref.read(serverProvider.notifier).forgetAddress(),
    );
  }
}

/// The first sign-in, on the saved server: every way ends in
/// [SessionNotifier.signInWith], which sets up the app lock.
class _SessionSignIn implements SignInActions {
  _SessionSignIn(this._ref);

  final WidgetRef _ref;

  /// The saved server, once its connection is ready.
  Future<ObhijatraServer> _server() async {
    final connection = await _ref.read(serverProvider.future);
    if (connection == null) {
      throw const ObhijatraException(ProblemCode.unknown);
    }
    return connection.server;
  }

  SessionNotifier get _session => _ref.read(sessionProvider.notifier);

  @override
  Future<SignInMethods> methods() async =>
      (await _server()).fetchSignInMethods();

  @override
  Future<void> withPassword(String email, String password) =>
      _session.signIn(email: email, password: password);

  @override
  Future<PhoneCodeRequest> requestPhoneCode(String phone) async =>
      (await _server()).requestPhoneCode(phone);

  @override
  Future<void> withPhoneCode(PhoneCodeRequest request, String code) =>
      _session.signInWith(
        (server) =>
            server.signInWithPhoneCode(codeId: request.codeId, code: code),
      );

  @override
  Future<void> withGoogle(SignInCancellation cancellation) {
    final browser = _ref.read(signInBrowserProvider);
    return _session.signInWith(
      (server) => signInWithGoogleIn(server, browser, cancellation),
    );
  }
}

/// What the sign-in form asks of the server. Each screen supplies its own:
/// the first sign-in, or the app lock's online sign-in. Every call throws
/// an [ObhijatraException] (or [WrongAccount]) when it does not work.
abstract interface class SignInActions {
  /// Which ways to sign in the server offers.
  Future<SignInMethods> methods();

  /// Signs in with an email address and password.
  Future<void> withPassword(String email, String password);

  /// Asks for a sign-in code by SMS to [phone] (international form).
  Future<PhoneCodeRequest> requestPhoneCode(String phone);

  /// Signs in with the [code] from the SMS of [request].
  Future<void> withPhoneCode(PhoneCodeRequest request, String code);

  /// Signs in with Google in a browser tab, until [cancellation].
  Future<void> withGoogle(SignInCancellation cancellation);
}

/// Why a sign-in did not work, in plain words.
@immutable
class SignInProblem {
  /// Creates the problem.
  const SignInProblem(this.message, {this.isConnection = false});

  /// The plain-language sentence for [code].
  factory SignInProblem.of(AppLocalizations l, ProblemCode code) =>
      SignInProblem(
        problemText(l, code),
        isConnection:
            code == ProblemCode.offline || code == ProblemCode.timeout,
      );

  /// What to tell the person.
  final String message;

  /// Whether it is about the connection (shown as information, not as a
  /// warning).
  final bool isConnection;
}

/// What to tell the person about [error]; `null` when they stopped the
/// sign-in themselves.
SignInProblem? signInProblemFor(AppLocalizations l, Object error) =>
    switch (error) {
      WrongAccount() => SignInProblem(l.reSignInWrongAccount),
      PasswordRequired(:final reason) => SignInProblem(
        reason == OnlineSignInReason.forgotPin
            ? l.reSignInPasswordForPin
            : l.reSignInPasswordForLock,
      ),
      ObhijatraException(code: ProblemCode.signInCancelled) => null,
      ObhijatraException(:final code) => SignInProblem.of(l, code),
      _ => SignInProblem.of(l, ProblemCode.unknown),
    };

/// The steps of the sign-in form.
enum _Step {
  /// Email and password.
  password,

  /// The mobile number, to send a code to.
  phone,

  /// The code from the SMS.
  code,
}

/// The sign-in form, used by the first sign-in and by the app lock's online
/// sign-in. It asks the server which ways to sign in it offers and shows
/// one clear way first: the mobile number when SMS codes are on (field
/// staff often have no email), otherwise email and password. The other
/// ways are quieter choices underneath.
class SignInForm extends StatefulWidget {
  /// Creates the form.
  const SignInForm({
    required this.actions,
    this.host,
    this.notice,
    this.secondaryLabel,
    this.onSecondary,
    this.passwordOnly = false,
    this.passwordOnlyNote,
    super.key,
  });

  /// Talks to the server.
  final SignInActions actions;

  /// The server's host name, shown at the top.
  final String? host;

  /// Why the person is asked to sign in, shown under the server.
  final String? notice;

  /// The words of the quiet button under the form.
  final String? secondaryLabel;

  /// What the quiet button does.
  final VoidCallback? onSecondary;

  /// Whether only email and password are offered, whatever else the server
  /// offers (the app lock decides; see `AppLockController.passwordOnly`).
  final bool passwordOnly;

  /// Said when [passwordOnly] hides other ways the server offers, for
  /// people whose account has no password.
  final String? passwordOnlyNote;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  /// What the server offers; `null` while loading or when it could not be
  /// checked (then email and password are shown).
  SignInMethods? _methods;
  bool _loadingMethods = true;

  /// Why the ways to sign in could not be checked.
  Object? _methodsError;

  _Step _step = _Step.password;
  bool _show = false;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;
  String? _phoneError;
  String? _codeError;

  /// What went wrong with the last try, shown in plain words.
  Object? _error;

  /// The code request of the code step.
  PhoneCodeRequest? _request;

  /// Whether a new code was sent (only the newest works).
  bool _newCodeSent = false;

  /// Seconds until a new code may be asked for.
  int _newCodeIn = 0;
  Timer? _countdown;

  /// Set while Google's page is open.
  SignInCancellation? _google;

  bool get _offersPhone => !widget.passwordOnly && (_methods?.phone ?? false);
  bool get _offersGoogle => !widget.passwordOnly && (_methods?.google ?? false);

  /// Whether the server offers ways that [SignInForm.passwordOnly] hides.
  bool get _hidesWays =>
      widget.passwordOnly &&
      ((_methods?.phone ?? false) || (_methods?.google ?? false));
  bool get _offersPassword => _methods?.password ?? true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMethods());
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _google?.cancel();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await widget.actions.methods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _methodsError = null;
        _loadingMethods = false;
        _step = methods.phone && !widget.passwordOnly
            ? _Step.phone
            : _Step.password;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _methodsError = e;
        _loadingMethods = false;
      });
    }
  }

  void _retryMethods() {
    setState(() {
      _loadingMethods = true;
      _methodsError = null;
    });
    unawaited(_loadMethods());
  }

  /// Runs [body] with the form busy; returns what went wrong, if anything,
  /// after showing it.
  Future<Object?> _run(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
      return null;
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
      return e;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _go(_Step step) {
    if (_busy) return;
    setState(() {
      _step = step;
      _error = null;
      _emailError = null;
      _passwordError = null;
      _phoneError = null;
      _codeError = null;
    });
  }

  // ---- Email and password ------------------------------------------------

  Future<void> _signInWithPassword() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final emailMissing = _email.text.trim().isEmpty;
    final passwordMissing = _password.text.isEmpty;
    setState(() {
      _emailError = emailMissing ? l.signInEmptyEmail : null;
      _passwordError = passwordMissing ? l.signInEmptyPassword : null;
      _error = null;
    });
    if (emailMissing || passwordMissing) return;
    await _run(() => widget.actions.withPassword(_email.text, _password.text));
  }

  // ---- SMS code ----------------------------------------------------------

  Future<void> _sendCode() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final number = parsePhoneNumber(_phone.text);
    setState(() {
      _phoneError = switch (number.issue) {
        null => null,
        PhoneNumberIssue.empty => l.signInPhoneEmpty,
        _ => l.signInPhoneInvalid,
      };
      _error = null;
    });
    final phone = number.e164;
    if (phone == null) return;
    await _run(() async {
      final request = await widget.actions.requestPhoneCode(phone);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _request = request;
        _step = _Step.code;
        _newCodeSent = false;
        _codeError = null;
      });
      _startCountdown(request.resendAfter);
    });
  }

  Future<void> _sendNewCode() async {
    final request = _request;
    if (_busy || request == null || _newCodeIn > 0) return;
    await _run(() async {
      final next = await widget.actions.requestPhoneCode(request.phone);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _request = next;
        _newCodeSent = true;
        _codeError = null;
      });
      _startCountdown(next.resendAfter);
      _codeFocus.requestFocus();
    });
  }

  void _startCountdown(Duration wait) {
    _countdown?.cancel();
    setState(() => _newCodeIn = wait.inSeconds);
    if (_newCodeIn <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _newCodeIn <= 1) timer.cancel();
      if (mounted) setState(() => _newCodeIn--);
    });
  }

  void _changeNumber() {
    if (_busy) return;
    _countdown?.cancel();
    _code.clear();
    setState(() {
      _request = null;
      _newCodeIn = 0;
      _newCodeSent = false;
    });
    _go(_Step.phone);
  }

  /// The digits typed in the code field, as `0` to `9`.
  String get _typedCode =>
      toAsciiDigits(_code.text).replaceAll(RegExp('[^0-9]'), '');

  void _codeChanged(String _) {
    if (_codeError != null) setState(() => _codeError = null);
    // Six digits typed or filled in from the SMS: sign in at once.
    if (_typedCode.length == phoneCodeLength) unawaited(_verifyCode());
  }

  Future<void> _verifyCode() async {
    final request = _request;
    if (_busy || request == null) return;
    final code = _typedCode;
    if (code.length != phoneCodeLength) {
      setState(() {
        _codeError = AppLocalizations.of(context).signInCodeIncomplete;
        _error = null;
      });
      return;
    }
    final error = await _run(() => widget.actions.withPhoneCode(request, code));
    if (!mounted) return;
    if (error is ObhijatraException &&
        error.code == ProblemCode.signInCodeWrong) {
      // Ready for the code to be typed again.
      _code.clear();
      _codeFocus.requestFocus();
    }
  }

  // ---- Google ------------------------------------------------------------

  Future<void> _signInWithGoogle() async {
    if (_busy || _google != null) return;
    final cancellation = SignInCancellation();
    setState(() {
      _google = cancellation;
      _error = null;
    });
    try {
      await widget.actions.withGoogle(cancellation);
    } on Object catch (e) {
      if (mounted && !cancellation.isCancelled) setState(() => _error = e);
    } finally {
      if (mounted && identical(_google, cancellation)) {
        setState(() => _google = null);
      }
    }
  }

  void _cancelGoogle() => _google?.cancel();

  // ---- Screen ------------------------------------------------------------

  /// Android's back button steps back inside the form instead of leaving.
  void _back() {
    if (_google != null) {
      _cancelGoogle();
    } else if (_step == _Step.code) {
      _changeNumber();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final waitingForGoogle = _google != null;
    final error = _error;
    final problem = error == null ? null : signInProblemFor(l, error);
    final methodsError = _methodsError;
    final methodsProblem = methodsError == null
        ? null
        : signInProblemFor(l, methodsError) ??
              SignInProblem.of(l, ProblemCode.unknown);
    final children = <Widget>[
      ..._header(context),
      if (_loadingMethods)
        _Checking(text: l.signInCheckingMethods)
      else if (waitingForGoogle)
        _GoogleWaiting(l: l)
      else ...<Widget>[
        if (methodsProblem != null) ...<Widget>[
          _ProblemPanel(problem: methodsProblem, lead: l.signInMethodsFailed),
          const SizedBox(height: Spacing.space2),
          PrimaryButton(
            label: l.actionTryAgain,
            icon: LucideIcons.refreshCw,
            variant: PrimaryButtonVariant.ghost,
            onPressed: _busy ? null : _retryMethods,
          ),
          const SizedBox(height: Spacing.space4),
        ],
        ...switch (_step) {
          _Step.password => _passwordStep(context),
          _Step.phone => _phoneStep(context),
          _Step.code => _codeStep(context, problem),
        },
        // In the code step it sits under the code field (see _codeStep).
        if (problem != null && _step != _Step.code) ...<Widget>[
          const SizedBox(height: Spacing.space4),
          _ProblemPanel(problem: problem),
        ],
        if (widget.passwordOnlyNote case final note? when _hidesWays) ...[
          const SizedBox(height: Spacing.space4),
          _Note(text: note),
        ],
        ..._otherWays(l),
      ],
      if (widget.secondaryLabel != null && !waitingForGoogle) ...<Widget>[
        const SizedBox(height: Spacing.space4),
        PrimaryButton(
          label: widget.secondaryLabel!,
          variant: PrimaryButtonVariant.ghost,
          onPressed: _busy ? null : widget.onSecondary,
        ),
      ],
    ];

    return PopScope(
      canPop: !waitingForGoogle && _step != _Step.code,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ScreenFrame(
        topBar: TopBar(title: l.signInTitle),
        body: ListView(
          padding: const EdgeInsets.all(Spacing.space4),
          children: children,
        ),
        bottom: _loadingMethods ? null : _bottom(l, waitingForGoogle),
      ),
    );
  }

  List<Widget> _header(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final host = widget.host;
    return <Widget>[
      if (host != null)
        Panel(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space4,
            vertical: Spacing.space3,
          ),
          child: Row(
            children: <Widget>[
              Icon(LucideIcons.server, color: p.action),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: Text(
                  l.signInServer(host),
                  style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      if (widget.notice != null) ...<Widget>[
        const SizedBox(height: Spacing.space4),
        Panel(
          color: p.infoSubtle,
          borderColor: p.info,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: Icon(LucideIcons.lock, color: p.info),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(child: Text(widget.notice!, style: text.bodyMedium)),
            ],
          ),
        ),
      ],
      const SizedBox(height: Spacing.space4),
      Text(
        l.signInNeedsInternet,
        style: text.bodyMedium!.copyWith(color: p.textMuted),
      ),
      const SizedBox(height: Spacing.space5),
    ];
  }

  List<Widget> _passwordStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    return <Widget>[
      LabeledField(
        fieldKey: const Key('email-field'),
        label: l.signInEmail,
        controller: _email,
        errorText: _emailError,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const <String>[
          AutofillHints.username,
          AutofillHints.email,
        ],
      ),
      const SizedBox(height: Spacing.space5),
      LabeledField(
        fieldKey: const Key('password-field'),
        label: l.signInPassword,
        controller: _password,
        errorText: _passwordError,
        obscureText: !_show,
        textInputAction: TextInputAction.done,
        autofillHints: const <String>[AutofillHints.password],
        onSubmitted: (_) => _signInWithPassword(),
        suffix: IconButton(
          tooltip: _show ? l.signInHidePassword : l.signInShowPassword,
          icon: Icon(_show ? LucideIcons.eyeOff : LucideIcons.eye),
          constraints: const BoxConstraints(
            minWidth: Sizes.touch,
            minHeight: Sizes.touch,
          ),
          onPressed: () => setState(() => _show = !_show),
        ),
      ),
    ];
  }

  List<Widget> _phoneStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    return <Widget>[
      LabeledField(
        fieldKey: const Key('phone-field'),
        label: l.signInPhone,
        help: l.signInPhoneHelp,
        controller: _phone,
        errorText: _phoneError,
        prefix: '+$bangladeshCallingCode',
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.send,
        autofillHints: const <String>[AutofillHints.telephoneNumberNational],
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯+\-\s().]')),
          LengthLimitingTextInputFormatter(20),
        ],
        onSubmitted: (_) => _sendCode(),
      ),
    ];
  }

  /// The code step; [problem] is shown right under the code field, where
  /// the person is looking, with the keyboard open.
  List<Widget> _codeStep(BuildContext context, SignInProblem? problem) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final request = _request!;
    final bangla = Localizations.localeOf(context).languageCode == 'bn';
    final shown = formatPhoneNumber(request.phone);
    return <Widget>[
      Semantics(
        header: true,
        child: Text(l.signInCodeTitle, style: text.titleMedium),
      ),
      const SizedBox(height: Spacing.space2),
      Text(
        l.signInCodeSent(bangla ? toBanglaDigits(shown) : shown),
        style: text.bodyMedium,
      ),
      const SizedBox(height: Spacing.space2),
      Text(l.signInCodeFrom, style: text.bodyMedium),
      if (_newCodeSent) ...<Widget>[
        const SizedBox(height: Spacing.space3),
        Panel(
          color: p.infoSubtle,
          borderColor: p.info,
          child: Semantics(
            liveRegion: true,
            child: Text(l.signInCodeNew, style: text.bodyMedium),
          ),
        ),
      ],
      const SizedBox(height: Spacing.space5),
      LabeledField(
        fieldKey: const Key('code-field'),
        label: l.signInCode,
        controller: _code,
        focusNode: _codeFocus,
        autofocus: true,
        errorText: _codeError,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofillHints: const <String>[AutofillHints.oneTimeCode],
        textAlign: TextAlign.center,
        style: text.headlineSmall!.copyWith(
          letterSpacing: Spacing.space2,
          fontWeight: FontWeight.w600,
        ),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp('[0-9০-৯]')),
          LengthLimitingTextInputFormatter(phoneCodeLength),
        ],
        onChanged: _codeChanged,
        onSubmitted: (_) => _verifyCode(),
      ),
      if (problem != null) ...<Widget>[
        const SizedBox(height: Spacing.space3),
        _ProblemPanel(problem: problem),
      ],
      const SizedBox(height: Spacing.space4),
      PrimaryButton(
        key: const Key('new-code-button'),
        label: l.signInNewCode,
        icon: LucideIcons.messageSquare,
        variant: PrimaryButtonVariant.secondary,
        onPressed: _busy || _newCodeIn > 0 ? null : _sendNewCode,
      ),
      if (_newCodeIn > 0) ...<Widget>[
        const SizedBox(height: Spacing.space2),
        Text(
          l.signInNewCodeIn(_newCodeIn),
          key: const Key('new-code-countdown'),
          textAlign: TextAlign.center,
          style: text.bodySmall!.copyWith(color: p.textMuted),
        ),
      ],
      const SizedBox(height: Spacing.space2),
      PrimaryButton(
        label: l.signInChangeNumber,
        variant: PrimaryButtonVariant.ghost,
        onPressed: _busy ? null : _changeNumber,
      ),
    ];
  }

  /// The quieter choices under the main way: the other ways the server
  /// offers, as plain words (no logos). None while a code is being entered.
  List<Widget> _otherWays(AppLocalizations l) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final ways = <Widget>[
      if (_step != _Step.phone && _step != _Step.code && _offersPhone)
        PrimaryButton(
          label: l.signInUsePhone,
          variant: PrimaryButtonVariant.secondary,
          onPressed: _busy ? null : () => _go(_Step.phone),
        ),
      if (_step != _Step.code && _offersGoogle)
        PrimaryButton(
          label: l.signInWithGoogle,
          variant: PrimaryButtonVariant.secondary,
          onPressed: _busy ? null : _signInWithGoogle,
        ),
      if (_step != _Step.password && _step != _Step.code && _offersPassword)
        PrimaryButton(
          label: l.signInUseEmail,
          variant: PrimaryButtonVariant.secondary,
          onPressed: _busy ? null : () => _go(_Step.password),
        ),
    ];
    if (ways.isEmpty) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: Spacing.space5),
      Divider(height: 1, color: p.border),
      const SizedBox(height: Spacing.space4),
      Semantics(
        header: true,
        child: Text(
          l.signInOtherWays,
          style: text.bodyMedium!.copyWith(
            color: p.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: Spacing.space3),
      for (var i = 0; i < ways.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: Spacing.space2),
        ways[i],
      ],
    ];
  }

  Widget _bottom(AppLocalizations l, bool waitingForGoogle) {
    if (waitingForGoogle) {
      return BottomActions(
        children: <Widget>[
          PrimaryButton(
            label: l.actionCancel,
            icon: LucideIcons.x,
            variant: PrimaryButtonVariant.secondary,
            onPressed: _cancelGoogle,
          ),
        ],
      );
    }
    final button = switch (_step) {
      _Step.password => PrimaryButton(
        label: _busy ? l.signInWorking : l.signInTitle,
        icon: LucideIcons.logIn,
        busy: _busy,
        onPressed: _signInWithPassword,
      ),
      _Step.phone => PrimaryButton(
        label: _busy ? l.signInSendingCode : l.signInSendCode,
        icon: LucideIcons.send,
        busy: _busy,
        onPressed: _sendCode,
      ),
      _Step.code => PrimaryButton(
        label: _busy ? l.signInWorking : l.signInTitle,
        icon: LucideIcons.logIn,
        busy: _busy,
        onPressed: _verifyCode,
      ),
    };
    return BottomActions(children: <Widget>[button]);
  }
}

/// A plain information note, spoken when it appears.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Panel(
      color: p.infoSubtle,
      borderColor: p.info,
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
                child: Icon(LucideIcons.info, color: p.info),
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

/// A quiet line with a progress ring, while something is checked.
class _Checking extends StatelessWidget {
  const _Checking({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Google's page is open in the browser: what to do there.
class _GoogleWaiting extends StatelessWidget {
  const _GoogleWaiting({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Panel(
      color: p.infoSubtle,
      borderColor: p.info,
      child: Semantics(
        liveRegion: true,
        container: true,
        label: '${l.signInGoogleWaiting} ${l.signInGoogleWaitingHelp}',
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: SizedBox.square(
                  dimension: Sizes.icon,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: p.info,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.signInGoogleWaiting, style: text.titleSmall),
                    const SizedBox(height: Spacing.space1),
                    Text(l.signInGoogleWaitingHelp, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A problem in plain words; spoken when it appears. Connection problems
/// are shown as information, the others as a warning.
class _ProblemPanel extends StatelessWidget {
  const _ProblemPanel({required this.problem, this.lead});

  final SignInProblem problem;

  /// A sentence before the problem, if any.
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final connection = problem.isConnection;
    final spoken = lead == null ? problem.message : '$lead ${problem.message}';
    return Panel(
      color: connection ? p.infoSubtle : p.warningSubtle,
      borderColor: connection ? p.info : p.warning,
      child: Semantics(
        liveRegion: true,
        container: true,
        label: spoken,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (lead != null) ...<Widget>[
                      Text(
                        lead!,
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Spacing.space1),
                    ],
                    Text(problem.message, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
