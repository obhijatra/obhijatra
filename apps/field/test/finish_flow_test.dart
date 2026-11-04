import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/screens/form_entry_screen.dart';
import 'package:obhijatra_field/src/screens/outcome_screen.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'support/harness.dart';

/// Waits longer than [settleApp]: sending touches the database and the
/// (fake) network several times.
Future<void> settleLong(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Finder _button(String label) => find.widgetWithText(PrimaryButton, label);

Future<void> _next(WidgetTester tester, AppLocalizations l) async {
  // The last question's button says Finish in some forms and Next in others;
  // either way it opens the finish screen.
  final label = _button(l.entryFinish).evaluate().isNotEmpty
      ? l.entryFinish
      : l.entryNext;
  await tester.tap(await reveal(tester, _button(label)));
  await settleApp(tester);
}

Future<void> _pickToday(WidgetTester tester, AppLocalizations l) async {
  await tester.tap(await reveal(tester, find.text(l.pickDate)));
  await settleApp(tester);
  final ok = MaterialLocalizations.of(
    tester.element(find.byType(DatePickerDialog)),
  ).okButtonLabel;
  await tester.tap(find.text(ok));
  await settleApp(tester);
}

/// Answers the household visit form from the first question to the last.
Future<void> fillHousehold(
  WidgetTester tester,
  String language,
  AppLocalizations l,
) async {
  final bn = language == 'bn';
  await _pickToday(tester, l);
  await _next(tester, l);
  await tester.tap(
    await reveal(
      tester,
      find.text(bn ? 'খানার সাথে দেখা হয়েছে' : 'Met the household'),
    ),
  );
  await settleApp(tester);
  await _next(tester, l);
  await tester.enterText(
    await reveal(tester, find.byType(EditableText).first),
    'Karim',
  );
  await _next(tester, l);
  await tester.enterText(
    await reveal(tester, find.byType(EditableText).first),
    bn ? '৪' : '4',
  );
  await _next(tester, l);
  await tester.enterText(
    await reveal(tester, find.byType(EditableText).first),
    bn ? '১' : '1',
  );
  await _next(tester, l);
  await _next(tester, l); // notes, left empty; opens the finish screen
}

Future<TestEnv> openHousehold(
  WidgetTester tester,
  String language,
  double scale, {
  FakeObhijatraServer? server,
}) async {
  final env = TestEnv(xform: householdVisitXForm, server: server);
  await tester.runAsync(() async {
    await env.seedSignedIn();
    await env.storeForm(householdVisitXForm);
  });
  await pumpScreen(
    tester,
    env,
    const FormEntryScreen(
      args: FormEntryArgs(formId: 'household_visit', token: 1),
    ),
    language: language,
    textScale: scale,
  );
  return env;
}

void main() {
  group('Outcome screen', () {
    matrix('shows each of the three results in plain words', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv();
      final cases = <SendOutcome, List<String>>{
        SendOutcome.sent(testNow): <String>[
          l.outcomeSentTitle,
          l.outcomeSentBody,
        ],
        const SendOutcome.waiting(2): <String>[
          l.outcomeWaitingTitle,
          l.outcomeWaitingBody,
        ],
        const SendOutcome.problem(ProblemCode.appUpdateRequired): <String>[
          l.outcomeProblemTitle,
          l.outcomeProblemSafe,
          l.problem_appUpdateRequired,
        ],
        const SendOutcome.problem(ProblemCode.signInRequired): <String>[
          l.outcomeProblemTitle,
          l.problem_signInRequired,
          l.outcomeSignIn,
        ],
        const SendOutcome.problem(ProblemCode.clockSkew): <String>[
          l.outcomeProblemTitle,
          l.problem_clockSkew,
          l.outcomeProblemSafe,
          l.outcomeNext,
        ],
      };
      for (final entry in cases.entries) {
        await pumpScreen(
          tester,
          env,
          OutcomeScreen(outcome: entry.key, formId: 'household_visit'),
          language: language,
          textScale: scale,
        );
        for (final words in entry.value) {
          expect(
            await reveal(tester, find.text(words)),
            findsWidgets,
            reason: words,
          );
        }
        await expectAccessibleTargets(tester);
      }
      await endTest(tester, env);
    });
  });

  group('Finish and send', () {
    matrix('sends the form and says Sent', (tester, language, scale, l) async {
      final env = await openHousehold(tester, language, scale);
      await fillHousehold(tester, language, l);
      expect(await reveal(tester, find.text(l.summaryReady)), findsOneWidget);
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(await reveal(tester, find.text(l.outcomeSentTitle)), findsWidgets);
      expect(env.server.submissions, hasLength(1));
      await endTest(tester, env);
    });

    matrix('without signal, keeps the form and says it is waiting', (
      tester,
      language,
      scale,
      l,
    ) async {
      final server = FakeObhijatraServer(xform: householdVisitXForm)
        ..submissionGlitch = const NoConnection();
      final env = await openHousehold(tester, language, scale, server: server);
      await fillHousehold(tester, language, l);
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(
        await reveal(tester, find.text(l.outcomeWaitingTitle)),
        findsWidgets,
      );
      expect(server.submissions, isEmpty);
      final queued = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(queued, hasLength(1));
      await endTest(tester, env);
    });

    matrix('when the server refuses, says so and keeps the answers', (
      tester,
      language,
      scale,
      l,
    ) async {
      final server = FakeObhijatraServer(xform: householdVisitXForm)
        ..submissionGlitch = const ErrorStatus(422);
      final env = await openHousehold(tester, language, scale, server: server);
      await fillHousehold(tester, language, l);
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(
        await reveal(tester, find.text(l.outcomeProblemTitle)),
        findsWidgets,
      );
      expect(
        await reveal(tester, find.text(l.outcomeProblemSafe)),
        findsOneWidget,
      );
      final queued = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(queued, hasLength(1));
      await endTest(tester, env);
    });

    matrix('when the phone\'s clock is wrong, says to set the date and time', (
      tester,
      language,
      scale,
      l,
    ) async {
      final server = FakeObhijatraServer(xform: householdVisitXForm)
        ..clockOffset = const Duration(hours: 2);
      final env = await openHousehold(tester, language, scale, server: server);
      await fillHousehold(tester, language, l);
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(
        await reveal(tester, find.text(l.outcomeProblemTitle)),
        findsWidgets,
      );
      expect(
        await reveal(tester, find.text(l.problem_clockSkew)),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.outcomeProblemSafe)),
        findsOneWidget,
      );
      await expectAccessibleTargets(tester);
      // Nothing was sent; the form waits safely in the outbox.
      expect(server.submissions, isEmpty);
      final queued = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(queued!.single.state, OutboxState.queued);
      expect(
        (await currentSyncStatus(tester)).blockedBy,
        ProblemCode.clockSkew,
      );
      await endTest(tester, env);
    });

    matrix('keeping a draft leaves nothing in the outbox', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openHousehold(tester, language, scale);
      await fillHousehold(tester, language, l);
      await tester.tap(await reveal(tester, _button(l.finishKeepDraft)));
      await settleLong(tester);
      final queued = await tester.runAsync(
        () => env.db.select(env.db.outbox).get(),
      );
      expect(queued, isEmpty);
      final drafts = await tester.runAsync(
        () => env.db.select(env.db.drafts).get(),
      );
      expect(drafts, hasLength(1));
      await endTest(tester, env);
    });
  });

  group('Finish: a missing answer', () {
    matrix('lists it, and tapping it jumps to the question', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: lateRelevanceXForm);
      await tester.runAsync(() async {
        await env.seedSignedIn();
        await env.storeForm(lateRelevanceXForm);
      });
      await pumpScreen(
        tester,
        env,
        const FormEntryScreen(
          args: FormEntryArgs(formId: 'late_question', token: 1),
        ),
        language: language,
        textScale: scale,
      );
      // Answer the gate "yes": a required question appears behind us.
      await tester.tap(await reveal(tester, find.text('Yes')));
      await settleApp(tester);
      await _next(tester, l);
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(
        await reveal(tester, find.text(l.validationTitle(1))),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.validationMessage(1))),
        findsOneWidget,
      );
      await expectAccessibleTargets(tester);
      // Tap the listed question: back in the form, on that question.
      await tester.tap(
        await reveal(tester, find.textContaining('How many goats?')),
      );
      await settleApp(tester);
      expect(find.text(l.validationTitle(1)), findsNothing);
      expect(
        await reveal(tester, find.textContaining('How many goats?')),
        findsWidgets,
      );
      await endTest(tester, env);
    });

    matrix('lists every missing answer; each item opens its own question', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: _twoLateXForm);
      await tester.runAsync(() async {
        await env.seedSignedIn();
        await env.storeForm(_twoLateXForm);
      });
      await pumpScreen(
        tester,
        env,
        const FormEntryScreen(
          args: FormEntryArgs(formId: 'two_late', token: 1),
        ),
        language: language,
        textScale: scale,
      );
      // Only the gate applies at first; "yes" adds two questions behind it.
      expect(
        await reveal(tester, find.text(l.questionProgress(1, 1))),
        findsOneWidget,
      );
      await tester.tap(await reveal(tester, find.text('Yes')));
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.questionProgress(3, 3))),
        findsOneWidget,
      );
      await _next(tester, l);
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(
        await reveal(tester, find.text(l.validationTitle(2))),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.validationMessage(2))),
        findsOneWidget,
      );
      final goats = find.text(
        l.validationItem('How many goats?', l.issueRequired),
      );
      final hens = find.text(
        l.validationItem('How many hens?', l.issueRequired),
      );
      expect(await reveal(tester, goats), findsOneWidget);
      expect(await reveal(tester, hens), findsOneWidget);
      await expectAccessibleTargets(tester);

      // The second item opens the second question, not the first.
      await tester.tap(await reveal(tester, hens));
      await settleApp(tester);
      expect(find.text(l.validationTitle(2)), findsNothing);
      expect(
        await reveal(tester, find.textContaining('How many hens?')),
        findsWidgets,
      );
      expect(find.textContaining('How many goats?'), findsNothing);
      expect(
        await reveal(tester, find.text(l.questionProgress(2, 3))),
        findsOneWidget,
      );
      expect(await reveal(tester, find.text(l.issueRequired)), findsOneWidget);

      // Fixed; at the end only the other one is still listed.
      await tester.enterText(
        await reveal(tester, find.byType(EditableText).first),
        language == 'bn' ? '৩' : '3',
      );
      await _next(tester, l); // to the gate question
      await _next(tester, l); // to the end: the finish screen opens
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(
        await reveal(tester, find.text(l.validationTitle(1))),
        findsOneWidget,
      );
      await tester.tap(
        await reveal(
          tester,
          find.text(l.validationItem('How many goats?', l.issueRequired)),
        ),
      );
      await settleApp(tester);
      expect(
        await reveal(tester, find.text(l.questionProgress(1, 3))),
        findsOneWidget,
      );
      await tester.enterText(
        await reveal(tester, find.byType(EditableText).first),
        language == 'bn' ? '২' : '2',
      );
      await _next(tester, l); // hens
      await _next(tester, l); // gate
      await _next(tester, l); // the finish screen
      await tester.tap(await reveal(tester, _button(l.finishSend)));
      await settleLong(tester);
      expect(await reveal(tester, find.text(l.outcomeSentTitle)), findsWidgets);
      expect(env.server.submissions, hasLength(1));
      await endTest(tester, env);
    });
  });
}

/// Two required questions that apply only once the last one is answered
/// "yes", so both are missing when the form reaches its end.
const String _twoLateXForm = '''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms">
  <h:head>
    <h:title>Two late questions</h:title>
    <model odk:xforms-version="1.0.0">
      <instance>
        <data id="two_late" version="1">
          <goats/><hens/><gate/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/goats" type="int" required="true()" relevant="/data/gate = 'yes'"/>
      <bind nodeset="/data/hens" type="int" required="true()" relevant="/data/gate = 'yes'"/>
      <bind nodeset="/data/gate" type="string" required="true()"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/goats"><label>How many goats?</label></input>
    <input ref="/data/hens"><label>How many hens?</label></input>
    <select1 ref="/data/gate"><label>Does the household keep animals?</label>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
  </h:body>
</h:html>''';
