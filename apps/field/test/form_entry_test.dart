import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/screens/form_entry_screen.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

import 'support/harness.dart';

/// The household form's words in each language.
class _Words {
  const _Words(
    this.date,
    this.outcome,
    this.met,
    this.head,
    this.size,
    this.sizeMessage,
  );
  final String date;
  final String outcome;
  final String met;
  final String head;
  final String size;
  final String sizeMessage;
}

const _en = _Words(
  'Date of visit',
  'What happened at the visit?',
  'Met the household',
  'Name of the household head',
  'How many people live in the household?',
  'Enter a number from 1 to 30.',
);
const _bn = _Words(
  'পরিদর্শনের তারিখ',
  'পরিদর্শনে কী হলো?',
  'খানার সাথে দেখা হয়েছে',
  'খানা প্রধানের নাম',
  'খানায় কতজন থাকেন?',
  '১ থেকে ৩০ এর মধ্যে একটি সংখ্যা লিখুন।',
);

_Words _wordsOf(String language) => language == 'bn' ? _bn : _en;

Future<TestEnv> openForm(
  WidgetTester tester,
  String language,
  double scale, {
  String xform = '',
  String formId = 'household_visit',
}) async {
  final form = xform.isEmpty ? householdVisitXForm : xform;
  final env = TestEnv(xform: form);
  await tester.runAsync(() async {
    await env.seedSignedIn();
    await env.storeForm(form);
  });
  await pumpScreen(
    tester,
    env,
    FormEntryScreen(args: FormEntryArgs(formId: formId, token: 1)),
    language: language,
    textScale: scale,
  );
  return env;
}

Future<void> next(
  WidgetTester tester,
  AppLocalizations l, {
  bool finish = false,
}) async {
  final label = finish ? l.entryFinish : l.entryNext;
  await tester.tap(find.widgetWithText(PrimaryButton, label));
  await settleApp(tester);
}

/// Picks today's date in the date picker (its first suggestion).
Future<void> pickToday(WidgetTester tester, AppLocalizations l) async {
  await tester.tap(await reveal(tester, find.text(l.pickDate)));
  await settleApp(tester);
  final ok = MaterialLocalizations.of(
    tester.element(find.byType(DatePickerDialog)),
  ).okButtonLabel;
  await tester.tap(find.text(ok));
  await settleApp(tester);
}

Finder get _field => find.byType(EditableText);

/// The "question N of T" line for [n], whatever the total estimate is.
Finder progress(AppLocalizations l, int n) {
  final options = <String>{
    for (var t = n; t <= 30; t++) l.questionProgress(n, t),
  };
  return find.byWidgetPredicate((w) => w is Text && options.contains(w.data));
}

void main() {
  group('Form entry: household visit', () {
    matrix('shows one question at a time with progress and a Next button', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(tester, language, scale);
      final w = _wordsOf(language);
      expect(await reveal(tester, find.textContaining(w.date)), findsWidgets);
      expect(await reveal(tester, progress(l, 1)), findsOneWidget);
      // The second question is not on screen yet.
      expect(find.textContaining(w.outcome), findsNothing);
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });

    matrix('will not move on from a required question and says why', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(tester, language, scale);
      await next(tester, l);
      expect(await reveal(tester, find.text(l.issueRequired)), findsOneWidget);
      expect(await reveal(tester, progress(l, 1)), findsOneWidget);
      await endTest(tester, env);
    });

    matrix('answers a date, a choice, then shows the skip-rule question', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(tester, language, scale);
      final w = _wordsOf(language);
      await pickToday(tester, l);
      await next(tester, l);
      expect(
        await reveal(tester, find.textContaining(w.outcome)),
        findsWidgets,
      );
      await tester.tap(await reveal(tester, find.text(w.met)));
      await settleApp(tester);
      await next(tester, l);
      // "Met the household" leads to the household head, not "why not met".
      expect(await reveal(tester, find.textContaining(w.head)), findsWidgets);
      await endTest(tester, env);
    });

    matrix('shows the form\'s own message when a number is not allowed', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(tester, language, scale);
      final w = _wordsOf(language);
      await pickToday(tester, l);
      await next(tester, l);
      await tester.tap(await reveal(tester, find.text(w.met)));
      await settleApp(tester);
      await next(tester, l);
      await tester.enterText(await reveal(tester, _field.first), 'Karim');
      await next(tester, l);
      expect(await reveal(tester, find.textContaining(w.size)), findsWidgets);
      // Bangla digits are accepted as typed.
      await tester.enterText(
        await reveal(tester, _field.first),
        language == 'bn' ? '৯৯' : '99',
      );
      await next(tester, l);
      expect(await reveal(tester, find.text(w.sizeMessage)), findsOneWidget);
      await tester.enterText(
        await reveal(tester, _field.first),
        language == 'bn' ? '৪' : '4',
      );
      await next(tester, l);
      expect(find.text(w.sizeMessage), findsNothing);
      await endTest(tester, env);
    });

    matrix('Back returns to the earlier answer, kept', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(tester, language, scale);
      final w = _wordsOf(language);
      await pickToday(tester, l);
      await next(tester, l);
      await tester.tap(await reveal(tester, find.text(w.met)));
      await settleApp(tester);
      await tester.tap(find.widgetWithText(PrimaryButton, l.entryBack));
      await settleApp(tester);
      expect(await reveal(tester, find.textContaining(w.date)), findsWidgets);
      expect(await reveal(tester, progress(l, 1)), findsOneWidget);
      await endTest(tester, env);
    });

    matrix('saves a draft by itself and says so', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(tester, language, scale);
      final w = _wordsOf(language);
      await pickToday(tester, l);
      await next(tester, l);
      await tester.tap(await reveal(tester, find.text(w.met)));
      await tester.pump(const Duration(seconds: 2));
      await settleApp(tester);
      expect(await reveal(tester, find.text(l.savedBadge)), findsWidgets);
      final drafts = await tester.runAsync(
        () => env.db.select(env.db.drafts).get(),
      );
      expect(drafts, hasLength(1));
      await endTest(tester, env);
    });
  });

  group('Form entry: leaving', () {
    matrix('closing the form keeps the draft', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(() async {
        await env.seedSignedIn();
        await env.storeForm(householdVisitXForm);
      });
      await pumpScreen(
        tester,
        env,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const FormEntryScreen(
                      args: FormEntryArgs(formId: 'household_visit', token: 7),
                    ),
                  ),
                ),
                child: const Text('open the form'),
              ),
            ),
          ),
        ),
        language: language,
        textScale: scale,
      );
      await tester.tap(find.text('open the form'));
      await settleApp(tester);
      await pickToday(tester, l);
      await next(tester, l);
      await tester.tap(find.byTooltip(l.closeForm));
      await settleApp(tester);
      expect(find.text('open the form'), findsOneWidget);
      final drafts = await tester.runAsync(
        () => env.db.select(env.db.drafts).get(),
      );
      expect(drafts, hasLength(1));
      await endTest(tester, env);
    });

    matrix('a form that is not on the phone says so plainly', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(
        tester,
        language,
        scale,
        formId: 'no_such_form',
      );
      expect(await reveal(tester, find.text(l.formNotOnPhone)), findsOneWidget);
      await endTest(tester, env);
    });
  });

  group('Form entry: every question kind', () {
    matrix('shows each kind, and a card for those not supported yet', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openForm(
        tester,
        language,
        scale,
        xform: kitchenSinkXForm,
        formId: 'kitchen_sink',
      );
      // Note.
      expect(
        await reveal(tester, find.textContaining('Welcome to the visit.')),
        findsWidgets,
      );
      await next(tester, l);
      // Select one (required).
      expect(
        await reveal(
          tester,
          find.textContaining('Where does the drinking water come from?'),
        ),
        findsWidgets,
      );
      await next(tester, l);
      expect(await reveal(tester, find.text(l.issueRequired)), findsOneWidget);
      await tester.tap(await reveal(tester, find.text('Tube well')));
      await settleApp(tester);
      await next(tester, l);
      // Select many.
      expect(
        await reveal(
          tester,
          find.textContaining('Which tools does the household own?'),
        ),
        findsWidgets,
      );
      await tester.tap(await reveal(tester, find.text('Plough')));
      await tester.tap(await reveal(tester, find.text('Pump')));
      await settleApp(tester);
      await next(tester, l);
      // Integer, decimal.
      expect(
        await reveal(tester, find.textContaining('Age of the oldest person')),
        findsWidgets,
      );
      await tester.enterText(await reveal(tester, _field.first), '7');
      await next(tester, l);
      expect(
        await reveal(tester, find.textContaining('Weight in kilograms')),
        findsWidgets,
      );
      await tester.enterText(await reveal(tester, _field.first), '12.5');
      await next(tester, l);
      // Date.
      expect(
        await reveal(tester, find.textContaining('Date of visit')),
        findsWidgets,
      );
      await next(tester, l);
      // Time is not supported yet: a card, and the form can still go on.
      expect(
        await reveal(tester, find.text(l.unsupportedTitle)),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.unsupportedBody)),
        findsOneWidget,
      );
      await expectAccessibleTargets(tester);
      await next(tester, l);
      // Text.
      expect(
        await reveal(tester, find.textContaining('Name of the household head')),
        findsWidgets,
      );
      await next(tester, l);
      // A required photo cannot be taken yet, and the card says so.
      expect(
        await reveal(tester, find.text(l.unsupportedTitle)),
        findsOneWidget,
      );
      expect(
        await reveal(tester, find.text(l.unsupportedRequiredBody)),
        findsOneWidget,
      );
      await endTest(tester, env);
    });
  });
}
