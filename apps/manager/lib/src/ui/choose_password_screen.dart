import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/widgets/brand_mark.dart';
import 'package:obhijatra_manager/widgets/language_switch.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The fewest characters a password may have (the server's own minimum).
const int minPasswordLength = 12;

// The server's names for the fields it can refuse.
const String _kCurrent = 'oldPassword';
const String _kNew = 'password';
const String _kRepeat = 'passwordConfirm';

/// Shown instead of the app when the person signed in with a one-time
/// password: they choose their own, are signed in again with it, and carry
/// on. Signing out is always possible.
class ChoosePasswordScreen extends ConsumerStatefulWidget {
  /// Creates the step.
  const ChoosePasswordScreen({super.key});

  @override
  ConsumerState<ChoosePasswordScreen> createState() =>
      _ChoosePasswordScreenState();
}

class _ChoosePasswordScreenState extends ConsumerState<ChoosePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();

  /// The one-time password the person just typed to sign in, if any.
  String? _typed;

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _busy = false;
  AppProblem? _problem;
  Map<String, String> _errors = <String, String>{};

  /// Whether the one-time password must be typed here.
  bool get _asksForCurrent => _typed == null;

  @override
  void initState() {
    super.initState();
    _typed = ref.read(typedOneTimePasswordProvider);
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  String get _currentPassword => _typed ?? _current.text;

  /// The problems the person can fix before anything is sent.
  Map<String, String> _check(AppLocalizations l10n) {
    final errors = <String, String>{};
    if (_asksForCurrent && _current.text.isEmpty) {
      errors[_kCurrent] = l10n.fieldRequired;
    }
    final chosen = _new.text;
    if (chosen.isEmpty) {
      errors[_kNew] = l10n.fieldRequired;
    } else if (chosen.length < minPasswordLength) {
      errors[_kNew] = l10n.choosePasswordTooShort;
    } else if (chosen == _currentPassword) {
      errors[_kNew] = l10n.choosePasswordSame;
    }
    if (!errors.containsKey(_kNew) && _repeat.text != chosen) {
      errors[_kRepeat] = l10n.choosePasswordMismatch;
    }
    return errors;
  }

  /// The server's refusals, in the screen's own words where it knows them.
  Map<String, String> _serverErrors(AppLocalizations l10n, AppProblem p) => {
    for (final entry in p.fields.entries)
      entry.key: switch ((entry.key, p.codes[entry.key])) {
        (_kCurrent, _) => l10n.choosePasswordWrongCurrent,
        (_kRepeat, 'validation_values_mismatch') => l10n.choosePasswordMismatch,
        _ when entry.value.isNotEmpty => entry.value,
        _ => l10n.problemRejected,
      },
  };

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errors = _check(l10n);
    setState(() {
      _errors = errors;
      _problem = null;
    });
    if (errors.isNotEmpty) {
      (errors.containsKey(_kCurrent) ? _currentFocus : _newFocus)
          .requestFocus();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .chooseNewPassword(
            currentPassword: _currentPassword,
            newPassword: _new.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.choosePasswordSaved)));
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        _problem = problem;
        _errors = _serverErrors(l10n, problem);
        // The password typed to sign in was refused: ask for it here.
        if (_errors.containsKey(_kCurrent) && _typed != null) {
          _typed = null;
          _current.clear();
        }
      });
      if (_errors.containsKey(_kCurrent)) _currentFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signOut() => ref.read(sessionProvider.notifier).signOut();

  void _onProblemAction() {
    final problem = _problem;
    if (problem == null) return;
    switch (problem.action) {
      case ProblemAction.signInAgain:
        _signOut();
      case ProblemAction.tryAgain:
        unawaited(_submit());
      case ProblemAction.close || ProblemAction.chooseFile:
        setState(() => _problem = null);
    }
  }

  void _edited(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  /// Field problems the screen has no field for.
  List<String> get _unplaced => <String>[
    for (final entry in _errors.entries)
      if (entry.key != _kCurrent && entry.key != _kNew && entry.key != _kRepeat)
        entry.value,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final user = ref.watch(sessionProvider);
    final who = user == null
        ? ''
        : (user.email.isNotEmpty ? user.email : user.displayName);
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
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ObPanel(
                      padding: const EdgeInsets.all(Spacing.space6),
                      child: AutofillGroup(
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
                                      l10n.choosePasswordTitle,
                                      style: text.headlineMedium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Spacing.space2),
                            Text(
                              l10n.choosePasswordIntro,
                              style: text.bodyMedium!.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                            if (who.isNotEmpty) ...<Widget>[
                              const SizedBox(height: Spacing.space3),
                              Text(
                                l10n.choosePasswordAccount(who),
                                style: text.labelLarge,
                              ),
                            ],
                            const SizedBox(height: Spacing.space5),
                            if (_asksForCurrent) ...<Widget>[
                              _PasswordField(
                                fieldKey: const ValueKey<String>(
                                  'current-password',
                                ),
                                controller: _current,
                                focusNode: _currentFocus,
                                label: l10n.choosePasswordCurrent,
                                helper: l10n.choosePasswordCurrentHelp,
                                error: _errors[_kCurrent],
                                hidden: _hideCurrent,
                                autofill: AutofillHints.password,
                                onToggle: () => setState(
                                  () => _hideCurrent = !_hideCurrent,
                                ),
                                onChanged: () => _edited(_kCurrent),
                              ),
                              const SizedBox(height: Spacing.space4),
                            ],
                            _PasswordField(
                              fieldKey: const ValueKey<String>('new-password'),
                              controller: _new,
                              focusNode: _newFocus,
                              label: l10n.choosePasswordNew,
                              helper: l10n.choosePasswordHint,
                              error: _errors[_kNew],
                              hidden: _hideNew,
                              autofocus: !_asksForCurrent,
                              autofill: AutofillHints.newPassword,
                              onToggle: () =>
                                  setState(() => _hideNew = !_hideNew),
                              onChanged: () => _edited(_kNew),
                            ),
                            const SizedBox(height: Spacing.space4),
                            _PasswordField(
                              fieldKey: const ValueKey<String>(
                                'repeat-password',
                              ),
                              controller: _repeat,
                              label: l10n.choosePasswordRepeat,
                              error: _errors[_kRepeat],
                              hidden: _hideNew,
                              autofill: AutofillHints.newPassword,
                              onToggle: () =>
                                  setState(() => _hideNew = !_hideNew),
                              onChanged: () => _edited(_kRepeat),
                              onSubmitted: _submit,
                            ),
                            if (_problem != null) ...<Widget>[
                              const SizedBox(height: Spacing.space4),
                              ProblemBanner(
                                problem: _problem!,
                                onAction: _onProblemAction,
                              ),
                              for (final message in _unplaced)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: Spacing.space2,
                                  ),
                                  child: Text(
                                    message,
                                    style: text.bodySmall!.copyWith(
                                      color: palette.danger,
                                    ),
                                  ),
                                ),
                            ],
                            const SizedBox(height: Spacing.space5),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(
                                _busy
                                    ? l10n.actionSaving
                                    : l10n.choosePasswordSave,
                              ),
                            ),
                            const SizedBox(height: Spacing.space3),
                            TextButton.icon(
                              onPressed: _busy ? null : _signOut,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// A hidden password field with a button that shows what was typed.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.hidden,
    required this.autofill,
    required this.onToggle,
    required this.onChanged,
    this.focusNode,
    this.helper,
    this.error,
    this.autofocus = false,
    this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? helper;
  final String? error;
  final bool hidden;
  final bool autofocus;
  final String autofill;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final Future<void> Function()? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: <String>[autofill],
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        errorText: error,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          tooltip: hidden ? l10n.signInShowPassword : l10n.signInHidePassword,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
