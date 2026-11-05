import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/config/server_address.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/state/url_opener.dart';
import 'package:obhijatra_manager/src/ui/sign_in_sms.dart';
import 'package:obhijatra_manager/widgets/brand_mark.dart';
import 'package:obhijatra_manager/widgets/language_switch.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';
import 'package:url_launcher/link.dart';

/// What the sign-in screen shows.
enum _Mode {
  /// Email and password, with the other ways below.
  password,

  /// The SMS-code steps.
  sms,

  /// Waiting while the person signs in on Google's page.
  google,
}

/// Where staff sign in: email and password first, then Google and SMS
/// codes when the server offers them.
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverKey = GlobalKey<FormFieldState<String>>();
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  AppProblem? _problem;
  bool _problemFromGoogle = false;
  _Mode _mode = _Mode.password;
  Timer? _serverPreview;
  Completer<void>? _googleCancel;
  Uri? _googleUrl;

  /// The web app talks to the server it was loaded from; the desktop app
  /// asks for the address.
  bool get _asksForServer => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _server.text = ref.read(serverUrlProvider);
    if (_asksForServer) _server.addListener(_onServerTyped);
  }

  @override
  void dispose() {
    _serverPreview?.cancel();
    final cancel = _googleCancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Once the person stops typing a server address, asks that server which
  /// ways to sign in it offers (desktop only).
  void _onServerTyped() {
    _serverPreview?.cancel();
    _serverPreview = Timer(const Duration(milliseconds: 600), () {
      final address = parseServerAddress(_server.text).address;
      if (address != null && mounted) {
        ref.read(serverUrlProvider.notifier).preview(address.toString());
      }
    });
  }

  /// Checks and keeps the server address before signing in another way.
  bool _useServerAddress() {
    if (!_asksForServer) return true;
    final field = _serverKey.currentState;
    if (field == null || !field.validate()) return false;
    ref
        .read(serverUrlProvider.notifier)
        .set(parseServerAddress(_server.text).address.toString());
    return true;
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
      if (mounted) {
        setState(() {
          _problem = problem;
          _problemFromGoogle = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSms() {
    if (_busy || !_useServerAddress()) return;
    setState(() {
      _problem = null;
      _mode = _Mode.sms;
    });
  }

  Future<void> _google() async {
    if (_busy || !_useServerAddress()) return;
    final cancel = Completer<void>();
    setState(() {
      _problem = null;
      _googleUrl = null;
      _googleCancel = cancel;
      _mode = _Mode.google;
    });
    try {
      final signedIn = await ref
          .read(sessionProvider.notifier)
          .signInWithGoogle(
            openUrl: (url) async {
              if (mounted) setState(() => _googleUrl = url);
              await ref.read(urlOpenerProvider)(url);
            },
            cancelled: cancel.future,
          );
      if (!signedIn && mounted) setState(() => _mode = _Mode.password);
    } on AppProblem catch (problem) {
      if (mounted) {
        setState(() {
          _mode = _Mode.password;
          _problem = problem;
          _problemFromGoogle = true;
        });
      }
    } finally {
      if (identical(_googleCancel, cancel)) _googleCancel = null;
    }
  }

  void _cancelGoogle() {
    final cancel = _googleCancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    setState(() => _mode = _Mode.password);
  }

  void _onProblemAction() {
    final problem = _problem;
    if (problem == null) return;
    if (problem.action != ProblemAction.tryAgain) {
      setState(() => _problem = null);
    } else if (_problemFromGoogle) {
      unawaited(_google());
    } else {
      unawaited(_submit());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final body = switch (_mode) {
      _Mode.password => _passwordForm(context),
      _Mode.sms => SmsSignIn(
        onBack: () => setState(() => _mode = _Mode.password),
      ),
      _Mode.google => _GoogleWaiting(
        url: _googleUrl,
        onOpen: (url) => ref.read(urlOpenerProvider)(url),
        onCancel: _cancelGoogle,
      ),
    };
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
                          if (_mode == _Mode.password) ...<Widget>[
                            Text(
                              l10n.signInIntro,
                              style: text.bodyMedium!.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                            const SizedBox(height: Spacing.space5),
                          ] else
                            const SizedBox(height: Spacing.space3),
                          body,
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

  Widget _passwordForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final online = ref.watch(onlineProvider);
    final methods =
        ref.watch(signInMethodsProvider).value ?? SignInMethods.passwordOnly;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_asksForServer) ...<Widget>[
              TextFormField(
                key: _serverKey,
                controller: _server,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.signInServer,
                  helperText: l10n.signInServerHelp,
                  helperMaxLines: 3,
                ),
                validator: (value) {
                  final result = parseServerAddress(value ?? '');
                  return switch (result.issue) {
                    null => null,
                    AddressIssue.empty => l10n.fieldRequired,
                    AddressIssue.shape => l10n.serverInvalid,
                    AddressIssue.insecure => l10n.serverInsecure,
                  };
                },
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _server,
                builder: (context, value, _) {
                  final address = parseServerAddress(value.text).address;
                  if (address == null || !isTestingAddress(address)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: Spacing.space2),
                    child: Text(
                      l10n.serverTestingOnly,
                      style: text.bodySmall!.copyWith(color: palette.textMuted),
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
              decoration: InputDecoration(labelText: l10n.signInEmail),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: Spacing.space4),
            TextFormField(
              controller: _password,
              obscureText: _hidePassword,
              autofillHints: const <String>[AutofillHints.password],
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
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? l10n.fieldRequired : null,
            ),
            if (_problem != null && !_problemFromGoogle) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              ProblemBanner(problem: _problem!, onAction: _onProblemAction),
            ],
            if (!online && _problem == null) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              Text(l10n.offlineBody, style: text.bodySmall),
            ],
            const SizedBox(height: Spacing.space5),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? l10n.signInWorking : l10n.signInButton),
            ),
            if (methods.google || methods.phone) ...<Widget>[
              const SizedBox(height: Spacing.space5),
              _OrDivider(label: l10n.signInOr),
              const SizedBox(height: Spacing.space5),
            ],
            if (methods.google) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.signInGoogle),
              ),
              // A Google problem sits under the Google button, so it is
              // not mistaken for a problem with the password.
              if (_problem != null && _problemFromGoogle) ...<Widget>[
                const SizedBox(height: Spacing.space3),
                ProblemBanner(problem: _problem!, onAction: _onProblemAction),
              ],
              if (methods.phone) const SizedBox(height: Spacing.space3),
            ],
            if (methods.phone) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _busy ? null : _openSms,
                icon: const Icon(Icons.sms_outlined),
                label: Text(l10n.signInSms),
              ),
              const SizedBox(height: Spacing.space2),
              Text(
                l10n.signInSmsAdminNote,
                textAlign: TextAlign.center,
                style: text.bodySmall!.copyWith(color: palette.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A line with a word in the middle.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.space3),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge!
                .copyWith(color: palette.textMuted),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Shown while the person signs in on Google's page in the browser.
class _GoogleWaiting extends StatelessWidget {
  const _GoogleWaiting({
    required this.url,
    required this.onOpen,
    required this.onCancel,
  });

  /// Google's page, once the server has given it.
  final Uri? url;

  /// Opens Google's page again.
  final void Function(Uri url) onOpen;

  /// Stops waiting.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final page = url;
    final Widget openButton;
    if (kIsWeb && page != null) {
      // A real link: a browser never blocks a tab the person opened by
      // clicking a link, as it may block one the app opens by itself.
      openButton = Link(
        uri: page,
        target: LinkTarget.blank,
        builder: (context, followLink) => OutlinedButton.icon(
          onPressed: followLink,
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.googleOpen),
        ),
      );
    } else {
      openButton = OutlinedButton.icon(
        onPressed: page == null ? null : () => onOpen(page),
        icon: const Icon(Icons.open_in_new),
        label: Text(l10n.googleOpen),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          header: true,
          child: Row(
            children: <Widget>[
              const SizedBox(
                width: Sizes.icon,
                height: Sizes.icon,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: Text(l10n.googleWaitingTitle, style: text.titleLarge),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.space3),
        Text(l10n.googleWaitingBody, style: text.bodyMedium),
        const SizedBox(height: Spacing.space5),
        Text(
          l10n.googleOpenHelp,
          style: text.bodySmall!.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: Spacing.space2),
        openButton,
        const SizedBox(height: Spacing.space3),
        TextButton(onPressed: onCancel, child: Text(l10n.actionCancel)),
      ],
    );
  }
}
