import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/app_info.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Version, licence, source code, open-source licences and credit.
class AboutScreen extends StatelessWidget {
  /// Creates the screen.
  const AboutScreen({super.key});

  Future<void> _openSource(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(sourceCodeUrl));
    } on Object {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.aboutSourceFailed(sourceCodeUrl))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;

    Widget card(String title, List<Widget> children) => ObPanel(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(header: true, child: Text(title, style: text.titleLarge)),
          const SizedBox(height: Spacing.space2),
          ...children,
        ],
      ),
    );

    return PageScaffold(
      title: l10n.aboutTitle,
      subtitle: '${l10n.appTitle} · ${l10n.aboutVersion(appVersion)}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Spacing.space8),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.content),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.aboutPreAlpha,
                  style: text.bodyMedium!.copyWith(color: palette.textMuted),
                ),
                const SizedBox(height: Spacing.space4),
                card(l10n.aboutLicenceTitle, <Widget>[
                  Text(l10n.aboutLicenceBody, style: text.bodyMedium),
                ]),
                const SizedBox(height: Spacing.space5),
                card(l10n.aboutSourceTitle, <Widget>[
                  Text(sourceCodeUrl, style: text.bodyMedium),
                  const SizedBox(height: Spacing.space3),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () => _openSource(context),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.aboutSourceOpen),
                    ),
                  ),
                ]),
                const SizedBox(height: Spacing.space5),
                card(l10n.aboutLicencesTitle, <Widget>[
                  Text(
                    l10n.aboutLicencesHelp,
                    style: text.bodyMedium!.copyWith(color: palette.textMuted),
                  ),
                  const SizedBox(height: Spacing.space3),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: l10n.appTitle,
                        applicationVersion: appVersion,
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: Text(l10n.aboutLicencesButton),
                    ),
                  ),
                ]),
                const SizedBox(height: Spacing.space6),
                Text(l10n.aboutMadeBy, style: text.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
