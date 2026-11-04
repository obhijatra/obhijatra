import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/locale_provider.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Placeholder home screen of the field app.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.content),
            child: ListView(
              padding: const EdgeInsets.all(Spacing.space4),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(Spacing.space6),
                  decoration: BoxDecoration(
                    color: palette.surfaceBrand,
                    borderRadius: Radii.xlAll,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.appTitle,
                      style: text.displayLarge!.copyWith(
                        color: palette.textOnBrand,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.space6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.space6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l10n.homeHeading, style: text.headlineMedium),
                        const SizedBox(height: Spacing.space3),
                        Text(l10n.homeIntro, style: text.bodyLarge),
                        const SizedBox(height: Spacing.space5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.space3,
                            vertical: Spacing.space1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.infoSubtle,
                            borderRadius: Radii.pillAll,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.info_outline,
                                size: Sizes.icon,
                                color: palette.info,
                              ),
                              const SizedBox(width: Spacing.space2),
                              Flexible(
                                child: Text(
                                  l10n.homeStatus,
                                  style: text.labelLarge!.copyWith(
                                    color: palette.info,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.space4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () =>
                        ref.read(localeProvider.notifier).toggle(),
                    child: Text(l10n.languageToggle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
