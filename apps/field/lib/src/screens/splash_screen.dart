import 'package:flutter/material.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The first screen: the app mark and the app name in English and Bangla.
/// Nothing else (no endorsement or wordmark).
class SplashScreen extends StatelessWidget {
  /// Creates the splash screen.
  const SplashScreen({super.key});

  // The app's own name, written in both scripts. It is a name, so it is
  // the same in every language and is not translated.
  static const String _english = 'Obhijatra';
  static const String _bangla = 'অভিযাত্রা';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            container: true,
            label: '${l.splashLoading}: ${l.appTitle}',
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const ObhijatraMark(size: 112),
                  const SizedBox(height: Spacing.space5),
                  Text(
                    _english,
                    textAlign: TextAlign.center,
                    style: ObhijatraType.h1.toStyle(color: p.text),
                  ),
                  Text(
                    _bangla,
                    textAlign: TextAlign.center,
                    style: ObhijatraType.bnH2.toStyle(color: p.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
