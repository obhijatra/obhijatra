import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/url_opener.dart';
import 'package:obhijatra_manager/src/ui/sign_in_methods_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

Finder button<T extends Widget>(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is T),
);

/// The text field inside the widget with [key].
Finder fieldIn(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(EditableText),
);

TextEditingController controllerOf(WidgetTester tester, String key) =>
    tester.widget<EditableText>(fieldIn(key)).controller;

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Settings already saved on the server: Google on, an SMS provider set
/// up, secrets saved, and a last send that failed.
SignInSettings savedSettings() => SignInSettings(
  google: const GoogleSignInSettings(
    enabled: true,
    clientId: '123456789012-abc123.apps.googleusercontent.com',
    clientSecretSet: true,
    redirectUrl: 'https://data.example.org/api/oauth2-redirect',
  ),
  phone: PhoneSignInSettings(
    enabled: true,
    sms: const SmsProviderSettings(
      url: 'https://api.example-sms.com/v1/send',
      body: '{"to": "{phone_digits}", "text": "{message}"}',
      headers: <SmsHeader>[
        SmsHeader(name: 'Authorization', value: 'Bearer {secret}'),
      ],
      secretSet: true,
      successText: 'SUCCESS',
    ),
    lastSend: SmsSendResult(
      at: DateTime(2026, 11, 4, 9, 15),
      ok: false,
      status: 401,
      reply: 'Unauthorised',
    ),
  ),
);

/// Opens Settings, then Sign-in methods, as an org admin.
Future<AppLocalizations> openSignInMethods(
  WidgetTester tester,
  FakeManagerApi api, {
  required String lang,
  List<Override> overrides = const <Override>[],
}) async {
  await pumpManager(tester, api, lang: lang, overrides: overrides);
  final l10n = l10nOf(tester);
  await tester.tap(find.bySemanticsLabel(l10n.navSettings).first);
  await tester.pumpAndSettle();
  await tapAndSettle(tester, button<OutlinedButton>(l10n.signInMethodsOpen));
  expect(find.byType(SignInMethodsScreen), findsOneWidget);
  return l10n;
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Sign-in methods ($lang)', () {
      testWidgets('only organisation admins see them', (tester) async {
        for (final role in <String>[
          'supervisor',
          'branch_manager',
          'me',
          'donor_readonly',
        ]) {
          await tester.pumpWidget(const SizedBox());
          await pumpManager(
            tester,
            FakeManagerApi(user: staff(role)),
            lang: lang,
          );
          final l10n = l10nOf(tester);
          await tester.tap(find.bySemanticsLabel(l10n.navSettings).first);
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.signInMethodsTitle),
            findsNothing,
            reason: role,
          );
          expect(find.text(l10n.signInMethodsOpen), findsNothing, reason: role);
        }
        await tester.pumpWidget(const SizedBox());
        final api = FakeManagerApi(user: staff('org_admin'))
          ..settings = savedSettings();
        final l10n = await openSignInMethods(tester, api, lang: lang);
        for (final label in <String>[
          l10n.googleTitle,
          l10n.googleRedirectLabel,
          l10n.googleClientId,
          l10n.googleClientSecret,
          l10n.smsTitle,
          l10n.smsMethod,
          l10n.smsAddress,
          l10n.smsBodyFormat,
          l10n.smsBody,
          l10n.smsHeaders,
          l10n.smsSecret,
          l10n.smsSuccessText,
          l10n.smsTestTitle,
          l10n.actionSave,
        ]) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        expect(
          find.text('https://data.example.org/api/oauth2-redirect'),
          findsOneWidget,
        );
        // The address is fine for Google: no warning.
        expect(find.text(l10n.googleRedirectWarning), findsNothing);
        // The server's last send is shown.
        expect(find.text(l10n.smsResultLast), findsOneWidget);
        expect(find.text(l10n.smsResultNotSent), findsOneWidget);
        expect(find.text(l10n.smsResultStatus('401')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the guide and the redirect address can be opened and '
          'copied', (tester) async {
        final opened = <Uri>[];
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add(
                (call.arguments as Map<Object?, Object?>)['text']! as String,
              );
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final api = FakeManagerApi(user: staff('org_admin'));
        final l10n = await openSignInMethods(
          tester,
          api,
          lang: lang,
          overrides: <Override>[
            urlOpenerProvider.overrideWithValue((url) async {
              opened.add(url);
              return true;
            }),
          ],
        );
        await tapAndSettle(tester, button<TextButton>(l10n.setupGuide).first);
        expect(opened.single.toString(), startsWith(signInGuideUrl));
        await tapAndSettle(tester, button<TextButton>(l10n.actionCopy));
        expect(copied, <String>[
          'https://data.example.org/api/oauth2-redirect',
        ]);
        expect(find.text(l10n.copiedRedirect), findsOneWidget);
      });

      testWidgets('warns when Google cannot use the server’s address', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..settings = const SignInSettings(
            google: GoogleSignInSettings(
              redirectUrl: 'http://192.168.1.10:8090/api/oauth2-redirect',
            ),
          );
        final l10n = await openSignInMethods(tester, api, lang: lang);
        expect(find.text(l10n.googleRedirectWarning), findsOneWidget);
      });

      testWidgets('saving sends everything; empty secrets keep the saved '
          'ones', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..settings = savedSettings();
        final l10n = await openSignInMethods(tester, api, lang: lang);
        // Both secrets are saved: the fields are empty and say so.
        expect(find.text(l10n.secretSavedKeep), findsNWidgets(2));
        expect(controllerOf(tester, 'google-secret').text, isEmpty);
        expect(controllerOf(tester, 'sms-secret').text, isEmpty);

        await tapAndSettle(
          tester,
          find.byKey(const ValueKey<String>('sms-switch')),
        );
        expect(find.text(l10n.unsavedChanges), findsOneWidget);
        await tapAndSettle(tester, button<FilledButton>(l10n.actionSave));
        final first = api.saves.single;
        expect(first.googleEnabled, isTrue);
        expect(first.googleClientSecret, isEmpty);
        expect(first.phoneEnabled, isFalse);
        expect(first.sms.secret, isEmpty);
        expect(first.sms.url, 'https://api.example-sms.com/v1/send');
        expect(first.sms.headers.single.value, 'Bearer {secret}');
        expect(find.text(l10n.signInMethodsSaved), findsOneWidget);
        expect(find.text(l10n.unsavedChanges), findsNothing);

        // Let the message go, so it does not cover the Save button.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // A new secret is sent once, then the field is empty again.
        await tester.enterText(fieldIn('google-secret'), 'GOCSPX-new-secret');
        await tester.enterText(fieldIn('sms-secret'), 'sms-api-key');
        await tapAndSettle(tester, button<FilledButton>(l10n.actionSave));
        expect(api.saves.last.googleClientSecret, 'GOCSPX-new-secret');
        expect(api.saves.last.sms.secret, 'sms-api-key');
        expect(controllerOf(tester, 'google-secret').text, isEmpty);
        expect(controllerOf(tester, 'sms-secret').text, isEmpty);
      });

      testWidgets('refused fields are shown under each field', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..settings = const SignInSettings(
            google: GoogleSignInSettings(
              redirectUrl: 'https://data.example.org/api/oauth2-redirect',
            ),
          );
        final l10n = await openSignInMethods(tester, api, lang: lang);
        // Two header rows: the first left empty, the second refused.
        await tapAndSettle(tester, button<TextButton>(l10n.smsHeaderAdd));
        await tapAndSettle(tester, button<TextButton>(l10n.smsHeaderAdd));
        final names = find.ancestor(
          of: find.text(l10n.smsHeaderName),
          matching: find.byType(TextField),
        );
        await tester.enterText(names.at(1), 'Host');
        await tester.pump();

        const idProblem =
            'This does not look like a Google client ID. It ends with '
            '.apps.googleusercontent.com.';
        const urlProblem =
            'The address must start with https:// so the codes and your key '
            'travel encrypted.';
        const headerProblem =
            'The server sets the Host header itself; remove it.';
        const otherProblem = 'Something else needs attention.';
        api.saveFailure = const AppProblem(
          ProblemKind.settingsInvalid,
          statusCode: 400,
          fields: <String, String>{
            'google.client_id': idProblem,
            'phone.sms.url': urlProblem,
            // The empty row is not sent, so the server's row 0 is "Host".
            'phone.sms.headers.0': headerProblem,
            'phone.sms.something': otherProblem,
          },
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('sms-address')),
          'http://sms.example.com/send',
        );
        await tapAndSettle(tester, button<FilledButton>(l10n.actionSave));
        expect(api.saves, isEmpty);
        expect(find.text(l10n.problemSettingsInvalid), findsOneWidget);
        expect(find.text(idProblem), findsOneWidget);
        expect(find.text(urlProblem), findsOneWidget);
        expect(find.text(headerProblem), findsOneWidget);
        expect(find.text(otherProblem), findsOneWidget);
        // The header message sits under the "Host" row, not the empty one.
        expect(
          tester.getTopLeft(find.text(headerProblem)).dy,
          greaterThan(tester.getTopLeft(names.at(1)).dy),
        );

        // Changing a field clears its message.
        await tester.enterText(
          find.descendant(
            of: find.ancestor(
              of: find.text(l10n.googleClientId),
              matching: find.byType(TextField),
            ),
            matching: find.byType(EditableText),
          ),
          '123456789012-abc.apps.googleusercontent.com',
        );
        await tester.pumpAndSettle();
        expect(find.text(idProblem), findsNothing);
        expect(find.text(urlProblem), findsOneWidget);
      });

      testWidgets('a test SMS shows what the provider answered', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..settings = savedSettings();
        final l10n = await openSignInMethods(tester, api, lang: lang);
        final number = fieldIn('sms-test-phone');
        await tester.ensureVisible(number);
        await tester.enterText(number, '12');
        await tapAndSettle(tester, button<OutlinedButton>(l10n.smsTestButton));
        expect(find.text(l10n.smsNumberInvalid), findsOneWidget);
        expect(api.tests, isEmpty);

        await tester.enterText(number, '01712 345678');
        await tapAndSettle(tester, button<OutlinedButton>(l10n.smsTestButton));
        expect(api.tests.single.$1, '+8801712345678');
        // Unsaved settings are tested as typed.
        expect(api.tests.single.$2.url, 'https://api.example-sms.com/v1/send');
        expect(find.text(l10n.smsResultTest), findsOneWidget);
        expect(find.text(l10n.smsResultSent), findsOneWidget);
        expect(find.text(l10n.smsResultStatus('200')), findsOneWidget);
        expect(find.text('{"status":"SUCCESS"}'), findsOneWidget);

        api.testResult = SmsSendResult(
          at: DateTime(2026, 11, 5, 14, 40),
          ok: false,
          status: 0,
          reply: 'Could not reach the SMS provider: connection refused',
        );
        await tapAndSettle(tester, button<OutlinedButton>(l10n.smsTestButton));
        expect(find.text(l10n.smsResultNotSent), findsOneWidget);
        expect(find.text(l10n.smsResultNoAnswer), findsOneWidget);
        expect(
          find.text('Could not reach the SMS provider: connection refused'),
          findsOneWidget,
        );

        api.testFailure = const AppProblem(ProblemKind.tooManyTests);
        await tapAndSettle(tester, button<OutlinedButton>(l10n.smsTestButton));
        expect(find.text(l10n.problemTooManyTests), findsOneWidget);
      });

      testWidgets('placeholders go where the cursor is', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        await openSignInMethods(tester, api, lang: lang);
        final body = find.byKey(const ValueKey<String>('sms-body'));
        await tester.ensureVisible(body);
        await tester.enterText(body, '{"to": "", "text": ""}');
        await tester.pump();
        final bodyText = controllerOf(tester, 'sms-body');
        bodyText.selection = const TextSelection.collapsed(offset: 8);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey<String>('insert-{phone_digits}')),
        );
        expect(bodyText.text, '{"to": "{phone_digits}", "text": ""}');
        final textQuotes = bodyText.text.indexOf('"text": "') + 9;
        bodyText.selection = TextSelection.collapsed(offset: textQuotes);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey<String>('insert-{message}')),
        );
        expect(bodyText.text, '{"to": "{phone_digits}", "text": "{message}"}');

        // The address, once it was the last field used.
        final address = find.byKey(const ValueKey<String>('sms-address'));
        await tester.ensureVisible(address);
        await tester.enterText(address, 'https://sms.example.com/send?to=');
        await tester.pump();
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey<String>('insert-{phone}')),
        );
        expect(
          controllerOf(tester, 'sms-address').text,
          'https://sms.example.com/send?to={phone}',
        );
        expect(bodyText.text, '{"to": "{phone_digits}", "text": "{message}"}');
      });

      testWidgets('GET has no body; headers are limited to ten', (
        tester,
      ) async {
        final api = FakeManagerApi(user: staff('org_admin'));
        final l10n = await openSignInMethods(tester, api, lang: lang);
        // Empty settings start as POST with a JSON body.
        expect(find.byKey(const ValueKey<String>('sms-body')), findsOneWidget);
        await tapAndSettle(tester, find.text('GET'));
        expect(find.byKey(const ValueKey<String>('sms-body')), findsNothing);
        expect(find.text(l10n.smsBodyFormat), findsNothing);

        final add = button<TextButton>(l10n.smsHeaderAdd);
        for (var i = 0; i < maxSmsHeaders; i++) {
          await tapAndSettle(tester, add);
        }
        expect(tester.widget<TextButton>(add).onPressed, isNull);
        expect(find.text(l10n.smsHeadersMax(maxSmsHeaders)), findsOneWidget);
        await tapAndSettle(tester, find.byTooltip(l10n.smsHeaderRemove).first);
        expect(tester.widget<TextButton>(add).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('asks before leaving with unsaved changes', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..settings = savedSettings();
        final l10n = await openSignInMethods(tester, api, lang: lang);
        await tester.enterText(
          find.byKey(const ValueKey<String>('sms-success')),
          'ACCEPTED',
        );
        await tester.pump();
        expect(find.text(l10n.unsavedChanges), findsOneWidget);

        // Another place in the menu: the person can stay.
        await tester.tap(find.bySemanticsLabel(l10n.navForms).first);
        await tester.pumpAndSettle();
        expect(find.text(l10n.leaveTitle), findsOneWidget);
        await tester.tap(button<TextButton>(l10n.leaveStay));
        await tester.pumpAndSettle();
        expect(find.byType(SignInMethodsScreen), findsOneWidget);
        expect(controllerOf(tester, 'sms-success').text, 'ACCEPTED');

        // Back to Settings: the person can leave without saving.
        await tester.tap(button<TextButton>(l10n.settingsBack));
        await tester.pumpAndSettle();
        await tester.tap(button<FilledButton>(l10n.leaveDiscard));
        await tester.pumpAndSettle();
        expect(find.byType(SignInMethodsScreen), findsNothing);
        expect(find.text(l10n.settingsLanguage), findsOneWidget);
        expect(api.saves, isEmpty);

        // With nothing changed, nobody is asked.
        await tapAndSettle(
          tester,
          button<OutlinedButton>(l10n.signInMethodsOpen),
        );
        await tester.tap(find.bySemanticsLabel(l10n.navForms).first);
        await tester.pumpAndSettle();
        expect(find.text(l10n.leaveTitle), findsNothing);
        expect(find.byType(SignInMethodsScreen), findsNothing);
      });
    });
  }
}
