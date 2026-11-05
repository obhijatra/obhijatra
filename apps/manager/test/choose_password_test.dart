import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/ui/choose_password_screen.dart';
import 'package:obhijatra_manager/src/ui/shell.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

const String oneTime = 'kfmw-tqzp-hrvx';
const String chosen = 'three green mangoes';

Finder fieldIn(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(EditableText),
);

Future<void> signInWith(
  WidgetTester tester,
  AppLocalizations l10n,
  String email,
  String password,
) async {
  final fields = find.byType(TextFormField);
  final count = fields.evaluate().length;
  if (count == 3) {
    await tester.enterText(fields.at(0), 'https://data.example.org');
  }
  await tester.enterText(fields.at(count - 2), email);
  await tester.enterText(fields.at(count - 1), password);
  await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.widgetWithText(FilledButton, l10n.choosePasswordSave));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Choose your own password ($lang)', () {
      testWidgets('after signing in with a one-time password, then signed '
          'in again with the new one', (tester) async {
        final api = FakeManagerApi()..signInMustChange = true;
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, l10n, 'shila@example.org', oneTime);
        expect(find.byType(ChoosePasswordScreen), findsOneWidget);
        expect(find.byType(ManagerShell), findsNothing);
        expect(find.text(l10n.choosePasswordTitle), findsOneWidget);
        expect(find.text(l10n.choosePasswordHint), findsOneWidget);
        expect(
          find.text(l10n.choosePasswordAccount('shila@example.org')),
          findsOneWidget,
        );
        // The one-time password was just typed: it is not asked again.
        expect(find.byKey(const ValueKey('current-password')), findsNothing);

        // Too short, the same as the one-time password, then not repeated.
        await tester.enterText(fieldIn('new-password'), 'short one');
        await save(tester, l10n);
        expect(find.text(l10n.choosePasswordTooShort), findsOneWidget);
        await tester.enterText(fieldIn('new-password'), oneTime);
        await save(tester, l10n);
        expect(find.text(l10n.choosePasswordSame), findsOneWidget);
        await tester.enterText(fieldIn('new-password'), chosen);
        await tester.enterText(fieldIn('repeat-password'), 'three green mango');
        await save(tester, l10n);
        expect(find.text(l10n.choosePasswordMismatch), findsOneWidget);
        expect(api.passwordChanges, isEmpty);

        await tester.enterText(fieldIn('repeat-password'), chosen);
        await save(tester, l10n);
        expect(api.passwordChanges, <(String, String)>[(oneTime, chosen)]);
        // Signed in again, automatically, with the new password.
        expect(api.signIns.last, ('shila@example.org', chosen));
        expect(find.byType(ChoosePasswordScreen), findsNothing);
        expect(find.byType(ManagerShell), findsOneWidget);
        expect(find.text(l10n.choosePasswordSaved), findsOneWidget);
      });

      testWidgets('a refusal of "password change required" from any request '
          'opens the step and asks for the one-time password', (tester) async {
        final api = FakeManagerApi(user: staff('supervisor'));
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.byType(ManagerShell), findsOneWidget);

        api.failWith = const AppProblem(
          ProblemKind.passwordChangeRequired,
          statusCode: 403,
        );
        await tester.tap(find.bySemanticsLabel(l10n.navSubmissions).first);
        await tester.pumpAndSettle();
        expect(find.byType(ChoosePasswordScreen), findsOneWidget);
        expect(find.byType(ManagerShell), findsNothing);
        api.failWith = null;

        // Nothing typed: the one-time password is asked for.
        await tester.enterText(fieldIn('new-password'), chosen);
        await tester.enterText(fieldIn('repeat-password'), chosen);
        await save(tester, l10n);
        expect(find.text(l10n.fieldRequired), findsOneWidget);
        expect(api.passwordChanges, isEmpty);

        await tester.enterText(fieldIn('current-password'), oneTime);
        await save(tester, l10n);
        expect(api.passwordChanges.single, (oneTime, chosen));
        expect(api.signIns.last, ('tania@example.org', chosen));
        expect(find.byType(ManagerShell), findsOneWidget);
      });

      testWidgets('a wrong one-time password is asked for again', (
        tester,
      ) async {
        final api = FakeManagerApi()..signInMustChange = true;
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, l10n, 'shila@example.org', oneTime);
        api.passwordChangeFailure = const AppProblem(
          ProblemKind.detailsInvalid,
          statusCode: 400,
          fields: <String, String>{
            'oldPassword': 'Missing or invalid old password.',
          },
          codes: <String, String>{
            'oldPassword': 'validation_invalid_old_password',
          },
        );
        await tester.enterText(fieldIn('new-password'), chosen);
        await tester.enterText(fieldIn('repeat-password'), chosen);
        await save(tester, l10n);
        expect(find.text(l10n.choosePasswordWrongCurrent), findsOneWidget);
        expect(find.byKey(const ValueKey('current-password')), findsOneWidget);
        expect(find.byType(ChoosePasswordScreen), findsOneWidget);

        await tester.enterText(fieldIn('current-password'), 'kfmw-tqzp-hrvz');
        await tester.pumpAndSettle();
        expect(find.text(l10n.choosePasswordWrongCurrent), findsNothing);
        await save(tester, l10n);
        expect(api.passwordChanges.single, ('kfmw-tqzp-hrvz', chosen));
        expect(find.byType(ManagerShell), findsOneWidget);
      });

      testWidgets('saved, but signing in again failed: sign in by hand', (
        tester,
      ) async {
        final api = FakeManagerApi()..signInMustChange = true;
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, l10n, 'shila@example.org', oneTime);
        api.passwordChangeFailure = const AppProblem(
          ProblemKind.passwordSavedSignIn,
        );
        await tester.enterText(fieldIn('new-password'), chosen);
        await tester.enterText(fieldIn('repeat-password'), chosen);
        await save(tester, l10n);
        expect(find.text(l10n.problemPasswordSavedSignIn), findsOneWidget);
        await tester.tap(find.text(l10n.actionSignInAgain));
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsOneWidget);
      });

      testWidgets('keeping the one-time password is refused in plain words', (
        tester,
      ) async {
        final api = FakeManagerApi()..signInMustChange = true;
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, l10n, 'shila@example.org', oneTime);
        api.passwordChangeFailure = const AppProblem(
          ProblemKind.detailsInvalid,
          statusCode: 400,
          fields: <String, String>{
            'password': 'The new password must be different.',
          },
          codes: <String, String>{'password': 'validation_password_unchanged'},
        );
        await tester.enterText(fieldIn('new-password'), chosen);
        await tester.enterText(fieldIn('repeat-password'), chosen);
        await save(tester, l10n);
        expect(find.text(l10n.choosePasswordSame), findsOneWidget);
        expect(find.byType(ChoosePasswordScreen), findsOneWidget);
      });

      testWidgets('signing out is always possible', (tester) async {
        final api = FakeManagerApi()..signInMustChange = true;
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await signInWith(tester, l10n, 'shila@example.org', oneTime);
        await tester.tap(find.text(l10n.menuSignOut));
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(api.signOuts, 1);
        expect(api.passwordChanges, isEmpty);
        // The language switch stays on screen.
        expect(find.text('English'), findsOneWidget);
        expect(find.text('বাংলা'), findsOneWidget);
      });
    });
  }
}
