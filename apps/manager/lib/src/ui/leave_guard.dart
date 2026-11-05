import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/places.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Asks before leaving a screen with unsaved changes. Returns whether to
/// go on.
Future<bool> confirmLeave(BuildContext context, WidgetRef ref) async {
  final guard = ref.read(leaveGuardProvider);
  if (!guard.hasUnsavedChanges) return true;
  final l10n = AppLocalizations.of(context);
  final palette = context.palette;
  final prompt = guard.promptIn(l10n);
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(prompt.title),
      content: Text(prompt.body),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.leaveStay),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: palette.danger,
            foregroundColor: palette.onAction,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(prompt.leave),
        ),
      ],
    ),
  );
  return leave ?? false;
}

/// Goes to [section] (its first page), asking first if changes would be
/// lost.
Future<void> goToSection(
  BuildContext context,
  WidgetRef ref,
  Section section,
) async {
  if (!await confirmLeave(context, ref) || !context.mounted) return;
  ref.read(settingsPageProvider.notifier).open(SettingsPage.overview);
  ref.read(peopleViewProvider.notifier).open(const PeopleView.list());
  ref.read(placesPageProvider.notifier).open(PlacesPage.tree);
  ref.read(sectionProvider.notifier).go(section);
}

/// Signs out, asking first if changes would be lost.
Future<void> signOutGuarded(
  BuildContext context,
  WidgetRef ref,
  VoidCallback signOut,
) async {
  if (!await confirmLeave(context, ref) || !context.mounted) return;
  signOut();
}
