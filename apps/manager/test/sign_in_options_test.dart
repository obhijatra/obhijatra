import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/url_opener.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

/// Records the addresses the app asks the browser to open.
class FakeOpener {
  final List<Uri> opened = <Uri>[];

  Future<bool> call(Uri url) async {
    opened.add(url);
    return true;
  }

  List<Override> get overrides => <Override>[
    urlOpenerProvider.overrideWithValue(call),
  ];
}

/// A button of kind [T] (or a subclass, such as `OutlinedButton.icon`)
/// labelled [label].
Finder button<T extends Widget>(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is T),
);

Finder outlined(String label) => button<OutlinedButton>(label);
Finder filled(String label) => button<FilledButton>(label);
Finder textButton(String label) => button<TextButton>(label);

/// The desktop app asks for the server address first; the web app does
/// not show the field.
Future<void> typeServer(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  if (fields.evaluate().length == 3) {
    await tester.enterText(fields.first, 'https://data.example.org');
    await tester.pump();
  }
}

/// Starts the app afresh (a new set of providers) on the sign-in screen,
/// with the server address typed.
Future<void> pumpSignIn(
  WidgetTester tester,
  FakeManagerApi api, {
  required String lang,
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(const SizedBox());
  await pumpManager(tester, api, lang: lang, overrides: overrides);
  await typeServer(tester);
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the SMS steps and asks for a code for 01712-345678.
Future<AppLocalizations> toCodeStep(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  await tapAndSettle(tester, outlined(l10n.signInSms));
  await tester.enterText(find.byType(TextField), '01712-345678');
  await tapAndSettle(tester, filled(l10n.smsSendCode));
  return l10n;
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Sign-in options ($lang)', () {
      testWidgets('shows only the ways to sign in the server offers', (
        tester,
      ) async {
        final api = FakeManagerApi();
        await pumpSignIn(tester, api, lang: lang);
        var l10n = l10nOf(tester);
        expect(find.text(l10n.signInGoogle), findsNothing);
        expect(find.text(l10n.signInSms), findsNothing);
        expect(find.text(l10n.signInOr), findsNothing);

        api.methods = const SignInMethods(google: true, phone: true);
        await pumpSignIn(tester, api, lang: lang);
        l10n = l10nOf(tester);
        // Email and password stay first; the others follow.
        expect(
          tester.getTopLeft(filled(l10n.signInButton)).dy,
          lessThan(tester.getTopLeft(outlined(l10n.signInGoogle)).dy),
        );
        expect(outlined(l10n.signInGoogle), findsOneWidget);
        expect(outlined(l10n.signInSms), findsOneWidget);
        expect(find.text(l10n.signInSmsAdminNote), findsOneWidget);

        api.methods = const SignInMethods(google: true);
        await pumpSignIn(tester, api, lang: lang);
        expect(outlined(l10n.signInGoogle), findsOneWidget);
        expect(find.text(l10n.signInSms), findsNothing);
        expect(find.text(l10n.signInSmsAdminNote), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SMS: number, then code, then signed in', (tester) async {
        final api = FakeManagerApi()
          ..methods = const SignInMethods(phone: true);
        await pumpSignIn(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await tapAndSettle(tester, outlined(l10n.signInSms));
        // The number step says admins cannot use codes, and shows +880.
        expect(find.text(l10n.signInSmsAdminNote), findsOneWidget);
        expect(find.textContaining('+880'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '01712-345678');
        await tapAndSettle(tester, filled(l10n.smsSendCode));
        expect(api.codeRequests, <String>['+8801712345678']);
        // The same words whether or not the number has an account.
        expect(find.text(l10n.smsCodeSent('+880 1712-345678')), findsOneWidget);
        expect(
          find.textContaining(l10n.smsResendIn('').trim()),
          findsOneWidget,
        );
        // Typing the sixth digit signs in; no button press is needed.
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();
        expect(api.codeChecks, <(String, String)>[('code1', '123456')]);
        expect(find.byType(SignInScreen), findsNothing);
        expect(find.text(l10n.navForms), findsWidgets);
      });

      testWidgets('SMS: wrong codes, a used-up code, a new code', (
        tester,
      ) async {
        final api = FakeManagerApi()
          ..methods = const SignInMethods(phone: true);
        await pumpSignIn(tester, api, lang: lang);
        final l10n = await toCodeStep(tester);

        await tester.enterText(find.byType(TextField), '000000');
        await tester.pumpAndSettle();
        expect(find.text(l10n.smsCodeWrong), findsOneWidget);
        expect(find.byType(SignInScreen), findsOneWidget);
        // The field is emptied for the next try.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );

        await tester.enterText(find.byType(TextField), '111111');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '222222');
        await tester.pumpAndSettle();
        expect(find.text(l10n.smsCodeUsedUp), findsOneWidget);
        expect(
          tester.widget<FilledButton>(filled(l10n.signInButton)).onPressed,
          isNull,
        );
        expect(api.codeChecks, hasLength(3));

        // A new code can be asked for after a minute.
        final countdown = find.ancestor(
          of: find.textContaining(l10n.smsResendIn('').trim()),
          matching: find.byType(TextButton),
        );
        expect(
          tester.widget<TextButton>(countdown).onPressed,
          isNull,
          reason: 'not before the minute is up',
        );
        expect(textButton(l10n.smsResend), findsNothing);
        await tester.pump(const Duration(seconds: 61));
        await tapAndSettle(tester, textButton(l10n.smsResend));
        expect(api.codeRequests, hasLength(2));
        expect(find.text(l10n.smsNewCodeSent), findsOneWidget);
        expect(find.text(l10n.smsCodeUsedUp), findsNothing);

        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();
        expect(api.codeChecks.last, ('code2', '123456'));
        expect(find.byType(SignInScreen), findsNothing);
      });

      testWidgets('SMS: a code expires after five minutes', (tester) async {
        final api = FakeManagerApi()
          ..methods = const SignInMethods(phone: true);
        await pumpSignIn(tester, api, lang: lang);
        final l10n = await toCodeStep(tester);
        await tester.pump(const Duration(minutes: 5, seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.smsCodeExpired), findsOneWidget);
        expect(
          tester.widget<FilledButton>(filled(l10n.signInButton)).onPressed,
          isNull,
        );
      });

      testWidgets('SMS: a number that is not a mobile number is caught, and '
          '"Other ways to sign in" goes back', (tester) async {
        final api = FakeManagerApi()
          ..methods = const SignInMethods(phone: true);
        await pumpSignIn(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await tapAndSettle(tester, outlined(l10n.signInSms));
        await tester.enterText(find.byType(TextField), '12345');
        await tapAndSettle(tester, filled(l10n.smsSendCode));
        expect(find.text(l10n.smsNumberInvalid), findsOneWidget);
        expect(api.codeRequests, isEmpty);

        await tapAndSettle(tester, textButton(l10n.signInOtherWays));
        expect(find.text(l10n.signInEmail), findsOneWidget);
        expect(outlined(l10n.signInSms), findsOneWidget);
      });

      testWidgets('SMS: switched off on the server says so plainly', (
        tester,
      ) async {
        final api = FakeManagerApi()
          ..methods = const SignInMethods(phone: true)
          ..codeRequestFailure = const AppProblem(ProblemKind.smsOff);
        await pumpSignIn(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await tapAndSettle(tester, outlined(l10n.signInSms));
        await tester.enterText(find.byType(TextField), '01712345678');
        await tapAndSettle(tester, filled(l10n.smsSendCode));
        expect(find.text(l10n.problemSmsOff), findsOneWidget);
      });

      testWidgets('Google: waits for the browser and can be cancelled', (
        tester,
      ) async {
        final opener = FakeOpener();
        final api = FakeManagerApi()
          ..methods = const SignInMethods(google: true);
        await pumpSignIn(tester, api, lang: lang, overrides: opener.overrides);
        final l10n = l10nOf(tester);
        await tester.tap(outlined(l10n.signInGoogle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(l10n.googleWaitingTitle), findsOneWidget);
        expect(api.googleWaiting, isTrue);
        expect(opener.opened, <Uri>[api.googlePage]);

        // If the browser blocked the page, the person opens it themselves.
        await tester.tap(outlined(l10n.googleOpen));
        await tester.pump();
        expect(opener.opened, <Uri>[api.googlePage, api.googlePage]);

        await tester.tap(textButton(l10n.actionCancel));
        await tester.pumpAndSettle();
        expect(api.googleWaiting, isFalse);
        expect(find.text(l10n.googleWaitingTitle), findsNothing);
        expect(outlined(l10n.signInGoogle), findsOneWidget);
        expect(find.byType(SignInScreen), findsOneWidget);
      });

      testWidgets('Google: a refusal is one plain, translated sentence', (
        tester,
      ) async {
        final api = FakeManagerApi()
          ..methods = const SignInMethods(google: true);
        await pumpSignIn(
          tester,
          api,
          lang: lang,
          overrides: FakeOpener().overrides,
        );
        final l10n = l10nOf(tester);
        await tester.tap(outlined(l10n.signInGoogle));
        await tester.pump();
        api.googleResult.completeError(
          const AppProblem(ProblemKind.googleNoAccount, statusCode: 400),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.problemGoogleNoAccount), findsOneWidget);
        expect(find.byType(SignInScreen), findsOneWidget);
        await tapAndSettle(tester, textButton(l10n.actionClose));
        expect(find.text(l10n.problemGoogleNoAccount), findsNothing);
      });

      testWidgets('Google: signs in when the browser comes back', (
        tester,
      ) async {
        final api = FakeManagerApi()
          ..methods = const SignInMethods(google: true);
        await pumpSignIn(
          tester,
          api,
          lang: lang,
          overrides: FakeOpener().overrides,
        );
        final l10n = l10nOf(tester);
        await tester.tap(outlined(l10n.signInGoogle));
        await tester.pump();
        api.googleResult.complete(staff('supervisor'));
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsNothing);
        expect(find.text(l10n.navForms), findsWidgets);
      });
    });
  }
}
