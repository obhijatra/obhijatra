import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/screens/about_screen.dart';
import 'package:obhijatra_field/src/screens/settings_screen.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Settings and About.
class MoreScreen extends ConsumerWidget {
  /// Creates the screen with the bottom bar [nav].
  const MoreScreen({required this.nav, super.key});

  /// The bottom navigation bar.
  final Widget nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(sessionProvider);
    return ScreenFrame(
      topBar: TopBar(title: l.moreTitle),
      bottomNavigation: nav,
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          if (user != null) ...<Widget>[
            Panel(
              child: Row(
                children: <Widget>[
                  Icon(LucideIcons.users, color: p.action),
                  const SizedBox(width: Spacing.space3),
                  Expanded(
                    child: Text(
                      l.settingsSignedInAs(
                        user.name.isEmpty ? user.email : user.name,
                      ),
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.space3),
          ],
          ActionCard(
            icon: LucideIcons.settings,
            title: l.settingsTitle,
            onTap: () => unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: Spacing.space2),
          ActionCard(
            icon: LucideIcons.info,
            title: l.settingsAbout,
            onTap: () => unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
