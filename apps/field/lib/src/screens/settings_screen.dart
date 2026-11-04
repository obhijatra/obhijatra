import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Language and sign out.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final status = ref.read(syncStatusProvider).value ?? const SyncStatus();
    final unsent = status.queued + status.problems;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.signOutConfirmTitle),
        content: Text(
          unsent > 0 ? l.signOutOutboxWarning(unsent) : l.signOutNothingWaiting,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.settingsSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(sessionProvider.notifier).signOut();
    // The app returns to the sign-in screen by itself.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = ref.watch(localeProvider);
    final user = ref.watch(sessionProvider);
    // Watched (not only read at sign-out) so the waiting count is already
    // known when the person taps Sign out.
    ref.watch(syncStatusProvider);
    return ScreenFrame(
      topBar: TopBar(
        title: l.settingsTitle,
        leadingIcon: LucideIcons.arrowLeft,
        leadingLabel: l.actionBack,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l.settingsLanguage, style: text.headlineMedium),
          ),
          const SizedBox(height: Spacing.space3),
          QuestionChoice(
            label: l.settingsLanguage,
            options: <ChoiceOption>[
              ChoiceOption('bn', l.languageBangla),
              ChoiceOption('en', l.languageEnglish),
            ],
            selected: <String>{locale.languageCode},
            onChanged: (values) =>
                ref.read(localeProvider.notifier).select(Locale(values.first)),
          ),
          const SizedBox(height: Spacing.space8),
          Semantics(
            header: true,
            child: Text(l.settingsAccount, style: text.headlineMedium),
          ),
          const SizedBox(height: Spacing.space3),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.space3),
              child: Text(
                l.settingsSignedInAs(
                  user.name.isEmpty ? user.email : user.name,
                ),
                style: text.bodyMedium,
              ),
            ),
          PrimaryButton(
            label: l.settingsSignOut,
            icon: LucideIcons.logOut,
            variant: PrimaryButtonVariant.secondary,
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}
