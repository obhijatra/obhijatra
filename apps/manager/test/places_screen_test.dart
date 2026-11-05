import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/places.dart';
import 'package:obhijatra_manager/src/state/file_picker.dart';
import 'package:obhijatra_manager/src/ui/forms_screen.dart';
import 'package:obhijatra_manager/src/ui/people_screen.dart';
import 'package:obhijatra_manager/src/ui/person_editor.dart';
import 'package:obhijatra_manager/src/ui/places_import_screen.dart';
import 'package:obhijatra_manager/src/ui/places_screen.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';
import 'support/people_fixtures.dart';

/// A closed branch in the South region.
const Place oldMarket = Place(
  id: 'oldmarket000001',
  name: 'Old Market branch',
  code: 'S-OLD',
  parentId: 'southregion0001',
  path: '/headoffice00001/southregion0001/oldmarket000001/',
  closed: true,
);

/// An open branch nobody works at.
const Place uttara = Place(
  id: 'uttarabranch001',
  name: 'Uttara branch',
  code: '',
  parentId: 'northregion0001',
  path: '/headoffice00001/northregion0001/uttarabranch001/',
);

/// Another open branch nobody works at, added by mistake.
const Place spare = Place(
  id: 'sparebranch0001',
  name: 'Spare branch',
  code: '',
  parentId: 'northregion0001',
  path: '/headoffice00001/northregion0001/sparebranch0001/',
);

/// The sample organisation, with a closed place and two empty branches.
FakeManagerApi placesApi() =>
    peopleApi(FakeManagerApi(user: staff('org_admin')))
      ..places.addAll(<Place>[oldMarket, uttara, spare]);

Finder fieldIn(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(EditableText),
);

Finder button<T extends Widget>(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is T),
);

Finder rowOf(Place place) => find.byKey(ValueKey<String>('place-${place.id}'));

/// [finder] inside the tree only.
Finder inTree(Finder finder) => find.descendant(
  of: find.byKey(const ValueKey<String>('places-tree')),
  matching: finder,
);

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets a message at the bottom go, so it covers nothing.
Future<void> waitOutMessage(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Starts as an org admin and opens Places.
Future<AppLocalizations> openPlaces(
  WidgetTester tester,
  FakeManagerApi api, {
  required String lang,
  Size size = const Size(1280, 900),
  FakeCsvPicker? csvPicker,
}) async {
  await pumpManager(tester, api, lang: lang, size: size, csvPicker: csvPicker);
  final l10n = l10nOf(tester);
  await tester.tap(find.bySemanticsLabel(l10n.navPlaces).first);
  await tester.pumpAndSettle();
  expect(find.byType(PlacesScreen), findsOneWidget);
  return l10n;
}

/// Opens [place]'s menu of actions and picks [label].
Future<void> act(WidgetTester tester, Place place, String label) async {
  await tapAndSettle(
    tester,
    find.byKey(ValueKey<String>('place-actions-${place.id}')),
  );
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// The labels in [place]'s menu of actions (the menu is closed again).
Future<List<String>> actionsOf(WidgetTester tester, Place place) async {
  await tapAndSettle(
    tester,
    find.byKey(ValueKey<String>('place-actions-${place.id}')),
  );
  final items = find.byWidgetPredicate((widget) => widget is PopupMenuItem);
  final labels = <String>[
    for (var i = 0; i < items.evaluate().length; i++)
      tester
          .widget<Text>(
            find.descendant(of: items.at(i), matching: find.byType(Text)).first,
          )
          .data!,
  ];
  expect(labels, isNotEmpty);
  await tester.tapAt(Offset.zero);
  await tester.pumpAndSettle();
  return labels;
}

Future<void> typeInto(WidgetTester tester, String key, String text) async {
  await tester.enterText(fieldIn(key), text);
  await tester.pumpAndSettle();
}

/// Scrolls the import page from the top until [finder] is in view.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('import-page')),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  await tester.pumpAndSettle();
}

PickedFile pickedBytes(String name, List<int> bytes) =>
    PickedFile(name: name, bytes: Uint8List.fromList(bytes));

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('Places ($lang)', () {
      testWidgets('only active organisation admins see Places', (tester) async {
        for (final user in <StaffUser>[
          staff('supervisor'),
          staff('branch_manager'),
          staff('me'),
          staff('donor_readonly'),
          const StaffUser(
            id: 'u9',
            name: 'Old Admin',
            email: 'old@example.org',
            role: 'org_admin',
            active: false,
          ),
        ]) {
          await tester.pumpWidget(const SizedBox());
          await pumpManager(tester, FakeManagerApi(user: user), lang: lang);
          final l10n = l10nOf(tester);
          expect(
            find.bySemanticsLabel(l10n.navPlaces),
            findsNothing,
            reason: '${user.role} ${user.active}',
          );
        }

        // An admin leaves Places open and signs out; a supervisor signs in
        // on the same computer and does not land on it.
        await tester.pumpWidget(const SizedBox());
        final api = placesApi();
        final l10n = await openPlaces(tester, api, lang: lang);
        await tester.tap(find.byTooltip(l10n.accountMenu));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.menuSignOut).last);
        await tester.pumpAndSettle();
        expect(find.byType(SignInScreen), findsOneWidget);
        api.signInRole = 'supervisor';
        final fields = find.byType(TextFormField);
        final count = fields.evaluate().length;
        if (count == 3) {
          await tester.enterText(fields.at(0), 'https://data.example.org');
        }
        await tester.enterText(fields.at(count - 2), 'karim@example.org');
        await tester.enterText(fields.at(count - 1), 'a-long-password');
        await tester.tap(find.widgetWithText(FilledButton, l10n.signInButton));
        await tester.pumpAndSettle();
        expect(find.byType(PlacesScreen), findsNothing);
        expect(find.byType(FormsScreen), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.navPlaces), findsNothing);
      });

      testWidgets('the tree: opening and shutting, codes, closed places '
          'and search', (tester) async {
        final api = placesApi();
        final l10n = await openPlaces(tester, api, lang: lang);
        // The organisation and the level inside it are open at first.
        for (final place in <Place>[
          headOffice,
          northRegion,
          mirpurBranch,
          uttara,
          spare,
          southRegion,
        ]) {
          expect(rowOf(place), findsOneWidget, reason: place.name);
        }
        expect(find.textContaining(l10n.placeRootNote), findsOneWidget);
        expect(find.text(l10n.placeCodeShown('N-MIR')), findsOneWidget);
        expect(
          find.textContaining(l10n.placeInsideCount(3)),
          findsOneWidget,
          reason: 'North region has three places inside',
        );
        // The closed branch is hidden, and the screen says so.
        expect(rowOf(oldMarket), findsNothing);
        expect(find.text(l10n.placesClosedHidden(1)), findsOneWidget);

        // Shut North region, then open it again.
        await tapAndSettle(
          tester,
          find.byKey(ValueKey<String>('place-toggle-${northRegion.id}')),
        );
        expect(rowOf(mirpurBranch), findsNothing);
        expect(
          find.byTooltip(l10n.placeOpenInside('North region')),
          findsOneWidget,
        );
        await tapAndSettle(tester, inTree(find.text('North region')));
        expect(rowOf(mirpurBranch), findsOneWidget);

        // Closed places, shown on request: muted, with a word, not colour
        // alone.
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey<String>('places-show-closed')),
        );
        expect(rowOf(oldMarket), findsOneWidget);
        expect(
          find.descendant(
            of: rowOf(oldMarket),
            matching: find.text(l10n.placeClosed),
          ),
          findsOneWidget,
        );
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey<String>('places-show-closed')),
        );
        expect(rowOf(oldMarket), findsNothing);

        // Search finds a place by name or code, with the places above it.
        await typeInto(tester, 'places-search', 'n-mir');
        await tester.pumpAndSettle();
        expect(find.text(l10n.placesMatches(1)), findsOneWidget);
        expect(rowOf(mirpurBranch), findsOneWidget);
        expect(
          find.textContaining('Head office › North region'),
          findsOneWidget,
        );
        expect(rowOf(southRegion), findsNothing);
        // A closed place is found only with closed places shown.
        await typeInto(tester, 'places-search', 'old market');
        await tester.pumpAndSettle();
        expect(find.text(l10n.placeNoMatch), findsOneWidget);
        expect(find.text(l10n.placesNoMatchClosedBody), findsOneWidget);
        await tapAndSettle(tester, find.byTooltip(l10n.peopleSearchClear));
        expect(rowOf(southRegion), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a new organisation is told how to start', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..places = <Place>[headOffice];
        final l10n = await openPlaces(tester, api, lang: lang);
        expect(rowOf(headOffice), findsOneWidget);
        expect(find.text(l10n.placesEmptyTitle), findsOneWidget);
        expect(find.text(l10n.placesEmptyBody('Head office')), findsOneWidget);
        expect(await actionsOf(tester, headOffice), <String>[
          l10n.placeAddInside,
          l10n.placeRename,
        ]);

        // A server with no organisation set up offers nothing to change.
        await tester.pumpWidget(const SizedBox());
        await openPlaces(
          tester,
          FakeManagerApi(user: staff('org_admin')),
          lang: lang,
        );
        expect(find.text(l10n.placesNoneTitle), findsOneWidget);
        expect(find.byKey(const ValueKey('places-add')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('adding and renaming; a name or code already used is '
          'shown under its field', (tester) async {
        final api = placesApi();
        final l10n = await openPlaces(tester, api, lang: lang);
        await tapAndSettle(tester, find.byKey(const ValueKey('places-add')));
        expect(find.text(l10n.placeAddTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('place-parent')),
            matching: find.text('Head office'),
          ),
          findsOneWidget,
        );

        // Nothing typed.
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        expect(find.text(l10n.placeErrorName), findsOneWidget);
        expect(api.placeChanges, isEmpty);

        // A name its neighbour has, in other capitals.
        await typeInto(tester, 'place-name', 'NORTH REGION');
        expect(find.text(l10n.placeErrorName), findsNothing);
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        expect(
          find.text(l10n.placeErrorNameTaken('Head office')),
          findsOneWidget,
        );

        // A code another place has.
        await typeInto(tester, 'place-name', 'East region');
        await typeInto(tester, 'place-code', 'n');
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        expect(find.text(l10n.placeErrorCodeTaken), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(l10n.placeErrorCodeTaken)).dy,
          greaterThan(tester.getTopLeft(fieldIn('place-code')).dy),
        );

        // Characters that could hide or reorder text.
        await typeInto(tester, 'place-name', 'East\u202E region');
        await typeInto(tester, 'place-code', 'E');
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        expect(find.text(l10n.placeErrorNameUnsafe), findsOneWidget);
        await typeInto(tester, 'place-name', '  East\u00A0 region ');
        await typeInto(tester, 'place-code', 'E\u0007');
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        expect(find.text(l10n.placeErrorCodeUnsafe), findsOneWidget);

        await typeInto(tester, 'place-code', 'E');
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        expect(find.text(l10n.placeAddTitle), findsNothing);
        final (_, added) = api.placeChanges.single;
        expect(added.name, 'East region');
        expect(added.code, 'E');
        expect(added.parentId, headOffice.id);
        expect(find.text(l10n.placeAdded('East region')), findsOneWidget);
        expect(inTree(find.text('East region')), findsOneWidget);
        await waitOutMessage(tester);

        // Inside a branch, which opens to show it.
        await act(tester, mirpurBranch, l10n.placeAddInside);
        expect(
          find.text('Head office › North region › Mirpur branch'),
          findsOneWidget,
        );
        await typeInto(tester, 'place-name', 'Ward 1');
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        expect(api.placeChanges.last.$2.parentId, mirpurBranch.id);
        expect(inTree(find.text('Ward 1')), findsOneWidget);
        await waitOutMessage(tester);

        // Rename, keeping the code.
        await act(tester, southRegion, l10n.placeRename);
        expect(find.text(l10n.placeParentFixed('Head office')), findsOneWidget);
        expect(
          tester.widget<EditableText>(fieldIn('place-code')).controller.text,
          'S',
        );
        await typeInto(tester, 'place-name', 'South-west region');
        await tapAndSettle(tester, find.byKey(const ValueKey('place-save')));
        final (word, renamed) = api.placeChanges.last;
        expect(word, 'update');
        expect(renamed.name, 'South-west region');
        expect(renamed.code, 'S');
        expect(find.text(l10n.personSaved), findsOneWidget);
        expect(inTree(find.text('South-west region')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('closing: refused while places or people are inside; '
          '"See who works here"; reopening', (tester) async {
        final api = placesApi();
        final l10n = await openPlaces(tester, api, lang: lang);

        // The organisation itself is never closed or deleted.
        final rootActions = await actionsOf(tester, headOffice);
        expect(rootActions, isNot(contains(l10n.placeCloseAction)));
        expect(rootActions, isNot(contains(l10n.placeDeleteAction)));

        // Open places inside.
        await act(tester, northRegion, l10n.placeCloseAction);
        expect(find.text(l10n.placeCloseTitle('North region')), findsOneWidget);
        expect(find.text(l10n.placeCloseBody), findsOneWidget);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-status-confirm')),
        );
        expect(find.text(l10n.placeErrorOpenInside(3)), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.actionCancel));
        expect(api.placeChanges, isEmpty);

        // Active people still work there: see them in People.
        await act(tester, mirpurBranch, l10n.placeCloseAction);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-status-confirm')),
        );
        expect(find.text(l10n.placeErrorPeople(2)), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.placeSeePeople));
        expect(find.byType(PeopleScreen), findsOneWidget);
        expect(api.peopleQueries.last.placePath, mirpurBranch.path);
        expect(api.peopleQueries.last.status, PeopleStatus.active);

        // Back in Places, South region closes: nobody active works there
        // and the place inside it is closed.
        await tester.tap(find.bySemanticsLabel(l10n.navPlaces).first);
        await tester.pumpAndSettle();
        await act(tester, southRegion, l10n.placeCloseAction);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-status-confirm')),
        );
        expect(api.placeChanges.single.$1, 'close');
        expect(find.text(l10n.placeClosedDone('South region')), findsOneWidget);
        expect(rowOf(southRegion), findsNothing);
        expect(find.text(l10n.placesClosedHidden(2)), findsOneWidget);
        await waitOutMessage(tester);

        // A place inside a closed place cannot reopen.
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey<String>('places-show-closed')),
        );
        final closedActions = await actionsOf(tester, oldMarket);
        expect(closedActions, isNot(contains(l10n.placeAddInside)));
        expect(closedActions, contains(l10n.placeReopenAction));
        await act(tester, oldMarket, l10n.placeReopenAction);
        expect(find.text(l10n.placeReopenBody), findsOneWidget);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-status-confirm')),
        );
        expect(find.text(l10n.placeErrorAboveClosed), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.actionCancel));

        // South region reopens.
        await act(tester, southRegion, l10n.placeReopenAction);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-status-confirm')),
        );
        expect(api.placeChanges.last.$1, 'reopen');
        expect(
          find.text(l10n.placeReopenedDone('South region')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('deleting: offered only for a place with nothing inside; '
          'in use suggests "Close it instead"', (tester) async {
        final api = placesApi()..placesInUse.add(uttara.id);
        final l10n = await openPlaces(tester, api, lang: lang);
        expect(
          await actionsOf(tester, northRegion),
          isNot(contains(l10n.placeDeleteAction)),
        );

        // A record uses Uttara branch.
        await act(tester, uttara, l10n.placeDeleteAction);
        expect(
          find.text(l10n.placeDeleteTitle('Uttara branch')),
          findsOneWidget,
        );
        expect(find.text(l10n.placeDeleteBody), findsOneWidget);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-delete-confirm')),
        );
        expect(find.text(l10n.placeErrorInUse), findsOneWidget);
        expect(
          find.byKey(const ValueKey('place-delete-confirm')),
          findsNothing,
        );
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-close-instead')),
        );
        expect(
          find.text(l10n.placeCloseTitle('Uttara branch')),
          findsOneWidget,
        );
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-status-confirm')),
        );
        expect(api.placeChanges.single.$1, 'close');
        expect(rowOf(uttara), findsNothing);
        await waitOutMessage(tester);

        // Spare branch was added by mistake and nothing uses it.
        await act(tester, spare, l10n.placeDeleteAction);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('place-delete-confirm')),
        );
        expect(api.placeChanges.last.$1, 'delete');
        expect(
          find.text(l10n.placeDeletedDone('Spare branch')),
          findsOneWidget,
        );
        expect(rowOf(spare), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('import: explained, checked, previewed, then added', (
        tester,
      ) async {
        final picker = FakeCsvPicker();
        final api = placesApi();
        final l10n = await openPlaces(
          tester,
          api,
          lang: lang,
          csvPicker: picker,
        );
        await tapAndSettle(tester, find.byKey(const ValueKey('places-import')));
        expect(find.byType(PlacesImportScreen), findsOneWidget);
        for (final words in <String>[
          l10n.importStepFile,
          l10n.importRuleCode,
          l10n.importRuleSave,
          l10n.importExampleRegion1,
          'code',
          'MRP10',
        ]) {
          expect(find.text(words), findsWidgets, reason: words);
        }
        // New places go inside the organisation unless the admin chooses.
        await scrollTo(tester, find.byKey(const ValueKey('import-choose')));
        expect(find.text(l10n.importStepChoose), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('import-parent')),
            matching: find.text('Head office'),
          ),
          findsOneWidget,
        );

        picker.next = pickedText(
          'places.csv',
          '\uFEFFRegion,Area,Branch,code\r\n'
              'North region,Mirpur area,Mirpur-10 branch,MRP10\r\n'
              'north region,Mirpur area,"Kafrul branch",KFR\r\n'
              'রাজশাহী অঞ্চল\r\n',
        );
        await tapAndSettle(tester, find.byKey(const ValueKey('import-choose')));
        final check = api.imports.single;
        expect(check.dryRun, isTrue);
        expect(check.parentId, headOffice.id);
        expect(check.rows.map((r) => r.line), <int>[2, 3, 4]);
        expect(check.rows.first.code, 'MRP10');
        expect(api.places, hasLength(7), reason: 'a check saves nothing');

        expect(find.text(l10n.importFileName('places.csv')), findsOneWidget);
        expect(find.text(l10n.importRowCount(3)), findsOneWidget);
        expect(find.text(l10n.importCodeColumn('code')), findsOneWidget);
        final summary =
            '${l10n.importNewCount(4)} · ${l10n.importExistingCount(1)}';
        expect(find.text(summary), findsWidgets);
        // The preview: the region already there, the new places marked.
        await scrollTo(tester, find.text(l10n.importAlready));
        await scrollTo(tester, find.text('Kafrul branch'));
        expect(find.text(l10n.importAlready), findsOneWidget);
        expect(
          find.text(l10n.importNew, skipOffstage: false),
          findsNWidgets(4),
        );
        await scrollTo(tester, find.text('রাজশাহী অঞ্চল'));

        await tapAndSettle(tester, find.byKey(const ValueKey('import-add')));
        expect(api.imports.last.dryRun, isFalse);
        expect(find.byType(PlacesImportScreen), findsNothing);
        expect(find.text(l10n.importDone(4)), findsOneWidget);
        expect(inTree(find.text('Mirpur area')), findsOneWidget);
        expect(inTree(find.text('রাজশাহী অঞ্চল')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('import: problems are listed by line and nothing can be '
          'added until they are fixed', (tester) async {
        final picker = FakeCsvPicker();
        final api = placesApi();
        final l10n = await openPlaces(
          tester,
          api,
          lang: lang,
          csvPicker: picker,
        );
        await tapAndSettle(tester, find.byKey(const ValueKey('places-import')));
        await scrollTo(tester, find.byKey(const ValueKey('import-choose')));

        // Files that cannot be read at all. A huge one is not even read.
        picker.next = PickedFile.tooLarge('huge.csv');
        await tapAndSettle(tester, find.byKey(const ValueKey('import-choose')));
        expect(picker.limits, <int>[maxImportBytes]);
        expect(find.text(l10n.importErrorTooBig), findsOneWidget);
        expect(find.byKey(const ValueKey('import-header')), findsNothing);
        picker.next = pickedBytes('old.csv', <int>[0x43, 0x61, 0x66, 0xE9]);
        await tapAndSettle(tester, find.byKey(const ValueKey('import-choose')));
        expect(find.text(l10n.importErrorNotUtf8), findsOneWidget);
        picker.next = pickedBytes('places.xlsx', <int>[0x50, 0x4B, 3, 4, 9]);
        await tapAndSettle(tester, find.byKey(const ValueKey('import-choose')));
        expect(find.text(l10n.importErrorExcel), findsOneWidget);
        expect(api.imports, isEmpty);

        // A gap in row 3; the server finds a closed place in row 4.
        picker.next = pickedText(
          'places.csv',
          'Region,Area,Branch\n'
              'North region,Mirpur area\n'
              'North region,,Pallabi branch\n'
              'South region,Old Market branch,Stall 1\n',
        );
        await tapAndSettle(tester, find.byKey(const ValueKey('import-choose')));
        expect(api.imports.single.rows.map((r) => r.line), <int>[2, 4]);
        expect(find.text(l10n.importProblems(2)), findsWidgets);
        // The server's sentence, in the app's own words.
        final closed = l10n.importServerClosed('Old Market branch');
        await scrollTo(tester, find.text(closed));
        expect(find.text(l10n.importLine(3)), findsOneWidget);
        expect(find.text(l10n.importRowGap('B')), findsOneWidget);
        expect(find.text(l10n.importLine(4)), findsOneWidget);
        final add = find.byKey(const ValueKey('import-add'));
        expect(add, findsOneWidget);
        expect(tester.widget<ButtonStyleButton>(add).onPressed, isNull);

        // Leaving asks first: the file has not been added.
        await tapAndSettle(tester, button<TextButton>(l10n.placesBack));
        expect(find.text(l10n.leaveImportTitle), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.leaveStay));
        expect(find.byType(PlacesImportScreen), findsOneWidget);

        // Fixed: the check passes, but something changes before the real
        // import, which then saves nothing and says why.
        picker.next = pickedText(
          'places.csv',
          'Region,Area\nNorth region,Mirpur area\n',
        );
        await scrollTo(tester, find.byKey(const ValueKey('import-choose')));
        await tapAndSettle(tester, find.byKey(const ValueKey('import-choose')));
        expect(find.text(l10n.importLine(3)), findsNothing);
        expect(tester.widget<ButtonStyleButton>(add).onPressed, isNotNull);
        api.importSurprise = const <PlaceImportProblem>[
          PlaceImportProblem(
            line: 2,
            code: 'code_taken',
            value: 'M',
            message: 'Another place already has the code "M".',
          ),
        ];
        await tapAndSettle(tester, add);
        expect(find.text(l10n.importChanged), findsOneWidget);
        await scrollTo(tester, find.text(l10n.importLine(2)));
        expect(find.text(l10n.importServerCodeTaken('M')), findsOneWidget);
        expect(tester.widget<ButtonStyleButton>(add).onPressed, isNull);
        expect(find.byType(PlacesImportScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the People place chooser hides closed places but shows a '
          'person\'s closed place', (tester) async {
        final api = placesApi();
        api.people[PersonKind.staff]!.add(
          person(id: 's9', name: 'Moni Begum', place: oldMarket, active: false),
        );
        await pumpManager(tester, api, lang: lang);
        final l10n = l10nOf(tester);
        await tester.tap(find.bySemanticsLabel(l10n.navPeople).first);
        await tester.pumpAndSettle();

        // The filter finds people at closed places too, and says so.
        await tapAndSettle(tester, find.byKey(const ValueKey('people-place')));
        expect(find.text('Old Market branch'), findsOneWidget);
        expect(find.text(l10n.placeClosed), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.actionCancel));

        // Moni works at the closed branch: it is shown, marked "Closed".
        await tapAndSettle(
          tester,
          find
              .descendant(
                of: find.byType(ListView),
                matching: find.text('Moni Begum'),
              )
              .first,
        );
        expect(find.byType(PersonEditor), findsOneWidget);
        final field = find.byKey(const ValueKey('person-place'));
        expect(
          find.descendant(
            of: field,
            matching: find.text(
              'Head office › South region › Old Market branch',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: field, matching: find.text(l10n.placeClosed)),
          findsOneWidget,
        );
        expect(find.text(l10n.personPlaceClosedHelp), findsOneWidget);

        // Choosing again offers open places only.
        await tapAndSettle(tester, field);
        expect(find.text(l10n.personPlaceChoose), findsWidgets);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Old Market branch'),
          ),
          findsNothing,
        );
        await tapAndSettle(tester, find.text('South region').last);
        expect(
          find.descendant(of: field, matching: find.text(l10n.placeClosed)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('works at 1024, 700 and 600 px wide', (tester) async {
        for (final size in <Size>[
          const Size(1024, 700),
          const Size(700, 800),
          const Size(600, 900),
        ]) {
          await tester.pumpWidget(const SizedBox());
          final picker = FakeCsvPicker()
            ..next = pickedText(
              'places.csv',
              'Region,Area,Branch,code\n'
                  'North region,Mirpur area,Mirpur-10 branch with a long '
                  'name for a small screen,MRP10\n',
            );
          final api = placesApi();
          final l10n = await openPlaces(
            tester,
            api,
            lang: lang,
            size: size,
            csvPicker: picker,
          );
          expect(tester.takeException(), isNull, reason: '$size tree');
          await act(tester, mirpurBranch, l10n.placeRename);
          expect(tester.takeException(), isNull, reason: '$size dialog');
          await tapAndSettle(tester, button<TextButton>(l10n.actionCancel));
          await tapAndSettle(
            tester,
            find.byKey(const ValueKey('places-import')),
          );
          expect(tester.takeException(), isNull, reason: '$size import');
          await scrollTo(tester, find.byKey(const ValueKey('import-choose')));
          await tapAndSettle(
            tester,
            find.byKey(const ValueKey('import-choose')),
          );
          expect(tester.takeException(), isNull, reason: '$size preview');
        }
      });
    });
  }
}
