// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Obhijatra Manager';

  @override
  String get homeHeading => 'Welcome to Obhijatra';

  @override
  String get homeIntro =>
      'Programme oversight for managers: forms, reports and field teams in one place. This is an early preview; nothing is stored yet.';

  @override
  String get homeStatus => 'Pre-alpha, Phase 1';

  @override
  String get languageToggle => 'বাংলা';
}
