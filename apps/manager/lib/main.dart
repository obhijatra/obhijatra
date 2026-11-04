import 'package:flutter/material.dart';
import 'package:obhijatra_manager/src/app.dart';
import 'package:obhijatra_manager/src/state/preferences.dart';
import 'package:obhijatra_manager/src/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = await Preferences.loadLanguage();
  final server = await Preferences.loadServer();
  runApp(
    ManagerRoot(
      overrides: [
        initialLocaleProvider.overrideWithValue(Locale(language ?? 'en')),
        initialServerUrlProvider.overrideWithValue(server ?? ''),
      ],
    ),
  );
}
