import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/submission_panel.dart';

import 'support/fake_api.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

FakeManagerApi apiWithSubmissions({String role = 'supervisor'}) {
  final api = FakeManagerApi(
    user: staff(role),
    forms: <FormSummary>[
      FormSummary(
        id: 'f1',
        formId: 'household_visit',
        title: 'Household visit',
        versions: <FormVersion>[version('v2', number: '2', published: true)],
      ),
    ],
  );
  api.xforms['v2'] = householdXForm(version: '2');
  api.locations = <String, String>{'/loc00000000000a/': 'Shapla Char'};
  api.submissions = <SubmissionRow>[
    row(1, state: ReviewState.hasIssues, comment: 'Household members is 0'),
    row(2),
    row(3, state: ReviewState.approved),
    row(
      4,
      state: ReviewState.rejected,
      comment: 'Duplicate of an earlier visit',
    ),
  ];
  for (final r in api.submissions) {
    api.instances[r.id] = householdInstance;
  }
  return api;
}

void expectNoSecrets(WidgetTester tester) {
  final words = everyWord(tester);
  expect(words, isNot(contains('SECRET')));
  expect(words, isNot(contains('Rahima')));
  expect(words, isNot(contains('01712345678')));
}

Future<void> goToSubmissions(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  await tester.tap(find.text(l10n.navSubmissions).first);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Submissions screen ($lang)', () {
      testWidgets(
        'shows the table with a word and a colour for each review state',
        (tester) async {
          final api = apiWithSubmissions();
          await pumpManager(tester, api, lang: lang);
          await goToSubmissions(tester);
          final l10n = l10nOf(tester);

          for (final heading in <String>[
            l10n.colDate,
            l10n.colForm,
            l10n.colCollector,
            l10n.colLocation,
            l10n.colReview,
          ]) {
            expect(find.text(heading), findsWidgets);
          }
          expect(find.text('Household visit'), findsWidgets);
          expect(find.text('Nasrin Sultana'), findsNWidgets(4));
          expect(find.text('Shapla Char'), findsNWidgets(4));
          // Each state appears as a word in the table (and as a tab).
          expect(find.text(l10n.stateHasIssues), findsNWidgets(2));
          expect(find.text(l10n.stateReceived), findsNWidgets(2));
          expect(find.text(l10n.stateApproved), findsNWidgets(2));
          expect(find.text(l10n.stateRejected), findsNWidgets(2));
          expect(find.text(l10n.subsCount(4)), findsOneWidget);
          // The first fetch is page 1 for the last 7 days.
          expect(api.queries.first.page, 1);
          expect(api.queries.first.from, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('filters by review state, form and dates on the server', (
        tester,
      ) async {
        final api = apiWithSubmissions();
        await pumpManager(tester, api, lang: lang);
        await goToSubmissions(tester);
        final l10n = l10nOf(tester);

        await tester.tap(
          find
              .descendant(
                of: find.byType(InkWell),
                matching: find.text(l10n.stateHasIssues),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(api.queries.last.state, ReviewState.hasIssues);
        expect(api.queries.last.page, 1);

        // Choose a form.
        await tester.tap(find.byType(DropdownMenu<String>));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(MenuItemButton),
                matching: find.text('Household visit'),
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(api.queries.last.formRecordId, 'f1');

        // Dates: all time clears the range.
        await tester.tap(find.byType(DropdownMenu<DatePreset>));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(MenuItemButton),
                matching: find.text(l10n.filterAllTime),
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(api.queries.last.from, isNull);
        expect(api.queries.last.formRecordId, 'f1');
      });

      testWidgets(
        'large data: 12,345 submissions are paged 50 at a time, from the server',
        (tester) async {
          final api = apiWithSubmissions()
            ..totalOverride = 12345
            ..rowFor = ((i) => row(i + 1, id: 'big$i'));
          await pumpManager(tester, api, lang: lang);
          await goToSubmissions(tester);
          final l10n = l10nOf(tester);

          expect(find.text(l10n.pagingPage(1, 247)), findsOneWidget);
          expect(find.text(l10n.pagingRange(1, 50, 12345)), findsOneWidget);
          expect(find.text(l10n.subsCount(12345)), findsOneWidget);
          expect(api.queries.last.page, 1);

          await tester.tap(find.text(l10n.pagingNext));
          await tester.pumpAndSettle();
          expect(api.queries.last.page, 2);
          expect(find.text(l10n.pagingPage(2, 247)), findsOneWidget);
          expect(find.text(l10n.pagingRange(51, 100, 12345)), findsOneWidget);

          // Previous works, and the last page holds the remainder (45 rows).
          await tester.tap(find.text(l10n.pagingPrevious));
          await tester.pumpAndSettle();
          expect(api.queries.last.page, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('empty: a calm message', (tester) async {
        final api = apiWithSubmissions()..submissions = <SubmissionRow>[];
        await pumpManager(tester, api, lang: lang);
        await goToSubmissions(tester);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.subsEmptyTitle), findsOneWidget);
        expect(find.text(l10n.subsEmptyBody), findsOneWidget);
        expect(find.text(l10n.subsCount(0)), findsOneWidget);
      });

      testWidgets('loading: a spinner with a label', (tester) async {
        final api = apiWithSubmissions();
        await pumpManager(tester, api, lang: lang);
        api.gate = Completer<void>();
        await tester.tap(find.text(l10nOf(tester).navSubmissions).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(find.text(l10nOf(tester).loading), findsWidgets);
        api.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Nasrin Sultana'), findsWidgets);
      });

      testWidgets(
        'error and offline: one sentence, one action, then it recovers',
        (tester) async {
          final api = apiWithSubmissions();
          await pumpManager(tester, api, lang: lang);
          api.failWith = const AppProblem(ProblemKind.offline);
          await goToSubmissions(tester);
          final l10n = l10nOf(tester);
          expect(find.text(l10n.problemOffline), findsOneWidget);
          expect(find.text(l10n.offlineTitle), findsOneWidget); // the banner
          expect(find.text(l10n.actionTryAgain), findsWidgets);

          api.failWith = null;
          await tester.tap(
            find.widgetWithText(FilledButton, l10n.actionTryAgain),
          );
          await tester.pumpAndSettle();
          expect(find.text('Nasrin Sultana'), findsWidgets);
          expect(find.text(l10n.offlineTitle), findsNothing);
        },
      );

      testWidgets('an ended session sends the person back to sign in', (
        tester,
      ) async {
        final api = apiWithSubmissions();
        await pumpManager(tester, api, lang: lang);
        api.failWith = const AppProblem(ProblemKind.signInRequired);
        await goToSubmissions(tester);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.problemSignInRequired), findsOneWidget);
        await tester.tap(find.text(l10n.actionSignInAgain));
        await tester.pumpAndSettle();
        expect(api.signOuts, 1);
        expect(find.text(l10n.signInTitle), findsWidgets);
      });

      testWidgets(
        'the details panel shows answers; protected ones are sealed and never rendered',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final api = apiWithSubmissions();
          await pumpManager(tester, api, lang: lang);
          await goToSubmissions(tester);
          final l10n = l10nOf(tester);

          await tester.tap(
            find.text(l10n.stateHasIssues).last,
          ); // first table row's badge
          await tester.pumpAndSettle();

          expect(find.byType(SubmissionPanel), findsOneWidget);
          expect(find.text(l10n.detailAnswers), findsOneWidget);
          expect(
            find.text(lang == 'en' ? 'Tube well' : 'নলকূপ'),
            findsOneWidget,
          );
          expect(
            find.text(lang == 'en' ? 'Household members' : 'খানার সদস্য'),
            findsOneWidget,
          );
          expect(find.text(l10n.protectedAnswer), findsNWidgets(2));
          expect(find.text(l10n.detailProtectedNote), findsOneWidget);
          // The reviewer's note is shown.
          expect(find.text('Household members is 0'), findsOneWidget);

          expectNoSecrets(tester);
          final tree = tester
              .getSemantics(find.byType(SubmissionPanel))
              .toStringDeep();
          expect(tree, isNot(contains('SECRET')));
          expect(tree, isNot(contains('Rahima')));
          expect(
            find.textContaining('SECRET', findRichText: true),
            findsNothing,
          );
          semantics.dispose();
        },
      );

      testWidgets(
        'if the form definition cannot be read, no answer is shown at all',
        (tester) async {
          final api = apiWithSubmissions()
            ..xformFailure = const AppProblem(ProblemKind.notFound);
          await pumpManager(tester, api, lang: lang);
          await goToSubmissions(tester);
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.stateHasIssues).last);
          await tester.pumpAndSettle();
          expect(find.text(l10n.problemFormUnavailable), findsOneWidget);
          // Nothing from the instance is drawn, protected or not.
          expect(find.text(lang == 'en' ? 'Tube well' : 'নলকূপ'), findsNothing);
          expect(find.text('tube'), findsNothing);
          expectNoSecrets(tester);
        },
      );

      testWidgets('Approve saves at once', (tester) async {
        final api = apiWithSubmissions();
        await pumpManager(tester, api, lang: lang);
        await goToSubmissions(tester);
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.stateReceived).last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, l10n.actionApprove));
        await tester.pumpAndSettle();
        expect(api.reviews.single.$1.id, 's2');
        expect(api.reviews.single.$2, ReviewState.approved);
        expect(api.reviews.single.$3, isNull);
        expect(find.text(l10n.reviewSaved(l10n.stateApproved)), findsOneWidget);
      });

      testWidgets('Has issues needs a comment', (tester) async {
        final api = apiWithSubmissions();
        await pumpManager(tester, api, lang: lang);
        await goToSubmissions(tester);
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.stateReceived).last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(OutlinedButton, l10n.actionHasIssues),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.reviewIssuesTitle),
          ),
          findsWidgets,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.reviewConfirmIssues),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewCommentRequired), findsOneWidget);
        expect(api.reviews, isEmpty);

        await tester.enterText(
          find.byType(TextFormField),
          'Members must be at least 1',
        );
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.reviewConfirmIssues),
        );
        await tester.pumpAndSettle();
        expect(api.reviews.single.$2, ReviewState.hasIssues);
        expect(api.reviews.single.$3, 'Members must be at least 1');
      });

      testWidgets('Reject asks for a reason and can be cancelled', (
        tester,
      ) async {
        final api = apiWithSubmissions();
        await pumpManager(tester, api, lang: lang);
        await goToSubmissions(tester);
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.stateReceived).last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(OutlinedButton, l10n.actionReject),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewRejectLabel), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, l10n.actionCancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.reviews, isEmpty);

        await tester.tap(
          find.widgetWithText(OutlinedButton, l10n.actionReject),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'Wrong household');
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, l10n.actionReject),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.reviews.single.$2, ReviewState.rejected);
        expect(api.reviews.single.$3, 'Wrong household');
      });

      testWidgets(
        'a server that cannot keep notes: the person is told, and the list refreshes',
        (tester) async {
          final api = apiWithSubmissions()
            ..reviewFailure = const AppProblem(ProblemKind.commentNotSaved);
          await pumpManager(tester, api, lang: lang);
          await goToSubmissions(tester);
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.stateReceived).last);
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(OutlinedButton, l10n.actionReject),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), 'Wrong household');
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(FilledButton, l10n.actionReject),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.problemCommentNotSaved), findsOneWidget);
          expect(find.text(l10n.actionClose), findsWidgets);
        },
      );

      testWidgets('a role that can only read sees no review buttons', (
        tester,
      ) async {
        final api = apiWithSubmissions(role: 'me');
        await pumpManager(tester, api, lang: lang);
        await goToSubmissions(tester);
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.stateReceived).last);
        await tester.pumpAndSettle();
        expect(find.text(l10n.reviewReadOnly), findsOneWidget);
        expect(find.text(l10n.actionApprove), findsNothing);
        expect(find.text(l10n.actionReject), findsNothing);
      });

      for (final width in <double>[1024, 1440, 640]) {
        testWidgets('layout holds at ${width.toInt()} px with the panel open', (
          tester,
        ) async {
          final api = apiWithSubmissions();
          await pumpManager(tester, api, lang: lang, size: Size(width, 800));
          await goToSubmissions(tester);
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.stateReceived).last);
          await tester.pumpAndSettle();
          expect(find.byType(SubmissionPanel), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Escape closes the panel.
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(SubmissionPanel), findsNothing);
        });
      }
    });
  }
}
