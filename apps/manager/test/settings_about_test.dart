import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/app_info.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

Future<void> open(
  WidgetTester tester,
  String Function(AppLocalizations l10n) pick,
) async {
  final l10n = l10nOf(tester);
  await tester.tap(find.bySemanticsLabel(pick(l10n)).first);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Settings and About ($lang)', () {
      testWidgets('Settings: language can be changed and is remembered', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'));
        await pumpManager(tester, api, lang: lang);
        await open(tester, (l) => l.navSettings);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.settingsTitle), findsWidgets);
        expect(find.text('tania@example.org'), findsOneWidget);
        await tester.tap(find.text(lang == 'en' ? 'বাংলা' : 'English').last);
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('language'), lang == 'en' ? 'bn' : 'en');
        // The screen is now in the other language.
        final after = l10nOf(tester);
        expect(after.localeName, lang == 'en' ? 'bn' : 'en');
        expect(find.text(after.settingsTitle), findsWidgets);
      });

      testWidgets('Settings: Sign out ends the session', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'));
        await pumpManager(tester, api, lang: lang);
        await open(tester, (l) => l.navSettings);
        final l10n = l10nOf(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, l10n.menuSignOut));
        await tester.pumpAndSettle();
        expect(api.signOuts, 1);
        expect(find.byType(SignInScreen), findsOneWidget);
      });

      testWidgets('About: version, licence, source, licences, credit', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('supervisor'));
        await pumpManager(tester, api, lang: lang);
        await open(tester, (l) => l.navAbout);
        final l10n = l10nOf(tester);
        expect(find.textContaining(appVersion), findsWidgets);
        expect(find.text(l10n.aboutLicenceBody), findsOneWidget);
        expect(find.textContaining('AGPL-3.0'), findsWidgets);
        expect(find.text(sourceCodeUrl), findsOneWidget);
        // Plain text, exactly as the design says.
        expect(find.text(l10n.aboutMadeBy), findsOneWidget);
        if (lang == 'en') expect(l10n.aboutMadeBy, 'Made by Aninda Studio');

        // The source link tells the person if it cannot open (no browser here).
        await tester.tap(find.text(l10n.aboutSourceOpen));
        await tester.pumpAndSettle();
        expect(find.textContaining(sourceCodeUrl), findsWidgets);

        await tester.ensureVisible(find.text(l10n.aboutLicencesButton));
        await tester.tap(find.text(l10n.aboutLicencesButton));
        await tester.pumpAndSettle();
        expect(find.byType(LicensePage), findsOneWidget);
      });
    });
  }

  test('the version shown matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(
      line.replaceFirst('version:', '').trim().split('+').first,
      appVersion,
    );
  });
}
