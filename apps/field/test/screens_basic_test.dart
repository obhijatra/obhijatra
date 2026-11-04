import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_field/src/screens/about_screen.dart';
import 'package:obhijatra_field/src/screens/more_screen.dart';
import 'package:obhijatra_field/src/screens/settings_screen.dart';
import 'package:obhijatra_field/src/screens/splash_screen.dart';
import 'package:obhijatra_field/src/screens/startup_problem_screen.dart';
import 'package:obhijatra_field/src/widgets/bottom_nav.dart';

import 'support/harness.dart';

void main() {
  group('Splash', () {
    matrix('shows only the app name', (tester, language, scale, l) async {
      final env = TestEnv();
      await pumpScreen(
        tester,
        env,
        const SplashScreen(),
        language: language,
        textScale: scale,
      );
      expect(await reveal(tester, find.text('Obhijatra')), findsOneWidget);
      expect(await reveal(tester, find.text('অভিযাত্রা')), findsOneWidget);
      // No maker's wordmark or endorsement line, in any spelling.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').toLowerCase().contains('aninda'),
        ),
        findsNothing,
      );
      await endTest(tester, env);
    });
  });

  group('Start-up problem', () {
    matrix('explains a locked database in plain words', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      var retried = 0;
      await pumpScreen(
        tester,
        env,
        StartupProblemScreen(
          code: ProblemCode.databaseKeyMissing,
          onRetry: () => retried++,
        ),
        language: language,
        textScale: scale,
      );
      expect(
        await reveal(tester, find.text(l.startupProblemTitle)),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.problem_databaseKeyMissing)),
        findsOneWidget,
      );
      await tester.tap(await reveal(tester, find.text(l.actionRetryStartup)));
      expect(retried, 1);
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });
  });

  group('More', () {
    matrix('shows who is signed in, Settings and About', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(env.seedSignedIn);
      await pumpScreen(
        tester,
        env,
        MoreScreen(
          nav: AppBottomNav(selected: MainTab.more, onSelected: (_) {}),
        ),
        language: language,
        textScale: scale,
      );
      expect(
        await reveal(tester, find.text(l.settingsSignedInAs('Rahima Akter'))),
        findsOneWidget,
      );
      expect(find.text(l.settingsTitle), findsWidgets);
      expect(await reveal(tester, find.text(l.settingsAbout)), findsOneWidget);
      await tester.tap(await reveal(tester, find.text(l.settingsAbout)));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.aboutLicenceHeading)),
        findsOneWidget,
      );
      await endTest(tester, env);
    });
  });

  group('Settings', () {
    matrix('switches the language and remembers it', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(env.seedSignedIn);
      await pumpScreen(
        tester,
        env,
        const SettingsScreen(),
        language: language,
        textScale: scale,
      );
      expect(find.text(l.settingsLanguage), findsWidgets);
      final other = language == 'bn' ? wordsFor('en') : wordsFor('bn');
      final otherName = language == 'bn'
          ? other.languageEnglish
          : other.languageBangla;
      await tester.tap(find.text(otherName));
      await settleApp(tester);
      // The screen is now in the other language.
      expect(find.text(other.settingsLanguage), findsWidgets);
      final saved = await tester.runAsync(
        () => SettingsRepository(env.db).read('ui.language'),
      );
      expect(saved, language == 'bn' ? 'en' : 'bn');
      await endTest(tester, env);
    });

    matrix('warns about unsent forms before signing out', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(() async {
        await env.seedSignedIn();
        await env.storeForm(householdVisitXForm);
        await OutboxRepository(env.db).enqueue(
          const FinalisedInstance(
            form: FormVersionRef('household_visit', '2026110401'),
            instanceId: 'uuid:aaaaaaaa-0000-4000-8000-000000000001',
            xml: '<data id="household_visit" version="2026110401"><meta><instanceID>uuid:aaaaaaaa-0000-4000-8000-000000000001</instanceID></meta></data>',
            attachmentNames: <String>[],
          ),
        );
      });
      env.server.submissionGlitch = const NoConnection();
      await pumpScreen(
        tester,
        env,
        const SettingsScreen(),
        language: language,
        textScale: scale,
      );
      // Wait for the sync engine to report the waiting form.
      await settleApp(tester);
      await tester.tap(await reveal(tester, find.text(l.settingsSignOut)));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.signOutConfirmTitle)),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.signOutOutboxWarning(1))),
        findsOneWidget,
      );
      // Cancel keeps the person signed in.
      await tester.tap(await reveal(tester, find.text(l.actionCancel)));
      await settleApp(tester);
      expect(find.text(l.signOutConfirmTitle), findsNothing);
      await endTest(tester, env);
    });

    matrix('signing out without waiting forms says drafts stay', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(env.seedSignedIn);
      await pumpScreen(
        tester,
        env,
        const SettingsScreen(),
        language: language,
        textScale: scale,
      );
      await tester.tap(await reveal(tester, find.text(l.settingsSignOut)));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.signOutNothingWaiting)),
        findsOneWidget,
      );
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });
  });

  group('About', () {
    matrix('shows version, notice, source link and licences', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      await pumpScreen(
        tester,
        env,
        const AboutScreen(),
        language: language,
        textScale: scale,
      );
      expect(find.text(l.aboutVersion('0.1.0 (1)')), findsOneWidget);
      // Plain text, exactly as the owner decided, in both languages.
      expect(
        await reveal(tester, find.text('Made by Aninda Studio')),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.aboutLicenceBody)),
        findsOneWidget,
      );
      expect(find.textContaining('AGPL-3.0'), findsWidgets);
      expect(
        await reveal(tester, find.text(l.aboutSourceLink)),
        findsOneWidget,
      );
      expect(await reveal(tester, find.text(l.aboutLicences)), findsOneWidget);
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });

    testWidgets('the source link opens outside the app', (tester) async {
      final env = TestEnv();
      await pumpScreen(tester, env, const AboutScreen(), language: 'en');
      await tester.tap(await reveal(tester, find.text('Get the source code')));
      await settleApp(tester);
      expect(env.opened, [Uri.parse('https://github.com/obhijatra/obhijatra')]);
      await endTest(tester, env);
    });

    testWidgets('says so when the link cannot be opened', (tester) async {
      final env = TestEnv()..canOpenLinks = false;
      await pumpScreen(tester, env, const AboutScreen(), language: 'en');
      await tester.tap(await reveal(tester, find.text('Get the source code')));
      await settleApp(tester);
      expect(find.textContaining('could not be opened'), findsOneWidget);
      await endTest(tester, env);
    });

    testWidgets('the licences page opens', (tester) async {
      final env = TestEnv();
      await pumpScreen(tester, env, const AboutScreen(), language: 'en');
      await tester.tap(await reveal(tester, find.text('Open-source licences')));
      await settleApp(tester);
      expect(find.byType(LicensePage), findsOneWidget);
      await endTest(tester, env);
    });
  });
}
