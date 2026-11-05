import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/widgets/code_text.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A one-time password, shown once: large and easy to read out, with a
/// Copy button and what to do with it.
class OneTimePasswordReveal extends StatefulWidget {
  /// Creates the reveal for the person called [name].
  const OneTimePasswordReveal({
    required this.name,
    required this.email,
    required this.password,
    super.key,
  });

  /// Who the password is for.
  final String name;

  /// The email address they sign in with.
  final String email;

  /// The password, as typed (`kfmw-tqzp-hrvx`).
  final String password;

  /// [password] spelled out for a screen reader: "k f m w, t q z p, …".
  static String spoken(String password) =>
      password.split('-').map((group) => group.split('').join(' ')).join(', ');

  @override
  State<OneTimePasswordReveal> createState() => _OneTimePasswordRevealState();
}

class _OneTimePasswordRevealState extends State<OneTimePasswordReveal> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.password));
    if (mounted) setState(() => _copied = true);
  }

  /// Done, Add another person, or leaving the page all close the reveal.
  /// A copied password must not stay on the clipboard (Windows keeps a
  /// clipboard history and can sync it to other devices), so it is
  /// overwritten then.
  @override
  void dispose() {
    if (_copied) unawaited(Clipboard.setData(const ClipboardData(text: '')));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final email = widget.email;
    final password = widget.password;
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.otpTitle(name), style: text.titleMedium),
        const SizedBox(height: Spacing.space3),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space4,
            vertical: Spacing.space3,
          ),
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: Radii.smAll,
            border: Border.all(color: palette.borderStrong),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.space4,
            runSpacing: Spacing.space2,
            children: <Widget>[
              Semantics(
                label: l10n.otpSpoken(OneTimePasswordReveal.spoken(password)),
                excludeSemantics: true,
                child: SelectableText(
                  password,
                  key: const ValueKey<String>('otp-value'),
                  style: codeStyle(
                    text.headlineSmall!.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
                label: Text(l10n.otpCopy),
              ),
            ],
          ),
        ),
        // Said here rather than in a passing message, so it is also seen
        // in the dialog.
        Semantics(
          liveRegion: true,
          child: _copied
              ? Padding(
                  padding: const EdgeInsets.only(top: Spacing.space2),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.check_circle_outline,
                        size: Sizes.iconSm,
                        color: palette.success,
                      ),
                      const SizedBox(width: Spacing.space1),
                      Expanded(
                        child: Text(l10n.otpCopied, style: text.bodySmall),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: Spacing.space3),
        Text(l10n.otpGive(name), style: text.bodyMedium),
        if (email.isNotEmpty) ...<Widget>[
          const SizedBox(height: Spacing.space2),
          Text(
            l10n.otpSignInWith(email),
            style: text.bodyMedium!.copyWith(color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Shows a new one-time password in a dialog that only "Done" closes.
Future<void> showOneTimePasswordDialog(
  BuildContext context, {
  required String name,
  required String email,
  required String password,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    content: SizedBox(
      width: 480,
      child: OneTimePasswordReveal(
        name: name,
        email: email,
        password: password,
      ),
    ),
    actions: <Widget>[
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context).otpDone),
      ),
    ],
  ),
);
