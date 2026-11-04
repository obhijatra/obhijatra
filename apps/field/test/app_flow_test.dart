// The whole journey of a field officer, against the fake server: connect to
// the organisation, sign in, fill the core's sample form, finish it with no
// signal (it is queued), then get signal back (it is sent by itself).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'finish_flow_test.dart' show fillHousehold, settleLong;
import 'support/fake_server.dart';
import 'support/harness.dart';

Finder _button(String label) => find.widgetWithText(PrimaryButton, label);

void main() {
  matrix(
    'connect, sign in, fill the form, finish offline, then it sends by itself',
    (tester, language, scale, l) async {
      final server = FakeServer(xform: householdVisitXForm);
      final env = TestEnv(server: server);
      await pumpApp(tester, env, language: language, textScale: scale);

      // 1. Connect to your organisation.
      expect(find.text(l.connectTitle), findsWidgets);
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('server-address-field'))),
        'data.example.org',
      );
      await tester.tap(_button(l.connectTest));
      await settleLong(tester);
      await tester.tap(await reveal(tester, _button(l.actionContinue)));
      await settleLong(tester);

      // 2. Sign in.
      expect(find.text(l.signInTitle), findsWidgets);
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('email-field'))),
        fakeEmail,
      );
      await tester.enterText(
        await reveal(tester, find.byKey(const Key('password-field'))),
        fakePassword,
      );
      await tester.tap(await reveal(tester, _button(l.signInTitle)));
      await settleLong(tester);

      // 3. Today shows the form that came from the server.
      expect(find.text(l.todayTitle), findsWidgets);
      expect(await reveal(tester, find.text('Household visit')), findsWidgets);

      // 4. Start it, fill it in, and finish with no signal.
      env.online.add(false);
      server.submissionGlitch = const NoConnection();
      await tester.tap(await reveal(tester, find.text('Household visit')));
      await settleLong(tester);
      await fillHousehold(tester, language, l);
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);

      // 5. It is queued: the person is told so, and nothing reached the server.
      expect(
        await reveal(tester, find.text(l.outcomeWaitingTitle)),
        findsWidgets,
      );
      expect(server.submissions, isEmpty);
      final queued = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(queued, hasLength(1));
      expect(queued!.single.state, OutboxState.queued);

      // 6. Signal returns: the form is sent without the person doing anything.
      await tester.tap(await reveal(tester, _button(l.outcomeBackToToday)));
      await settleLong(tester);
      server.submissionGlitch = null;
      env.online.add(true);
      await settleLong(tester);
      expect(server.submissions, hasLength(1));
      final sent = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(sent!.single.state, OutboxState.sent);
      expect(find.textContaining(l.offlineTitle), findsNothing);
      await endTest(tester, env);
    },
  );
}
