import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/file_picker.dart';
import 'package:obhijatra_manager/src/ui/forms_screen.dart';
import 'package:obhijatra_manager/src/ui/upload_form_dialog.dart';

import 'support/fake_api.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

const _kobo = ' xmlns:kobo="http://kobotoolbox.org/xforms"';
const _matrix =
    '<group ref="/data/water_sources" kobo--matrix_list="w"><label>x</label></group>';

FakeManagerApi apiWithForms({
  String role = 'org_admin',
  bool draftHasMatrix = true,
}) {
  final api = FakeManagerApi(
    user: staff(role),
    forms: <FormSummary>[
      FormSummary(
        id: 'f1',
        formId: 'household_visit',
        title: 'Household visit',
        versions: <FormVersion>[
          version('v3', number: '3'),
          version('v2', number: '2', published: true),
          version('v1', number: '1', published: true),
        ],
      ),
      FormSummary(
        id: 'f2',
        formId: 'monthly',
        title: 'Monthly follow-up',
        versions: <FormVersion>[
          version('m5', number: '5', published: true, formRecordId: 'f2'),
        ],
      ),
    ],
  );
  api.xforms['v3'] = draftHasMatrix
      ? householdXForm(version: '3', extraNamespaces: _kobo, extraBody: _matrix)
      : householdXForm(version: '3');
  api.xforms['v2'] = householdXForm(version: '2');
  api.xforms['v1'] = householdXForm(version: '1');
  api.xforms['m5'] = householdXForm(version: '5', formId: 'monthly');
  return api;
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Forms screen ($lang)', () {
      testWidgets('lists forms with their versions and explains each problem', (
        tester,
      ) async {
        await pumpManager(tester, apiWithForms(), lang: lang);
        final l10n = l10nOf(tester);

        expect(find.text(l10n.formsYourForms), findsOneWidget);
        expect(find.text(l10n.formsUploadTitle), findsOneWidget);
        expect(find.text('Monthly follow-up'), findsOneWidget);
        expect(find.text(l10n.versionLabel('3')), findsOneWidget);
        expect(find.text(l10n.versionLabel('2')), findsOneWidget);
        expect(find.text(l10n.badgePublished), findsWidgets);
        // The newest version is a draft with a Kobo matrix: it needs a fix.
        expect(find.text(l10n.badgeNeedsFix), findsWidgets);
        expect(find.text(l10n.publishCheckTitle), findsOneWidget);
        expect(find.text(l10n.checkKindFix), findsOneWidget);
        expect(find.text(l10n.checkKoboMatrix), findsOneWidget);
        expect(find.text(l10n.checkWhere(1, 'water_sources')), findsOneWidget);
        expect(find.text(l10n.checkKindProtected), findsOneWidget);
        expect(
          find.textContaining(
            lang == 'en' ? 'Household head’s name' : 'খানা প্রধানের নাম',
          ),
          findsWidgets,
        );
        expect(
          find.text(l10n.publishFixCount(1)),
          findsNothing,
        ); // joined into one sentence
        expect(find.textContaining(l10n.publishFixCount(1)), findsOneWidget);

        final publish = find.ancestor(
          of: find.text(l10n.publishButton),
          matching: find.bySubtype<FilledButton>(),
        );
        expect(tester.widget<FilledButton>(publish).onPressed, isNull);
        expect(find.text(l10n.publishHint), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a clean draft can be published after a confirmation', (
        tester,
      ) async {
        final api = apiWithForms(draftHasMatrix: false);
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);

        expect(find.text(l10n.publishAllClear), findsNothing);
        expect(find.textContaining(l10n.publishAllClear), findsOneWidget);
        final publish = find.ancestor(
          of: find.text(l10n.publishButton),
          matching: find.bySubtype<FilledButton>(),
        );
        expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);

        await tester.tap(publish);
        await tester.pumpAndSettle();
        expect(find.text(l10n.publishConfirmTitle('3')), findsOneWidget);
        expect(find.text(l10n.publishConfirmBody), findsOneWidget);
        // Not yet: nothing is sent.
        await tester.tap(find.text(l10n.publishConfirmNo));
        await tester.pumpAndSettle();
        expect(api.published, isEmpty);

        await tester.tap(publish);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.publishButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.published.single.id, 'v3');
        expect(find.text(l10n.publishDone('3')), findsOneWidget);
      });

      testWidgets('a published version is read-only', (tester) async {
        await pumpManager(tester, apiWithForms(), lang: lang);
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.versionLabel('2')));
        await tester.pumpAndSettle();
        expect(find.text(l10n.formCheckTitle), findsOneWidget);
        expect(find.text(l10n.publishedReadOnly), findsOneWidget);
        expect(find.text(l10n.publishButton), findsNothing);
      });

      testWidgets('staff who are not admins cannot upload or publish', (
        tester,
      ) async {
        await pumpManager(
          tester,
          apiWithForms(role: 'supervisor', draftHasMatrix: false),
          lang: lang,
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.formsUploadTitle), findsNothing);
        expect(find.text(l10n.adminOnlyForms), findsWidgets);
        final publish = find.ancestor(
          of: find.text(l10n.publishButton),
          matching: find.bySubtype<FilledButton>(),
        );
        expect(tester.widget<FilledButton>(publish).onPressed, isNull);
      });

      testWidgets('empty: no forms yet', (tester) async {
        await pumpManager(
          tester,
          FakeManagerApi(user: staff('org_admin')),
          lang: lang,
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.formsEmptyTitle), findsWidgets);
        expect(find.text(l10n.formsEmptyBodyAdmin), findsOneWidget);
      });

      testWidgets('loading: shows a spinner with a spoken label', (
        tester,
      ) async {
        final api = apiWithForms()..gate = Completer<void>();
        await pumpManager(tester, api, lang: lang, settle: false);
        final l10n = l10nOf(tester);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(find.text(l10n.loading), findsWidgets);
        api.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text(l10n.formsYourForms), findsOneWidget);
      });

      testWidgets('error: one plain sentence and one action that works', (
        tester,
      ) async {
        final api = apiWithForms()
          ..failWith = const AppProblem(ProblemKind.serverError);
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.problemServerError), findsOneWidget);
        expect(find.text(l10n.actionTryAgain), findsWidgets);
        expect(find.textContaining('500'), findsNothing);

        api.failWith = null;
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.actionTryAgain).first,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.formsYourForms), findsOneWidget);
      });

      testWidgets('large data: a long list of forms scrolls without trouble', (
        tester,
      ) async {
        final api = FakeManagerApi(
          user: staff('org_admin'),
          forms: <FormSummary>[
            for (var i = 0; i < 150; i++)
              FormSummary(
                id: 'f$i',
                formId: 'form_$i',
                title: 'Household visit number $i',
                versions: <FormVersion>[
                  version(
                    'v$i',
                    number: '$i',
                    published: true,
                    formRecordId: 'f$i',
                  ),
                ],
              ),
          ],
        );
        api.xforms['v0'] = householdXForm(version: '0');
        await pumpManager(tester, api, lang: lang, size: const Size(1024, 700));
        await tester.scrollUntilVisible(
          find.text('Household visit number 149'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('narrow window: the two columns stack', (tester) async {
        await pumpManager(
          tester,
          apiWithForms(),
          lang: lang,
          size: const Size(700, 900),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(VersionPanel), findsOneWidget);
      });
    });

    group('Upload dialog ($lang)', () {
      Future<FakePicker> open(WidgetTester tester, FakeManagerApi api) async {
        final picker = FakePicker();
        await pumpManager(tester, api, lang: lang, picker: picker);
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.formsChooseFile));
        await tester.pumpAndSettle();
        return picker;
      }

      testWidgets('says plainly that spreadsheets arrive in Phase 2', (
        tester,
      ) async {
        final picker = await open(tester, apiWithForms());
        final l10n = l10nOf(tester);
        expect(find.textContaining('Phase 2'), findsOneWidget);
        expect(find.text(l10n.uploadChoosePrompt), findsOneWidget);

        picker.next = pickedText('household.xlsx', 'binary');
        await tester.tap(find.text(l10n.formsChooseFile).last);
        await tester.pumpAndSettle();
        expect(find.text(l10n.uploadXlsNotice), findsOneWidget);
        final upload = find.ancestor(
          of: find.text(l10n.uploadButton),
          matching: find.bySubtype<FilledButton>(),
        );
        expect(tester.widget<FilledButton>(upload).onPressed, isNull);
      });

      testWidgets('a form with a Kobo matrix cannot be uploaded', (
        tester,
      ) async {
        final picker = await open(tester, apiWithForms());
        final l10n = l10nOf(tester);
        picker.next = pickedText(
          'bad.xml',
          householdXForm(
            version: '9',
            extraNamespaces: _kobo,
            extraBody: _matrix,
          ),
        );
        await tester.tap(find.text(l10n.formsChooseFile).last);
        await tester.pumpAndSettle();
        expect(find.text(l10n.uploadBlocked), findsOneWidget);
        expect(find.text(l10n.checkKoboMatrix), findsWidgets);
        final upload = find.ancestor(
          of: find.text(l10n.uploadButton),
          matching: find.bySubtype<FilledButton>(),
        );
        expect(tester.widget<FilledButton>(upload).onPressed, isNull);
      });

      testWidgets(
        'a version that was already uploaded is caught before sending',
        (tester) async {
          final picker = await open(tester, apiWithForms());
          final l10n = l10nOf(tester);
          picker.next = pickedText('dup.xml', householdXForm(version: '2'));
          await tester.tap(find.text(l10n.formsChooseFile).last);
          await tester.pumpAndSettle();
          expect(find.text(l10n.checkVersionExists('2')), findsOneWidget);
        },
      );

      testWidgets('a good file is saved as a draft', (tester) async {
        final api = apiWithForms();
        final picker = await open(tester, api);
        final l10n = l10nOf(tester);
        picker.next = pickedText('ok.xml', householdXForm(version: '9'));
        await tester.tap(find.text(l10n.formsChooseFile).last);
        await tester.pumpAndSettle();
        expect(find.text(l10n.uploadReady), findsOneWidget);
        await tester.tap(find.text(l10n.uploadButton));
        await tester.pumpAndSettle();
        expect(api.uploads.single.formId, 'household_visit');
        expect(api.uploads.single.version, '9');
        expect(api.uploads.single.title, 'Household visit');
        expect(find.text(l10n.uploadDone), findsOneWidget);
        expect(find.byType(UploadFormDialog), findsNothing);
      });

      testWidgets(
        'a file over 10 MB and a file that is not text get plain sentences',
        (tester) async {
          final picker = await open(tester, apiWithForms());
          final l10n = l10nOf(tester);
          picker.next = PickedFile(
            name: 'huge.xml',
            bytes: Uint8List(maxFormBytes + 1),
          );
          await tester.tap(find.text(l10n.formsChooseFile).last);
          await tester.pumpAndSettle();
          expect(find.text(l10n.problemTooLarge), findsOneWidget);

          picker.next = PickedFile(
            name: 'junk.xml',
            bytes: Uint8List.fromList(<int>[0xff, 0xfe, 0xfd]),
          );
          await tester.tap(find.text(l10n.actionChooseFile).last);
          await tester.pumpAndSettle();
          expect(find.text(l10n.problemUnreadableFile), findsOneWidget);

          picker.next = pickedText('notxml.xml', 'hello <');
          await tester.tap(find.text(l10n.actionChooseFile).last);
          await tester.pumpAndSettle();
          expect(find.text(l10n.checkUnreadable), findsOneWidget);
        },
      );

      testWidgets('a server refusal during upload is shown with one action', (
        tester,
      ) async {
        final api = apiWithForms()..failWith = null;
        final picker = await open(tester, api);
        final l10n = l10nOf(tester);
        picker.next = pickedText(
          'ok.xml',
          utf8.decode(utf8.encode(householdXForm(version: '9'))),
        );
        await tester.tap(find.text(l10n.formsChooseFile).last);
        await tester.pumpAndSettle();
        api.failWith = const AppProblem(ProblemKind.notAllowed);
        await tester.tap(find.text(l10n.uploadButton));
        await tester.pumpAndSettle();
        expect(find.text(l10n.problemNotAllowed), findsOneWidget);
        expect(find.text(l10n.actionClose), findsWidgets);
      });
    });
  }
}
