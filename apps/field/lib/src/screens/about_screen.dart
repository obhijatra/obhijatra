import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Version, free-software notice, how the data is kept safe (one phone per
/// person), source code and licences.
class AboutScreen extends ConsumerWidget {
  /// Creates the screen.
  const AboutScreen({super.key});

  Future<void> _openSource(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(urlLauncherProvider)(Uri.parse(sourceCodeUrl));
    } on Object {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.aboutLinkFailed(sourceCodeUrl))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return ScreenFrame(
      topBar: TopBar(
        title: l.aboutTitle,
        leadingIcon: LucideIcons.arrowLeft,
        leadingLabel: l.actionBack,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          Row(
            children: <Widget>[
              const ObhijatraMark(size: 56),
              const SizedBox(width: Spacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(l.appTitle, style: text.headlineMedium),
                    ),
                    Text(
                      l.aboutVersion('$appReleaseVersion ($appBuildNumber)'),
                      style: text.bodySmall!.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.space3),
          // Plain text on purpose: the maker's name is never drawn as a logo.
          Text(l.aboutMadeBy, style: text.bodyMedium),
          const SizedBox(height: Spacing.space5),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(l.aboutLicenceHeading, style: text.titleMedium),
                ),
                const SizedBox(height: Spacing.space2),
                Text(l.aboutLicenceBody, style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: Spacing.space3),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(l.aboutSecurityHeading, style: text.titleMedium),
                ),
                const SizedBox(height: Spacing.space2),
                Text(l.aboutSecurityBody, style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: Spacing.space3),
          ActionCard(
            icon: LucideIcons.externalLink,
            title: l.aboutSourceLink,
            meta: sourceCodeUrl,
            onTap: () => unawaited(_openSource(context, ref)),
          ),
          const SizedBox(height: Spacing.space2),
          ActionCard(
            icon: LucideIcons.scale,
            title: l.aboutLicences,
            onTap: () => showLicensePage(
              context: context,
              applicationName: l.appTitle,
              applicationVersion: appReleaseVersion,
            ),
          ),
        ],
      ),
    );
  }
}
