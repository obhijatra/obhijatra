import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/phone_number.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/widgets/phone_number_field.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Digits in a sign-in code.
const int smsCodeLength = 6;

/// Wrong entries a code allows before it stops working (the server's rule).
const int smsCodeTries = 3;

/// Sign in with a code sent by SMS: the number, then the code.
///
/// Nothing on screen says whether a number has an account: the server
/// answers every request for a code the same way, and so does this.
class SmsSignIn extends ConsumerStatefulWidget {
  /// Creates the steps. [onBack] returns to the other ways to sign in.
  const SmsSignIn({required this.onBack, super.key});

  /// Goes back to the main sign-in screen.
  final VoidCallback onBack;

  @override
  ConsumerState<SmsSignIn> createState() => _SmsSignInState();
}

class _SmsSignInState extends ConsumerState<SmsSignIn> {
  final _number = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  PhoneCodeRequest? _request;
  Timer? _ticker;
  int _elapsed = 0; // seconds since the code was asked for
  int _wrongTries = 0;
  bool _busy = false;
  bool _resent = false;
  String? _numberError;
  String? _codeError;
  AppProblem? _problem;

  @override
  void dispose() {
    _ticker?.cancel();
    _number.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _expired {
    final request = _request;
    return request != null && _elapsed >= request.expiresIn.inSeconds;
  }

  bool get _usedUp => _wrongTries >= smsCodeTries;

  int get _waitBeforeResend {
    final request = _request;
    if (request == null) return 0;
    return (request.resendAfter.inSeconds - _elapsed).clamp(0, 1 << 20);
  }

  void _startTicker() {
    _ticker?.cancel();
    _elapsed = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsed++);
      // Nothing changes on screen once the code has expired and a new one
      // may be asked for.
      if (_expired && _waitBeforeResend == 0) timer.cancel();
    });
  }

  Future<void> _send({bool again = false}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final phone = again ? _request?.phone : normalisePhone(_number.text);
    if (phone == null) {
      setState(() => _numberError = l10n.smsNumberInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _numberError = null;
      _problem = null;
    });
    try {
      final request = await trackedUi(
        ref,
        () => ref.read(apiProvider).requestPhoneCode(phone),
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _wrongTries = 0;
        _codeError = null;
        _resent = again;
        _code.clear();
        _startTicker();
      });
      _codeFocus.requestFocus();
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        if (problem.kind == ProblemKind.phoneInvalid && !again) {
          _numberError = l10n.smsNumberInvalid;
        } else {
          _problem = problem;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final request = _request;
    final code = _code.text;
    if (request == null || _busy || _expired || _usedUp) return;
    if (code.length != smsCodeLength) {
      setState(
        () => _codeError = AppLocalizations.of(context).smsCodeIncomplete,
      );
      return;
    }
    setState(() {
      _busy = true;
      _codeError = null;
      _problem = null;
      _resent = false;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .signInWithPhoneCode(request.codeId, code);
      // Signed in: the app now shows the main screen instead of this one.
    } on AppProblem catch (problem) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        if (problem.kind == ProblemKind.codeWrong) {
          _wrongTries++;
          _codeError = _usedUp ? l10n.smsCodeUsedUp : l10n.smsCodeWrong;
          _code.clear();
        } else {
          _problem = problem;
        }
      });
      if (!_usedUp) _codeFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeNumber() {
    _ticker?.cancel();
    setState(() {
      _request = null;
      _problem = null;
      _codeError = null;
      _resent = false;
    });
  }

  void _onProblemAction() {
    final problem = _problem;
    if (problem == null) return;
    if (problem.action == ProblemAction.tryAgain) {
      if (_request == null) {
        unawaited(_send());
      } else {
        unawaited(_verify());
      }
    } else {
      setState(() => _problem = null);
    }
  }

  @override
  Widget build(BuildContext context) =>
      _request == null ? _numberStep(context) : _codeStep(context);

  Widget _heading(BuildContext context, String title) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _backLink(AppLocalizations l10n) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      onPressed: _busy ? null : widget.onBack,
      icon: const Icon(Icons.arrow_back),
      label: Text(l10n.signInOtherWays),
    ),
  );

  List<Widget> _problemBanner() => <Widget>[
    if (_problem != null) ...<Widget>[
      const SizedBox(height: Spacing.space4),
      ProblemBanner(problem: _problem!, onAction: _onProblemAction),
    ],
  ];

  Widget _numberStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium!.copyWith(color: context.palette.textMuted);
    return Column(
      key: const ValueKey<String>('sms-number'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, l10n.signInSms),
        const SizedBox(height: Spacing.space2),
        Text(l10n.smsNumberIntro, style: muted),
        const SizedBox(height: Spacing.space1),
        Text(l10n.signInSmsAdminNote, style: muted),
        const SizedBox(height: Spacing.space5),
        PhoneNumberField(
          controller: _number,
          label: l10n.smsNumberLabel,
          helper: l10n.smsNumberHelp,
          errorText: _numberError,
          autofocus: true,
          enabled: !_busy,
          onChanged: (_) {
            if (_numberError != null) setState(() => _numberError = null);
          },
          onSubmitted: (_) => _send(),
        ),
        ..._problemBanner(),
        const SizedBox(height: Spacing.space5),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? l10n.actionSending : l10n.smsSendCode),
        ),
        const SizedBox(height: Spacing.space3),
        _backLink(l10n),
      ],
    );
  }

  Widget _codeStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final request = _request!;
    final muted = text.bodyMedium!.copyWith(color: palette.textMuted);
    final wait = _waitBeforeResend;
    final countdown = '${wait ~/ 60}:${(wait % 60).toString().padLeft(2, '0')}';
    final error = _expired && !_usedUp ? l10n.smsCodeExpired : _codeError;
    final canSubmit = !_busy && !_expired && !_usedUp;
    return Column(
      key: const ValueKey<String>('sms-code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, l10n.smsCodeTitle),
        const SizedBox(height: Spacing.space2),
        Text(l10n.smsCodeSent(displayPhone(request.phone)), style: muted),
        const SizedBox(height: Spacing.space1),
        Text(
          l10n.smsCodeLifetime(
            (request.expiresIn.inSeconds / 60).ceil().clamp(1, 60),
          ),
          style: muted,
        ),
        const SizedBox(height: Spacing.space5),
        TextField(
          controller: _code,
          focusNode: _codeFocus,
          autofocus: true,
          readOnly: _busy || _usedUp,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.oneTimeCode],
          inputFormatters: const <TextInputFormatter>[_CodeFormatter()],
          textAlign: TextAlign.center,
          // Numbers are set in Noto Sans, large and evenly spaced.
          style: text.bodyLarge!.copyWith(
            fontSize: 24,
            height: 32 / 24,
            letterSpacing: Spacing.space2,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            labelText: l10n.smsCodeLabel,
            errorText: error,
            errorMaxLines: 3,
          ),
          onChanged: (value) {
            // A new try: the message about the last one no longer applies.
            if (_codeError != null && !_usedUp && value.isNotEmpty) {
              setState(() => _codeError = null);
            }
            if (value.length == smsCodeLength) unawaited(_verify());
          },
          onSubmitted: (_) => _verify(),
        ),
        if (_resent && error == null) ...<Widget>[
          const SizedBox(height: Spacing.space2),
          Semantics(
            liveRegion: true,
            child: Text(l10n.smsNewCodeSent, style: muted),
          ),
        ],
        ..._problemBanner(),
        const SizedBox(height: Spacing.space5),
        FilledButton(
          onPressed: canSubmit ? _verify : null,
          child: Text(_busy ? l10n.smsCodeChecking : l10n.signInButton),
        ),
        const SizedBox(height: Spacing.space3),
        Wrap(
          spacing: Spacing.space2,
          runSpacing: Spacing.space1,
          children: <Widget>[
            TextButton(
              onPressed: _busy || wait > 0 ? null : () => _send(again: true),
              child: Text(
                wait > 0 ? l10n.smsResendIn(countdown) : l10n.smsResend,
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _changeNumber,
              child: Text(l10n.smsChangeNumber),
            ),
          ],
        ),
        _backLink(l10n),
      ],
    );
  }
}

/// Keeps digits only (Bangla digits become 0 to 9), at most six, so a
/// pasted message such as "Your code is ১২৩৪৫৬" still works.
class _CodeFormatter extends TextInputFormatter {
  const _CodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = latinDigits(newValue.text).replaceAll(RegExp('[^0-9]'), '');
    if (digits.length > smsCodeLength) {
      digits = digits.substring(0, smsCodeLength);
    }
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
