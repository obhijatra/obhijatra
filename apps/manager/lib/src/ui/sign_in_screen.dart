import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/config/server_address.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/widgets/brand_mark.dart';
import 'package:obhijatra_manager/widgets/language_switch.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Where staff sign in.
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  AppProblem? _problem;

  /// The web app talks to the server it was loaded from; the desktop app
  /// asks for the address.
  bool get _asksForServer => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _server.text = ref.read(serverUrlProvider);
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      if (_asksForServer) {
        ref
            .read(serverUrlProvider.notifier)
            .set(parseServerAddress(_server.text).address.toString());
      }
      await ref
          .read(sessionProvider.notifier)
          .signIn(_email.text, _password.text);
    } on AppProblem catch (problem) {
      if (mounted) setState(() => _problem = problem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final online = ref.watch(onlineProvider);
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
                        child: Form(
                          key: _formKey,
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
                                        l10n.signInTitle,
                                        style: text.headlineMedium,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Spacing.space2),
                              Text(
                                l10n.signInIntro,
                                style: text.bodyMedium!.copyWith(
                                  color: palette.textMuted,
                                ),
                              ),
                              const SizedBox(height: Spacing.space5),
                              if (_asksForServer) ...<Widget>[
                                TextFormField(
                                  controller: _server,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: l10n.signInServer,
                                    helperText: l10n.signInServerHelp,
                                    helperMaxLines: 3,
                                  ),
                                  validator: (value) {
                                    final result = parseServerAddress(
                                      value ?? '',
                                    );
                                    return switch (result.issue) {
                                      null => null,
                                      AddressIssue.empty => l10n.fieldRequired,
                                      AddressIssue.shape => l10n.serverInvalid,
                                      AddressIssue.insecure =>
                                        l10n.serverInsecure,
                                    };
                                  },
                                ),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _server,
                                  builder: (context, value, _) {
                                    final address = parseServerAddress(
                                      value.text,
                                    ).address;
                                    if (address == null ||
                                        !isTestingAddress(address)) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: Spacing.space2,
                                      ),
                                      child: Text(
                                        l10n.serverTestingOnly,
                                        style: text.bodySmall!.copyWith(
                                          color: palette.textMuted,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: Spacing.space4),
                              ],
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const <String>[
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: l10n.signInEmail,
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty
                                    ? l10n.fieldRequired
                                    : null,
                              ),
                              const SizedBox(height: Spacing.space4),
                              TextFormField(
                                controller: _password,
                                obscureText: _hidePassword,
                                autofillHints: const <String>[
                                  AutofillHints.password,
                                ],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: l10n.signInPassword,
                                  suffixIcon: IconButton(
                                    tooltip: _hidePassword
                                        ? l10n.signInShowPassword
                                        : l10n.signInHidePassword,
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword,
                                    ),
                                  ),
                                ),
                                validator: (value) => (value ?? '').isEmpty
                                    ? l10n.fieldRequired
                                    : null,
                              ),
                              if (_problem != null) ...<Widget>[
                                const SizedBox(height: Spacing.space4),
                                ProblemBanner(
                                  problem: _problem!,
                                  onAction: _submit,
                                ),
                              ],
                              if (!online && _problem == null) ...<Widget>[
                                const SizedBox(height: Spacing.space4),
                                Text(l10n.offlineBody, style: text.bodySmall),
                              ],
                              const SizedBox(height: Spacing.space5),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: Text(
                                  _busy
                                      ? l10n.signInWorking
                                      : l10n.signInButton,
                                ),
                              ),
                            ],
                          ),
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
