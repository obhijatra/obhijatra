import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

Future<void> signInWith(
  WidgetTester tester,
  String email,
  String password,
) async {
  final fields = find.byType(TextFormField);
  // Desktop shows the server address first; the web build does not.
  final count = fields.evaluate().length;
  if (count == 3) {
    await tester.enterText(fields.at(0), 'https://data.example.org');
  }
  await tester.enterText(fields.at(count - 2), email);
  await tester.enterText(fields.at(count - 1), password);
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Sign in ($lang)', () {
      testWidgets('asks for email and password and signs in', (tester) async {
        final api = FakeManagerApi();
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(find.text(l10n.signInTitle), findsWidgets);
        // Empty form: the person is told what is missing.
        await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsOneWidget);
        await signInWith(tester, 'tania@example.org', 'a-long-password');
        await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsNothing);
        expect(find.text(l10n.navForms), findsWidgets);
      });

      testWidgets('a wrong password gives one plain sentence', (tester) async {
        final api = FakeManagerApi()
          ..signInFailure = const AppProblem(ProblemKind.signInFailed);
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, 'tania@example.org', 'wrong');
        await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
        await tester.pumpAndSettle();
        expect(find.text(l10n.problemSignInFailed), findsOneWidget);
        expect(find.byType(SignInScreen), findsOneWidget);
      });

      testWidgets('offline while signing in says so', (tester) async {
        final api = FakeManagerApi()
          ..signInFailure = const AppProblem(ProblemKind.offline);
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, 'tania@example.org', 'whatever-it-is');
        await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
        await tester.pumpAndSettle();
        expect(find.text(l10n.problemOffline), findsOneWidget);
      });

      testWidgets(
        'the language switch is visible and its choice is remembered',
        (tester) async {
          final api = FakeManagerApi();
          await pumpManager(tester, api, lang: lang);
          expect(find.text('English'), findsOneWidget);
          expect(find.text('বাংলা'), findsOneWidget);
          await tester.tap(find.text(lang == 'en' ? 'বাংলা' : 'English'));
          await tester.pumpAndSettle();
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('language'), lang == 'en' ? 'bn' : 'en');
          expect(prefs.getKeys(), <String>{'language'});
        },
      );
    });

    group('Shell ($lang)', () {
      testWidgets('an organisation admin has five places and nothing '
          'unfinished', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        for (final label in <String>[
          l10n.navForms,
          l10n.navSubmissions,
          l10n.navPeople,
          l10n.navSettings,
          l10n.navAbout,
        ]) {
          expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
        }
        final words = everyWord(tester).toLowerCase();
        for (final hidden in <String>[
          'devices',
          'cases',
          'enrol',
          'key ceremony',
          'decrypt',
        ]) {
          expect(words, isNot(contains(hidden)), reason: hidden);
        }
        // Language switch is always on screen.
        expect(find.text('English'), findsOneWidget);
        expect(find.text('বাংলা'), findsOneWidget);
      });

      testWidgets('works at 1024 px wide', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        await pumpManager(tester, api, lang: lang, size: const Size(1024, 700));
        expect(tester.takeException(), isNull);
        final l10n = l10nOf(tester);
        for (final label in <String>[
          l10n.navSubmissions,
          l10n.navSettings,
          l10n.navAbout,
          l10n.navForms,
        ]) {
          await tester.tap(find.bySemanticsLabel(label).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }
      });

      testWidgets('keyboard: Tab shows a focus ring and Enter opens a place', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        await pumpManager(tester, api, lang: lang);
        final before = visibleFocusRings(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(visibleFocusRings(tester), greaterThan(before));

        // Tab until the About item has focus, then press Enter.
        final l10n = l10nOf(tester);
        bool onAbout() {
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused == null) return false;
          var found = false;
          focused.visitAncestorElements((e) {
            final w = e.widget;
            if (w is Semantics && w.properties.label == l10n.navAbout) {
              found = true;
              return false;
            }
            return true;
          });
          return found;
        }

        var guard = 0;
        while (!onAbout() && guard++ < 60) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(onAbout(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(l10n.aboutTitle), findsWidgets);
      });

      testWidgets('offline: a banner with Try again, then it clears', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        api.failWith = const AppProblem(ProblemKind.offline);
        await tester.tap(find.bySemanticsLabel(l10n.navSubmissions).first);
        await tester.pumpAndSettle();
        expect(find.text(l10n.offlineTitle), findsOneWidget);
        api.failWith = null;
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.actionTryAgain).first,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.offlineTitle), findsNothing);
      });

      testWidgets('an ended session returns to sign in', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        api.failWith = const AppProblem(ProblemKind.signInRequired);
        await tester.tap(find.bySemanticsLabel(l10n.navSubmissions).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.actionSignInAgain).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsOneWidget);
      });

      testWidgets('keeps nothing in browser storage but the language', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        await pumpManager(tester, api, lang: lang);
        await tester.tap(find.text(lang == 'en' ? 'বাংলা' : 'English'));
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        // The server address is also kept on Windows and macOS, never on web.
        expect(
          prefs.getKeys().difference(<String>{'language', 'server_url'}),
          isEmpty,
        );
      });
    });
  }
}
