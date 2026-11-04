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
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;
  ProblemCode? _problem;

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
      await ref
          .read(sessionProvider.notifier)
          .signIn(email: _email.text, password: _password.text);
    } on ObhijatraException catch (e) {
      if (mounted) setState(() => _problem = e.code);
    } on Object {
      if (mounted) setState(() => _problem = ProblemCode.unknown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final address = ref.watch(serverProvider).value?.address;
    final host = address?.host;
    final offlineLike =
        _problem == ProblemCode.offline || _problem == ProblemCode.timeout;
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
          if (_problem != null) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            Panel(
              color: offlineLike ? p.infoSubtle : p.warningSubtle,
              borderColor: offlineLike ? p.info : p.warning,
              child: Semantics(
                liveRegion: true,
                container: true,
                label: problemText(l, _problem!),
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.space1),
                        child: Icon(
                          offlineLike
                              ? LucideIcons.wifiOff
                              : LucideIcons.triangleAlert,
                          color: offlineLike ? p.info : p.warning,
                        ),
                      ),
                      const SizedBox(width: Spacing.space3),
                      Expanded(
                        child: Text(
                          problemText(l, _problem!),
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: Spacing.space4),
          PrimaryButton(
            label: l.signInChangeServer,
            variant: PrimaryButtonVariant.ghost,
            onPressed: _busy
                ? null
                : () => ref.read(serverProvider.notifier).forgetAddress(),
          ),
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
