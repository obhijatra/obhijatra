import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/widgets/labeled_field.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The full-screen step in which a person replaces the one-time password an
/// organisation admin gave them with their own (at least
/// [minPasswordLength] characters, typed twice).
///
/// Shown right after a sign-in with a one-time password, before the app
/// lock is set up or the data opens, and from the Today screen when sending
/// stopped because of one ([openPasswordChange]).
class ChangePasswordScreen extends StatefulWidget {
  /// Creates the step.
  const ChangePasswordScreen({
    required this.onSave,
    required this.onSignOut,
    this.currentPassword,
    this.onBack,
    super.key,
  });

  /// Chooses the new password in place of the current one, then carries on
  /// as the sign-in would have. Throws an [ObhijatraException] when it does
  /// not work.
  final Future<void> Function(String currentPassword, String newPassword)
  onSave;

  /// Leaves without a new password, back to signing in.
  final VoidCallback onSignOut;

  /// The one-time password the person has just typed to sign in: it is not
  /// asked for again (unless the server says it is wrong).
  final String? currentPassword;

  /// Goes back without changing anything; `null` shows no back button.
  final VoidCallback? onBack;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _repeat = TextEditingController();

  /// Whether the one-time password is asked for on this screen.
  late bool _askCurrent = widget.currentPassword == null;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showRepeat = false;
  bool _busy = false;
  String? _currentError;
  String? _newError;
  String? _repeatError;

  /// What went wrong with the last try, other than a field.
  ProblemCode? _problem;

  /// Whether the one-time session has ended (the new password may already
  /// be saved): only signing in again helps.
  bool get _mustSignInAgain =>
      _problem == ProblemCode.passwordChangedSignInAgain ||
      _problem == ProblemCode.signInRequired;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _mustSignInAgain) return;
    final l = AppLocalizations.of(context);
    final current = _askCurrent ? _current.text : widget.currentPassword!;
    final password = _new.text;
    final length = password.runes.length;
    setState(() {
      _problem = null;
      _currentError = current.isEmpty ? l.passwordChangeCurrentEmpty : null;
      _newError = length < minPasswordLength
          ? l.passwordChangeTooShort
          : length > maxPasswordLength
          ? l.passwordChangeTooLong
          : password == current
          ? l.passwordChangeSameAsOld
          : null;
      _repeatError = _newError == null && _repeat.text != password
          ? l.passwordChangeMismatch
          : null;
    });
    if (_repeatError != null) _repeat.clear();
    if (_currentError != null || _newError != null || _repeatError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSave(current, password);
    } on ObhijatraException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case ProblemCode.currentPasswordWrong:
            // Ask for it, even if it was the one just used to sign in.
            _askCurrent = true;
            _current.clear();
            _currentError = problemText(l, e.code);
          case ProblemCode.newPasswordInvalid:
            _newError = problemText(l, e.code);
          default:
            _problem = e.code;
        }
      });
    } on Object {
      if (mounted) setState(() => _problem = ProblemCode.unknown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final problem = _problem;
    final fields = <Widget>[
      if (_askCurrent) ...<Widget>[
        _PasswordField(
          fieldKey: const Key('current-password-field'),
          label: l.passwordChangeCurrent,
          help: l.passwordChangeCurrentHelp,
          controller: _current,
          errorText: _currentError,
          shown: _showCurrent,
          onToggle: () => setState(() => _showCurrent = !_showCurrent),
          autofillHints: const <String>[AutofillHints.password],
        ),
        const SizedBox(height: Spacing.space5),
      ],
      _PasswordField(
        fieldKey: const Key('new-password-field'),
        label: l.passwordChangeNew,
        help: l.passwordChangeHint,
        controller: _new,
        errorText: _newError,
        shown: _showNew,
        onToggle: () => setState(() => _showNew = !_showNew),
      ),
      const SizedBox(height: Spacing.space5),
      _PasswordField(
        fieldKey: const Key('repeat-password-field'),
        label: l.passwordChangeRepeat,
        controller: _repeat,
        errorText: _repeatError,
        shown: _showRepeat,
        onToggle: () => setState(() => _showRepeat = !_showRepeat),
        action: TextInputAction.done,
        onSubmitted: (_) => _save(),
      ),
    ];
    return ScreenFrame(
      topBar: TopBar(
        title: l.passwordChangeTitle,
        leadingIcon: widget.onBack == null ? null : LucideIcons.arrowLeft,
        leadingLabel: widget.onBack == null ? null : l.actionBack,
        onLeading: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          Text(l.passwordChangeBody, style: text.bodyLarge),
          const SizedBox(height: Spacing.space5),
          if (!_mustSignInAgain) ...fields,
          if (problem != null) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            _ProblemNotice(code: problem),
          ],
          if (!_mustSignInAgain) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            PrimaryButton(
              label: l.passwordChangeSignOut,
              variant: PrimaryButtonVariant.ghost,
              onPressed: _busy ? null : widget.onSignOut,
            ),
          ],
        ],
      ),
      bottom: BottomActions(
        children: <Widget>[
          if (_mustSignInAgain)
            PrimaryButton(
              label: l.passwordChangeSignInAgain,
              icon: LucideIcons.logIn,
              onPressed: widget.onSignOut,
            )
          else
            PrimaryButton(
              label: _busy ? l.passwordChangeSaving : l.passwordChangeSave,
              icon: LucideIcons.check,
              busy: _busy,
              onPressed: _save,
            ),
        ],
      ),
    );
  }
}

/// A hidden password field with a show/hide button of at least 48 dp.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.shown,
    required this.onToggle,
    this.help,
    this.errorText,
    this.autofillHints,
    this.action = TextInputAction.next,
    this.onSubmitted,
  });

  final Key fieldKey;
  final String label;
  final String? help;
  final TextEditingController controller;
  final String? errorText;
  final bool shown;
  final VoidCallback onToggle;
  final Iterable<String>? autofillHints;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LabeledField(
      fieldKey: fieldKey,
      label: label,
      help: help,
      controller: controller,
      errorText: errorText,
      obscureText: !shown,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: action,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      suffix: IconButton(
        tooltip: shown ? l.signInHidePassword : l.signInShowPassword,
        icon: Icon(shown ? LucideIcons.eyeOff : LucideIcons.eye),
        constraints: const BoxConstraints(
          minWidth: Sizes.touch,
          minHeight: Sizes.touch,
        ),
        onPressed: onToggle,
      ),
    );
  }
}

/// A problem in plain words; spoken when it appears. Connection problems
/// are shown as information, the others as a warning.
class _ProblemNotice extends StatelessWidget {
  const _ProblemNotice({required this.code});

  final ProblemCode code;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final message = problemText(AppLocalizations.of(context), code);
    final connection =
        code == ProblemCode.offline || code == ProblemCode.timeout;
    return Panel(
      color: connection ? p.infoSubtle : p.warningSubtle,
      borderColor: connection ? p.info : p.warning,
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
                child: Icon(
                  connection ? LucideIcons.wifiOff : LucideIcons.triangleAlert,
                  color: connection ? p.info : p.warning,
                ),
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
    );
  }
}

/// Opens the step from the Today screen, when sending stopped because the
/// person must replace a one-time password. On success the app carries on
/// as after any sign-in (the app lock may ask for an app PIN), then sends
/// what is waiting and fetches new forms. Queued forms stay queued
/// throughout.
Future<void> openPasswordChange(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const _SessionPasswordChange()),
    );

class _SessionPasswordChange extends ConsumerWidget {
  const _SessionPasswordChange();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void leave() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }

    return ChangePasswordScreen(
      onBack: leave,
      onSave: (current, password) async {
        await ref
            .read(sessionProvider.notifier)
            .changePassword(currentPassword: current, newPassword: password);
        // The app lock may have taken over (an app PIN to choose); the app
        // then syncs as it opens again.
        if (!context.mounted) return;
        unawaited(syncNow(ref, ignoreBackoff: true));
        unawaited(ref.read(formsRefreshProvider.notifier).refresh());
        leave();
      },
      onSignOut: () {
        final session = ref.read(sessionProvider.notifier);
        leave();
        session.signOut();
      },
    );
  }
}
