import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/config/server_address.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';

void main() {
  group('parseServerAddress', () {
    test('adds https when no scheme is typed and keeps only the origin', () {
      final r = parseServerAddress(' data.example.org/some/path/ ');
      expect(r.issue, isNull);
      expect(r.address.toString(), 'https://data.example.org');
      expect(
        parseServerAddress('https://data.example.org:8443/').address.toString(),
        'https://data.example.org:8443',
      );
    });

    test('refuses empty text and text that is not an address', () {
      expect(parseServerAddress('  ').issue, AddressIssue.empty);
      expect(parseServerAddress('not an address').issue, AddressIssue.shape);
      expect(
        parseServerAddress('ftp://data.example.org').issue,
        AddressIssue.shape,
      );
      expect(parseServerAddress('https://nodots').issue, AddressIssue.shape);
    });

    test('refuses http on the open internet', () {
      for (final text in <String>[
        'http://data.example.org',
        'http://8.8.8.8',
        'http://172.32.0.1',
        'http://172.15.0.1',
        'http://192.169.1.1',
        'http://11.0.0.1',
      ]) {
        expect(
          parseServerAddress(text).issue,
          AddressIssue.insecure,
          reason: text,
        );
      }
    });

    test('allows http on this computer and private networks, for testing', () {
      for (final text in <String>[
        'http://localhost:8090',
        'http://127.0.0.1:8090',
        'http://10.1.2.3',
        'http://172.16.0.5',
        'http://172.31.255.1',
        'http://192.168.0.20:8090',
      ]) {
        final r = parseServerAddress(text);
        expect(r.issue, isNull, reason: text);
        expect(isTestingAddress(r.address!), isTrue, reason: text);
      }
    });

    test('https is never a testing address', () {
      expect(
        isTestingAddress(parseServerAddress('https://192.168.0.20').address!),
        isFalse,
      );
    });
  });

  // The server field is shown on desktop only, so on the web build the sign-in
  // screen has nothing to check; the rule above is what the desktop uses.
  if (!kIsWeb) {
    for (final lang in <String>['en', 'bn']) {
      testWidgets('sign-in refuses http on the internet ($lang)', (
        tester,
      ) async {
        await pumpManager(tester, FakeManagerApi(), lang: lang);
        final l10n = l10nOf(tester);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'http://data.example.org');
        await tester.enterText(fields.at(1), 'a@b.org');
        await tester.enterText(fields.at(2), 'a-long-password');
        await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
        await tester.pumpAndSettle();
        expect(find.text(l10n.serverInsecure), findsOneWidget);
      });

      testWidgets('sign-in shows a testing-only note on a private address '
          '($lang)', (tester) async {
        await pumpManager(tester, FakeManagerApi(), lang: lang);
        final l10n = l10nOf(tester);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'http://192.168.0.20:8090',
        );
        await tester.pump();
        expect(find.text(l10n.serverTestingOnly), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'https://data.example.org',
        );
        await tester.pump();
        expect(find.text(l10n.serverTestingOnly), findsNothing);
      });
    }
  }
}
