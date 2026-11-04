import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
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
      secondaryLabel: l.signInChangeServer,
      onSecondary: () => ref.read(serverProvider.notifier).forgetAddress(),
      onSignIn: (email, password) async {
        try {
          await ref
              .read(sessionProvider.notifier)
              .signIn(email: email, password: password);
          return null;
        } on ObhijatraException catch (e) {
          return SignInProblem.of(l, e.code);
        } on Object {
          return SignInProblem.of(l, ProblemCode.unknown);
        }
      },
    );
  }
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

/// The sign-in form: server, email, password and the sign-in button. Used by
/// the first sign-in and by the app lock's online sign-in.
class SignInForm extends StatefulWidget {
  /// Creates the form. [onSignIn] returns `null` when it worked.
  const SignInForm({
    required this.onSignIn,
    this.host,
    this.notice,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  /// Signs in; returns the problem to show, or `null`.
  final Future<SignInProblem?> Function(String email, String password) onSignIn;

  /// The server's host name, shown at the top.
  final String? host;

  /// Why the person is asked to sign in, shown under the server.
  final String? notice;

  /// The words of the quiet button under the form.
  final String? secondaryLabel;

  /// What the quiet button does.
  final VoidCallback? onSecondary;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;
  SignInProblem? _problem;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l = AppLocalizations.of(context);
    final emailMissing = _email.text.trim().isEmpty;
    final passwordMissing = _password.text.isEmpty;
    setState(() {
      _emailError = emailMissing ? l.signInEmptyEmail : null;
      _passwordError = passwordMissing ? l.signInEmptyPassword : null;
      _problem = null;
    });
    if (emailMissing || passwordMissing) return;
    setState(() => _busy = true);
    try {
      final problem = await widget.onSignIn(_email.text, _password.text);
      if (mounted) setState(() => _problem = problem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final host = widget.host;
    final problem = _problem;
    final connection = problem?.isConnection ?? false;
    return ScreenFrame(
      topBar: TopBar(title: l.signInTitle),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
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
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
            onSubmitted: (_) => _signIn(),
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
          if (problem != null) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            Panel(
              color: connection ? p.infoSubtle : p.warningSubtle,
              borderColor: connection ? p.info : p.warning,
              child: Semantics(
                liveRegion: true,
                container: true,
                label: problem.message,
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.space1),
                        child: Icon(
                          connection
                              ? LucideIcons.wifiOff
                              : LucideIcons.triangleAlert,
                          color: connection ? p.info : p.warning,
                        ),
                      ),
                      const SizedBox(width: Spacing.space3),
                      Expanded(
                        child: Text(problem.message, style: text.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (widget.secondaryLabel != null) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            PrimaryButton(
              label: widget.secondaryLabel!,
              variant: PrimaryButtonVariant.ghost,
              onPressed: _busy ? null : widget.onSecondary,
            ),
          ],
        ],
      ),
      bottom: BottomActions(
        children: <Widget>[
          PrimaryButton(
            label: _busy ? l.signInWorking : l.signInTitle,
            icon: LucideIcons.logIn,
            busy: _busy,
            onPressed: _signIn,
          ),
        ],
      ),
    );
  }
}
