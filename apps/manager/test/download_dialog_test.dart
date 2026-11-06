// Downloading submissions from the Submissions screen, with "Confirm it's
// you" (docs/decisions/0009-data-export.md), in English and Bangla.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/files/download_saver.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/state/url_opener.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/widgets/review_badge.dart';

import 'support/fake_api.dart';
import 'support/fake_saver.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

List<FormSummary> twoForms() => <FormSummary>[
  FormSummary(
    id: 'f1',
    formId: 'household_visit',
    title: 'Household visit',
    versions: <FormVersion>[version('v1', published: true)],
  ),
  FormSummary(
    id: 'f2',
    formId: 'school_check',
    title: 'School check',
    versions: <FormVersion>[version('v9', formRecordId: 'f2', published: true)],
  ),
];

FakeManagerApi exportApi(StaffUser user) =>
    FakeManagerApi(user: user, forms: twoForms())
      ..signInRole = user.role
      ..exportChunks = <List<int>>[
        List<int>.filled(2048, 1),
        List<int>.filled(1024, 2),
      ];

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Starts the app with [saver], opens Submissions with [form] in the
/// filter, and opens the download dialog.
Future<void> openDownload(
  WidgetTester tester,
  FakeManagerApi api,
  FakeDownloadSaver saver, {
  String lang = 'en',
  Size size = const Size(1280, 900),
  String? form = 'f1',
  ReviewState? state,
}) async {
  await pumpManager(
    tester,
    api,
    lang: lang,
    size: size,
    overrides: [
      downloadSaverProvider.overrideWithValue(saver),
      urlOpenerProvider.overrideWithValue((url) async => true),
    ],
  );
  final l10n = l10nOf(tester);
  await tester.tap(find.text(l10n.navSubmissions).first);
  await tester.pumpAndSettle();
  containerOf(tester).read(submissionFilterProvider.notifier)
    ..setForm(form)
    ..setState(state);
  await tester.pumpAndSettle();
  await tapAndSettle(tester, find.byKey(const ValueKey('subs-download')));
  expect(find.byKey(const ValueKey('download-dialog')), findsOneWidget);
}

Future<void> startDownload(WidgetTester tester) =>
    tapAndSettle(tester, find.byKey(const ValueKey('download-start')));

/// Starts a download that stays on its way (the progress bar moves for
/// ever, so the screen never settles).
Future<void> startDownloadAndWait(WidgetTester tester) async {
  final start = find.byKey(const ValueKey('download-start'));
  await tester.ensureVisible(start);
  await tester.pumpAndSettle();
  await tester.tap(start);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

String today() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Download ($lang)', () {
      testWidgets('only org admins and M&E staff see Download', (tester) async {
        for (final role in <String>[
          'org_admin',
          'me',
          'supervisor',
          'branch_manager',
          'donor_readonly',
        ]) {
          await pumpManager(tester, exportApi(staff(role)), lang: lang);
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.navSubmissions).first);
          await tester.pumpAndSettle();
          final allowed = role == 'org_admin' || role == 'me';
          expect(
            find.byKey(const ValueKey('subs-download')),
            allowed ? findsOneWidget : findsNothing,
            reason: role,
          );
          expect(
            find.text(l10n.actionDownload),
            allowed ? findsOneWidget : findsNothing,
          );
        }
      });

      testWidgets('starts from the filter; every state and photos by '
          'default; says the file holds personal data', (tester) async {
        final saver = FakeDownloadSaver();
        await openDownload(tester, exportApi(staff('me')), saver, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.downloadTitle), findsOneWidget);
        expect(find.text('Household visit'), findsWidgets);
        for (final state in ReviewState.values) {
          final chip = tester.widget<FilterChip>(
            find.byKey(ValueKey('download-state-${state.wire}')),
          );
          expect(chip.selected, isTrue, reason: state.name);
        }
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('download-media')),
              )
              .value,
          isTrue,
        );
        expect(find.text(l10n.downloadMediaNote), findsOneWidget);
        expect(find.text(l10n.downloadPersonalData), findsOneWidget);
        // The desktop app saves straight to disk: no memory warning.
        expect(find.text(l10n.downloadBrowserMemory), findsNothing);
        // The filter's last 7 days.
        final now = DateTime.now();
        final firstDay = DateTime(now.year, now.month, now.day - 6);
        final context = tester.element(find.byType(AlertDialog));
        expect(
          find.textContaining(
            Format.day(context, firstDay),
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('download-last-day')),
            matching: find.textContaining(
              l10n.downloadAnyDay,
              findRichText: true,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('downloads the choices, shows progress, then the file '
          'name', (tester) async {
        final api = exportApi(staff('org_admin'))
          ..exportGate = Completer<void>()
          ..exportPause = Completer<void>();
        final saver = FakeDownloadSaver();
        await openDownload(
          tester,
          api,
          saver,
          lang: lang,
          state: ReviewState.approved,
        );
        final l10n = l10nOf(tester);
        // Only the filter's state is chosen; leave photos out.
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('download-media')),
        );
        await startDownloadAndWait(tester);

        expect(saver.suggested, <String>['household_visit_${today()}.zip']);
        expect(find.byKey(const ValueKey('download-working')), findsOneWidget);
        expect(find.text(l10n.downloadPreparing), findsOneWidget);
        api.exportGate!.complete();
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final context = tester.element(find.byType(AlertDialog));
        expect(
          find.text(l10n.downloadReceived(Format.bytes(context, 2048))),
          findsOneWidget,
        );
        api.exportPause!.complete();
        await tester.pumpAndSettle();

        final export = api.exports.single;
        expect(export.formRecordId, 'f1');
        expect(export.reviewStates, <ReviewState>{ReviewState.approved});
        expect(export.includeMedia, isFalse);
        expect(export.lastDay, isNull);
        final target = saver.targets.single;
        expect(target.bytes, hasLength(3072));
        expect(target.finished, isTrue);
        expect(find.byKey(const ValueKey('download-done')), findsOneWidget);
        expect(
          find.text(l10n.downloadSaved('household_visit_${today()}.zip')),
          findsOneWidget,
        );
        expect(find.text(l10n.downloadDoneReminder), findsOneWidget);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('download-close')),
        );
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('asks for a form and at least one review state first', (
        tester,
      ) async {
        final api = exportApi(staff('org_admin'));
        final saver = FakeDownloadSaver();
        await openDownload(tester, api, saver, lang: lang, form: null);
        final l10n = l10nOf(tester);
        for (final state in ReviewState.values) {
          await tapAndSettle(
            tester,
            find.byKey(ValueKey('download-state-${state.wire}')),
          );
        }
        await startDownload(tester);
        expect(find.text(l10n.downloadChooseForm), findsWidgets);
        expect(find.text(l10n.downloadStatesNone), findsOneWidget);
        expect(saver.suggested, isEmpty);
        expect(api.exports, isEmpty);
      });

      testWidgets('an old sign-in: confirm with the password, then the '
          'download goes on by itself into the same file', (tester) async {
        final api = exportApi(staff('org_admin'))
          ..exportFailures.add(
            const AppProblem(ProblemKind.recentSignInRequired, statusCode: 403),
          );
        final saver = FakeDownloadSaver();
        await openDownload(tester, api, saver, lang: lang);
        final l10n = l10nOf(tester);
        await startDownload(tester);

        expect(find.byKey(const ValueKey('download-confirm')), findsOneWidget);
        expect(find.text(l10n.confirmTitle), findsOneWidget);
        expect(find.text(l10n.confirmIntro), findsOneWidget);
        // Nothing typed: asked for.
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('confirm-password-button')),
        );
        expect(find.text(l10n.fieldRequired), findsOneWidget);
        expect(api.signIns, isEmpty);

        await tester.enterText(
          find.byKey(const ValueKey('confirm-password')),
          'correct horse',
        );
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('confirm-password-button')),
        );
        expect(api.signIns, <(String, String)>[
          ('tania@example.org', 'correct horse'),
        ]);
        expect(api.exports, hasLength(2), reason: 'tried once more');
        expect(saver.suggested, hasLength(1), reason: 'the same file');
        expect(saver.targets.single.finished, isTrue);
        expect(find.byKey(const ValueKey('download-done')), findsOneWidget);
        expect(find.text('correct horse'), findsNothing);
      });

      testWidgets('a wrong password says so, and nothing is downloaded', (
        tester,
      ) async {
        final api = exportApi(staff('org_admin'))
          ..exportFailures.add(
            const AppProblem(ProblemKind.recentSignInRequired, statusCode: 403),
          )
          ..signInFailure = const AppProblem(
            ProblemKind.signInFailed,
            statusCode: 400,
          );
        final saver = FakeDownloadSaver();
        await openDownload(tester, api, saver, lang: lang);
        final l10n = l10nOf(tester);
        await startDownload(tester);
        await tester.enterText(
          find.byKey(const ValueKey('confirm-password')),
          'wrong horse',
        );
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('confirm-password-button')),
        );
        expect(find.text(l10n.problemSignInFailed), findsOneWidget);
        expect(api.exports, hasLength(1));
        expect(find.byKey(const ValueKey('download-confirm')), findsOneWidget);

        // Cancel: the file chosen is not left behind.
        await tapAndSettle(
          tester,
          find.widgetWithText(TextButton, l10n.actionCancel).last,
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(saver.targets.single.discarded, isTrue);
      });

      testWidgets('an account with only a phone confirms with an SMS code', (
        tester,
      ) async {
        const smsOnly = StaffUser(
          id: 'u1',
          name: 'Nasrin Sultana',
          email: '',
          phone: '+8801712345678',
          role: 'me',
        );
        final api = exportApi(smsOnly)
          ..methods = const SignInMethods(phone: true)
          ..phoneUser = smsOnly
          ..exportFailures.add(
            const AppProblem(ProblemKind.recentSignInRequired, statusCode: 403),
          );
        final saver = FakeDownloadSaver();
        await openDownload(tester, api, saver, lang: lang);
        final l10n = l10nOf(tester);
        await startDownload(tester);
        expect(find.byKey(const ValueKey('confirm-password')), findsNothing);
        await tapAndSettle(tester, find.byKey(const ValueKey('confirm-sms')));
        expect(api.codeRequests, <String>['+8801712345678']);
        expect(
          find.text(l10n.confirmSmsSent('+8801712345678')),
          findsOneWidget,
        );
        // Bangla digits work.
        await tester.enterText(
          find.byKey(const ValueKey('confirm-code')),
          '১২৩৪৫৬',
        );
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('confirm-code-button')),
        );
        expect(api.codeChecks, <(String, String)>[('code1', '123456')]);
        expect(api.exports, hasLength(2));
        expect(find.byKey(const ValueKey('download-done')), findsOneWidget);
      });

      testWidgets('an admin confirms with Google; SMS is not offered to '
          'admins', (tester) async {
        const admin = StaffUser(
          id: 'u1',
          name: 'Tania Rahman',
          email: 'tania@example.org',
          phone: '+8801700000001',
          role: 'org_admin',
        );
        final api = exportApi(admin)
          ..methods = const SignInMethods(google: true, phone: true)
          ..exportFailures.add(
            const AppProblem(ProblemKind.recentSignInRequired, statusCode: 403),
          );
        final saver = FakeDownloadSaver();
        await openDownload(tester, api, saver, lang: lang);
        final l10n = l10nOf(tester);
        await startDownload(tester);
        expect(find.byKey(const ValueKey('confirm-sms')), findsNothing);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('confirm-google')),
        );
        expect(api.googleWaiting, isTrue);
        expect(find.text(l10n.confirmGoogleWaiting), findsOneWidget);
        api.googleResult.complete(admin);
        await tester.pumpAndSettle();
        expect(api.exports, hasLength(2));
        expect(find.byKey(const ValueKey('download-done')), findsOneWidget);
      });

      testWidgets('problems are plain words with a way on', (tester) async {
        final api = exportApi(staff('org_admin'))
          ..exportFailures.add(const AppProblem(ProblemKind.offline));
        final saver = FakeDownloadSaver();
        await openDownload(tester, api, saver, lang: lang);
        final l10n = l10nOf(tester);
        await startDownload(tester);
        expect(find.byKey(const ValueKey('download-dialog')), findsOneWidget);
        expect(find.text(l10n.problemOffline), findsOneWidget);
        expect(saver.targets.single.discarded, isTrue);

        // A file that cannot be written.
        saver.failWrites = true;
        final dialog = find.byKey(const ValueKey('download-dialog'));
        await tapAndSettle(
          tester,
          find.descendant(of: dialog, matching: find.text(l10n.actionTryAgain)),
        );
        expect(find.text(l10n.problemSaveFailed), findsOneWidget);
        expect(saver.targets.last.discarded, isTrue);

        saver.failWrites = false;
        await tapAndSettle(
          tester,
          find.descendant(of: dialog, matching: find.text(l10n.actionTryAgain)),
        );
        expect(find.byKey(const ValueKey('download-done')), findsOneWidget);
      });

      testWidgets('"Stop" ends it, and a cancelled Save dialog downloads '
          'nothing', (tester) async {
        final api = exportApi(staff('org_admin'))
          ..exportGate = Completer<void>();
        final saver = FakeDownloadSaver()..cancelNext = true;
        await openDownload(tester, api, saver, lang: lang);
        await startDownload(tester);
        expect(api.exports, isEmpty);
        expect(find.byKey(const ValueKey('download-dialog')), findsOneWidget);

        await startDownloadAndWait(tester);
        expect(find.byKey(const ValueKey('download-working')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('download-stop')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('download-dialog')), findsOneWidget);
        expect(saver.targets.single.discarded, isTrue);
        expect(find.byKey(const ValueKey('download-done')), findsNothing);
      });

      testWidgets('in a browser: warns that the file is held in memory, and '
          'names the file as the server does', (tester) async {
        final api = exportApi(staff('org_admin'));
        final saver = FakeDownloadSaver(holdsInMemory: true);
        await openDownload(tester, api, saver, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.downloadBrowserMemory), findsOneWidget);
        await startDownload(tester);
        expect(
          find.text(
            l10n.downloadSavedBrowser('household_survey_2026-11-06.zip'),
          ),
          findsOneWidget,
        );
      });

      for (final size in <Size>[const Size(1280, 900), const Size(600, 900)]) {
        testWidgets('large text fits every step at ${size.width.toInt()} '
            'wide', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final api = exportApi(staff('org_admin'))
            ..exportFailures.add(
              const AppProblem(
                ProblemKind.recentSignInRequired,
                statusCode: 403,
              ),
            );
          final saver = FakeDownloadSaver();
          await openDownload(tester, api, saver, lang: lang, size: size);
          expect(tester.takeException(), isNull);
          final start = find.byKey(const ValueKey('download-start'));
          await tester.ensureVisible(start);
          expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
          await startDownload(tester);
          expect(tester.takeException(), isNull);
          await tester.enterText(
            find.byKey(const ValueKey('confirm-password')),
            'correct horse',
          );
          final confirm = find.byKey(const ValueKey('confirm-password-button'));
          await tester.ensureVisible(confirm);
          expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
          await tapAndSettle(tester, confirm);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('download-done')), findsOneWidget);
        });
      }
    });
  }

  testWidgets('choosing days with the calendar', (tester) async {
    final api = exportApi(staff('org_admin'));
    final saver = FakeDownloadSaver();
    await openDownload(tester, api, saver);
    final l10n = l10nOf(tester);
    // Clear the filter's first day, then choose the 1st of this month.
    await tapAndSettle(tester, find.byTooltip(l10n.downloadClearDay));
    expect(find.byTooltip(l10n.downloadClearDay), findsNothing);
    await tapAndSettle(
      tester,
      find.byKey(const ValueKey('download-first-day')),
    );
    await tapAndSettle(tester, find.text('1').last);
    await tapAndSettle(tester, find.text('OK'));
    await startDownload(tester);
    final now = DateTime.now();
    expect(api.exports.single.firstDay, DateTime(now.year, now.month));
    expect(api.exports.single.from, DateTime(now.year, now.month));
    // Review state words come from the badges' own.
    expect(reviewStateWord(l10n, ReviewState.approved), isNotEmpty);
  });
}
