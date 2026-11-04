import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/screens/connect_screen.dart';
import 'package:obhijatra_field/src/screens/sign_in_screen.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'support/fake_server.dart';
import 'support/harness.dart';

Finder _button(String label) => find.widgetWithText(PrimaryButton, label);

void main() {
  group('parseServerAddress', () {
    test('adds https and keeps only the origin', () {
      final r = parseServerAddress('  data.example.org/some/path ');
      expect(r.address, Uri.parse('https://data.example.org'));
      expect(r.issue, isNull);
    });
    test('refuses empty, odd and unprotected addresses', () {
      expect(parseServerAddress('').issue, AddressIssue.empty);
      expect(parseServerAddress('two words.org').issue, AddressIssue.shape);
      expect(parseServerAddress('nodots').issue, AddressIssue.shape);
      expect(
        parseServerAddress('http://data.example.org').issue,
        AddressIssue.insecure,
      );
    });
    test('allows plain http only on the local network', () {
      expect(
        parseServerAddress('http://192.168.1.5:8090').address,
        Uri.parse('http://192.168.1.5:8090'),
      );
      expect(parseServerAddress('http://localhost:8090').issue, isNull);
    });
  });

  group('Connect', () {
    matrix('asks for an address before testing', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      await pumpScreen(
        tester,
        env,
        const ConnectScreen(),
        language: language,
        textScale: scale,
      );
      expect(find.text(l.connectTitle), findsWidgets);
      await tester.tap(_button(l.connectTest));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.connectErrorEmpty)),
        findsOneWidget,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('server-address-field'))),
        'http://data.example.org',
      );
      await tester.tap(_button(l.connectTest));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.connectErrorInsecure)),
        findsOneWidget,
      );
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });

    matrix('tests the connection, then saves the address', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      await pumpScreen(
        tester,
        env,
        const ConnectScreen(),
        language: language,
        textScale: scale,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('server-address-field'))),
        'data.example.org',
      );
      await tester.tap(_button(l.connectTest));
      await settleApp(tester);
      expect(await reveal(tester, find.text(l.connectSuccess)), findsWidgets);
      await tester.tap(await reveal(tester, _button(l.actionContinue)));
      await settleApp(tester);
      final saved = await tester.runAsync(
        () => SettingsRepository(env.db).read(serverUrlSettingKey0),
      );
      expect(saved, 'https://data.example.org');
      await endTest(tester, env);
    });

    matrix('says plainly when the address is a website, not Obhijatra', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv()..server.isWebsite = true;
      await pumpScreen(
        tester,
        env,
        const ConnectScreen(),
        language: language,
        textScale: scale,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('server-address-field'))),
        'data.example.org',
      );
      await tester.tap(_button(l.connectTest));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.connectWrongAddress)),
        findsOneWidget,
      );
      expect(_button(l.actionContinue), findsNothing);
      await endTest(tester, env);
    });

    matrix('says plainly when there is no connection', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv()..server.metaGlitch = const NoConnection();
      await pumpScreen(
        tester,
        env,
        const ConnectScreen(),
        language: language,
        textScale: scale,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('server-address-field'))),
        'data.example.org',
      );
      await tester.tap(_button(l.connectTest));
      await settleApp(tester);
      expect(await reveal(tester, find.text(l.connectOffline)), findsOneWidget);
      expect(_button(l.actionContinue), findsNothing);
      await endTest(tester, env);
    });

    matrix('tells the person to update an app that is too old', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv()
        ..server.meta = <String, Object?>{
          ...FakeServer().meta,
          'min_client_version': '9.0.0',
        };
      await pumpScreen(
        tester,
        env,
        const ConnectScreen(),
        language: language,
        textScale: scale,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('server-address-field'))),
        'data.example.org',
      );
      await tester.tap(_button(l.connectTest));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.problem_appUpdateRequired)),
        findsOneWidget,
      );
      expect(_button(l.actionContinue), findsNothing);
      await endTest(tester, env);
    });
  });

  group('Sign in', () {
    Future<TestEnv> open(
      WidgetTester tester,
      String language,
      double scale, {
      FakeServer? server,
    }) async {
      final env = TestEnv(server: server);
      await tester.runAsync(() => env.seedSignedIn(signedIn: false));
      await pumpScreen(
        tester,
        env,
        const SignInScreen(),
        language: language,
        textScale: scale,
      );
      return env;
    }

    matrix('asks for both fields', (tester, language, scale, l) async {
      final env = await open(tester, language, scale);
      expect(find.text(l.signInServer('data.example.org')), findsOneWidget);
      await tester.tap(_button(l.signInTitle));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.signInEmptyEmail)),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.signInEmptyPassword)),
        findsOneWidget,
      );
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });

    matrix('a wrong password gets a plain sentence', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await open(tester, language, scale);
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('email-field'))),
        fakeEmail,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('password-field'))),
        'wrong',
      );
      await tester.tap(_button(l.signInTitle));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.problem_signInFailed)),
        findsWidgets,
      );
      expect(containerOf(tester).read(sessionProvider), isNull);
      await endTest(tester, env);
    });

    matrix('offline says so and keeps what was typed', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await open(
        tester,
        language,
        scale,
        server: FakeServer()..signInGlitch = const NoConnection(),
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('email-field'))),
        fakeEmail,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('password-field'))),
        fakePassword,
      );
      await tester.tap(_button(l.signInTitle));
      await settleApp(tester);
      expect(await reveal(tester, find.text(l.problem_offline)), findsWidgets);
      expect(await reveal(tester, find.text(fakeEmail)), findsOneWidget);
      await endTest(tester, env);
    });

    matrix('the right password signs in', (tester, language, scale, l) async {
      final env = await open(tester, language, scale);
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('email-field'))),
        fakeEmail,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('password-field'))),
        fakePassword,
      );
      await tester.tap(_button(l.signInTitle));
      await settleApp(tester);
      expect(containerOf(tester).read(sessionProvider)?.name, 'Rahima Akter');
      await endTest(tester, env);
    });
  });
}
