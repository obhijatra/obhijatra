import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/people_words.dart';
import 'package:obhijatra_manager/src/ui/sign_in_methods_screen.dart';
import 'package:obhijatra_manager/widgets/language_switch.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Language, account and sign out; for organisation admins, the way into
/// the sign-in methods.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final user = ref.watch(sessionProvider);
    final org = ref.watch(organisationNameProvider).asData?.value ?? '';
    final server = ref.watch(serverUrlProvider);
    final isAdmin = user?.isOrgAdmin ?? false;
    if (isAdmin &&
        ref.watch(settingsPageProvider) == SettingsPage.signInMethods) {
      return const SignInMethodsScreen();
    }

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: text.bodySmall!.copyWith(color: palette.textMuted),
          ),
          Text(value, style: text.titleSmall),
        ],
      ),
    );

    return PageScaffold(
      title: l10n.settingsTitle,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Spacing.space8),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.content),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ObPanel(
                  padding: const EdgeInsets.all(Spacing.space6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.settingsLanguage,
                          style: text.titleLarge,
                        ),
                      ),
                      const SizedBox(height: Spacing.space2),
                      Text(
                        l10n.settingsLanguageHelp,
                        style: text.bodyMedium!.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: Spacing.space4),
                      const LanguageSwitch(),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.space5),
                ObPanel(
                  padding: const EdgeInsets.all(Spacing.space6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.settingsAccount,
                          style: text.titleLarge,
                        ),
                      ),
                      const SizedBox(height: Spacing.space2),
                      if (user != null) ...<Widget>[
                        row(l10n.accountName, user.displayName),
                        if (user.email.isNotEmpty)
                          row(l10n.accountEmail, user.email),
                        if (user.phone.isNotEmpty)
                          row(l10n.accountPhone, user.phone),
                        row(l10n.accountRole, roleName(l10n, user.role)),
                      ],
                      if (org.isNotEmpty) row(l10n.accountOrganisation, org),
                      if (!kIsWeb && server.isNotEmpty)
                        row(l10n.accountServer, server),
                      const SizedBox(height: Spacing.space3),
                      Wrap(
                        spacing: Spacing.space4,
                        runSpacing: Spacing.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.read(sessionProvider.notifier).signOut(),
                            icon: const Icon(Icons.logout),
                            label: Text(l10n.menuSignOut),
                          ),
                          Text(
                            l10n.settingsSignOutHelp,
                            style: text.bodySmall!.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...<Widget>[
                  const SizedBox(height: Spacing.space5),
                  ObPanel(
                    padding: const EdgeInsets.all(Spacing.space6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.signInMethodsTitle,
                            style: text.titleLarge,
                          ),
                        ),
                        const SizedBox(height: Spacing.space2),
                        Text(
                          l10n.signInMethodsSummary,
                          style: text.bodyMedium!.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                        const SizedBox(height: Spacing.space4),
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(settingsPageProvider.notifier)
                              .open(SettingsPage.signInMethods),
                          icon: const Icon(Icons.key_outlined),
                          label: Text(l10n.signInMethodsOpen),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
