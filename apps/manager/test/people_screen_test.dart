import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/ui/forms_screen.dart';
import 'package:obhijatra_manager/src/ui/people_screen.dart';
import 'package:obhijatra_manager/src/ui/person_editor.dart';
import 'package:obhijatra_manager/src/ui/sign_in_screen.dart';

import 'support/fake_api.dart';
import 'support/harness.dart';
import 'support/people_fixtures.dart';

Finder button<T extends Widget>(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is T),
);

/// The text field inside the widget with [key].
Finder fieldIn(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(EditableText),
);

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(fieldIn(key));
  await tester.enterText(fieldIn(key), text);
  await tester.pump();
}

/// The dropdown menu labelled [label].
Finder menuLabelled(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownMenu &&
      widget.label is Text &&
      (widget.label! as Text).data == label,
);

/// [finder], inside the list of people only (dropdown menus keep hidden
/// copies of their choices).
Finder inList(Finder finder) =>
    find.descendant(of: find.byType(ListView), matching: finder);

/// Picks [label] in the dropdown menu labelled [menu].
Future<void> pickFromMenu(
  WidgetTester tester,
  String menu,
  String label,
) async {
  await tapAndSettle(tester, menuLabelled(menu));
  await tester.tap(
    find
        .descendant(of: find.byType(MenuItemButton), matching: find.text(label))
        .last,
  );
  await tester.pumpAndSettle();
}

/// Starts as an org admin and opens People.
Future<AppLocalizations> openPeople(
  WidgetTester tester,
  FakeManagerApi api, {
  required String lang,
  Size size = const Size(1280, 900),
}) async {
  await pumpManager(tester, api, lang: lang, size: size);
  final l10n = l10nOf(tester);
  await tester.tap(find.bySemanticsLabel(l10n.navPeople).first);
  await tester.pumpAndSettle();
  expect(find.byType(PeopleScreen), findsOneWidget);
  return l10n;
}

/// Opens [name]'s page from the list.
Future<void> openPerson(WidgetTester tester, String name) async {
  await tapAndSettle(tester, inList(find.text(name)).first);
  expect(find.byType(PersonEditor), findsOneWidget);
}

/// Copies to the clipboard go here.
List<String> watchClipboard(WidgetTester tester) {
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
  return copied;
}

void main() {
  for (final lang in <String>['en', 'bn']) {
    group('People ($lang)', () {
      testWidgets('only active organisation admins see People', (tester) async {
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
            find.bySemanticsLabel(l10n.navPeople),
            findsNothing,
            reason: '${user.role} ${user.active}',
          );
          expect(find.text(l10n.navPeople), findsNothing);
        }

        // An admin leaves People open and signs out; a supervisor signs in
        // on the same computer and does not land on it.
        await tester.pumpWidget(const SizedBox());
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
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
        expect(find.byType(PeopleScreen), findsNothing);
        expect(find.byType(FormsScreen), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.navPeople), findsNothing);
      });

      testWidgets('lists office and field staff with role, place, contact '
          'and status', (tester) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        expect(api.peopleQueries.last, const PeopleQuery());
        for (final text in <String>[
          'Karim Hossain',
          'Rina Akter',
          'Tania Rahman',
          'karim@example.org',
          '+880 1711-111111',
          l10n.roleSupervisor,
          l10n.roleBranchManager,
          l10n.roleOrgAdmin,
        ]) {
          expect(find.textContaining(text), findsWidgets, reason: text);
        }
        expect(
          find.textContaining('${l10n.roleSupervisor} · Mirpur branch'),
          findsOneWidget,
        );
        // Rina and Tania have confirmed addresses; Karim does not.
        expect(inList(find.text(l10n.emailConfirmed)), findsNWidgets(2));
        expect(inList(find.text(l10n.statusActive)), findsNWidgets(2));
        expect(inList(find.text(l10n.statusDeactivated)), findsOneWidget);
        expect(inList(find.text(l10n.statusLocked)), findsOneWidget);

        // Field staff.
        await tapAndSettle(tester, find.text(l10n.kindField).first);
        expect(api.peopleQueries.last.kind, PersonKind.field);
        expect(inList(find.text('Nasrin Sultana')), findsOneWidget);
        expect(find.textContaining(l10n.roleFieldOfficer), findsOneWidget);
        expect(inList(find.text(l10n.statusMustChoose)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('search, status and place filters ask the server', (
        tester,
      ) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);

        // Search waits for a pause in typing.
        await tester.enterText(fieldIn('people-search'), 'karim');
        await tester.pump(const Duration(milliseconds: 100));
        expect(api.peopleQueries.last.search, isEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(api.peopleQueries.last.search, 'karim');
        expect(inList(find.text('Karim Hossain')), findsOneWidget);
        expect(inList(find.text('Rina Akter')), findsNothing);
        await tapAndSettle(tester, find.byTooltip(l10n.peopleSearchClear));
        expect(api.peopleQueries.last.search, isEmpty);

        // Locked.
        await pickFromMenu(tester, l10n.peopleStatus, l10n.statusLocked);
        expect(api.peopleQueries.last.status, PeopleStatus.locked);
        expect(inList(find.text('Karim Hossain')), findsOneWidget);
        expect(inList(find.text('Tania Rahman')), findsNothing);

        // Deactivated, then everyone.
        await pickFromMenu(tester, l10n.peopleStatus, l10n.statusDeactivated);
        expect(api.peopleQueries.last.status, PeopleStatus.deactivated);
        expect(inList(find.text('Rina Akter')), findsOneWidget);
        expect(inList(find.text('Karim Hossain')), findsNothing);
        await pickFromMenu(tester, l10n.peopleStatus, l10n.peopleStatusAll);
        expect(api.peopleQueries.last.status, isNull);

        // A place and the places below it.
        await tapAndSettle(tester, find.byKey(const ValueKey('people-place')));
        expect(find.text(l10n.personPlaceChoose), findsOneWidget);
        await tapAndSettle(tester, find.text('North region'));
        expect(api.peopleQueries.last.placePath, northRegion.path);
        expect(inList(find.text('Karim Hossain')), findsOneWidget);
        expect(inList(find.text('Rina Akter')), findsNothing);
        expect(find.text('North region'), findsOneWidget);

        // Nobody matches.
        await tester.enterText(fieldIn('people-search'), 'nobody-like-this');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(find.text(l10n.peopleNoMatchTitle), findsOneWidget);

        // Back to all places.
        await tapAndSettle(tester, find.byKey(const ValueKey('people-place')));
        await tapAndSettle(tester, find.text(l10n.placeAll).last);
        expect(api.peopleQueries.last.placePath, isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty lists say what to do', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..places = List<Place>.of(samplePlaces);
        final l10n = await openPeople(tester, api, lang: lang);
        expect(find.text(l10n.peopleEmptyStaffTitle), findsOneWidget);
        expect(find.text(l10n.peopleEmptyBody), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.kindField).first);
        expect(find.text(l10n.peopleEmptyFieldTitle), findsOneWidget);
        await pickFromMenu(tester, l10n.peopleStatus, l10n.statusLocked);
        expect(find.text(l10n.peopleNoLockedTitle), findsOneWidget);
      });

      testWidgets('large lists are paged 50 at a time', (tester) async {
        final api = FakeManagerApi(user: staff('org_admin'))
          ..places = List<Place>.of(samplePlaces)
          ..peopleTotalOverride = 120
          ..personFor = ((i) => person(id: 'p$i', name: 'Person $i'));
        final l10n = await openPeople(tester, api, lang: lang);
        expect(find.text(l10n.pagingPage(1, 3)), findsOneWidget);
        expect(find.text(l10n.pagingRange(1, 50, 120)), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.pagingNext));
        expect(api.peopleQueries.last.page, 2);
        expect(find.text(l10n.pagingRange(51, 100, 120)), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.pagingNext));
        expect(find.text(l10n.pagingRange(101, 120, 120)), findsOneWidget);
        // Changing a filter starts again at page 1.
        await pickFromMenu(tester, l10n.peopleSort, l10n.peopleSortName);
        expect(api.peopleQueries.last.page, 1);
        expect(api.peopleQueries.last.sort, PeopleSort.name);
      });

      testWidgets('adding a person with a one-time password shows it once, '
          'with Copy', (tester) async {
        final copied = watchClipboard(tester);
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await tapAndSettle(tester, button<FilledButton>(l10n.peopleAdd));
        expect(find.byType(PersonEditor), findsOneWidget);

        // Nothing typed: every missing thing is named under its field.
        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        expect(api.created, isEmpty);
        expect(find.text(l10n.personErrorName), findsOneWidget);
        expect(find.text(l10n.personErrorRole), findsOneWidget);
        expect(find.text(l10n.personErrorPlace), findsOneWidget);
        expect(find.text(l10n.personErrorEmailOrPhone), findsOneWidget);

        await typeInto(tester, 'person-name', 'Shila Das');
        await pickFromMenu(tester, l10n.accountRole, l10n.roleSupervisor);
        await tapAndSettle(tester, find.byKey(const ValueKey('person-place')));
        await tapAndSettle(tester, find.text('Mirpur branch'));
        expect(
          find.text('Head office › North region › Mirpur branch'),
          findsOneWidget,
        );
        // Without an email address, a one-time password is not possible.
        final otp = find.byKey(const ValueKey('signin-otp'));
        expect(tester.widget<RadioListTile<Object>>(otp).enabled, isFalse);
        await typeInto(tester, 'person-email', 'shila@example.org');
        expect(tester.widget<RadioListTile<Object>>(otp).enabled, isTrue);

        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        final added = api.created.single;
        expect(added.kind, PersonKind.staff);
        expect(added.oneTime, isTrue);
        expect(added.draft.name, 'Shila Das');
        expect(added.draft.role, 'supervisor');
        expect(added.draft.locationId, mirpurBranch.id);
        expect(added.draft.verified, isFalse);
        expect(
          added.password,
          matches(RegExp(r'^[a-z2-9]{4}-[a-z2-9]{4}-[a-z2-9]{4}$')),
        );

        // The password is shown, exactly as sent, with what to do.
        expect(find.text(added.password), findsOneWidget);
        expect(find.text(l10n.personAddedHeading('Shila Das')), findsOneWidget);
        expect(find.text(l10n.otpGive('Shila Das')), findsOneWidget);
        expect(
          find.text(l10n.otpSignInWith('shila@example.org')),
          findsOneWidget,
        );
        await tapAndSettle(tester, find.text(l10n.otpCopy));
        expect(copied, <String>[added.password]);
        expect(find.text(l10n.otpCopied), findsOneWidget);

        // Leaving asks first, since it will not be shown again.
        await tester.tap(find.bySemanticsLabel(l10n.navForms).first);
        await tester.pumpAndSettle();
        expect(find.text(l10n.leaveOtpTitle), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.leaveStay));
        expect(find.text(added.password), findsOneWidget);

        await tapAndSettle(tester, button<FilledButton>(l10n.otpDone));
        expect(find.byType(PersonEditor), findsNothing);
        expect(find.text(added.password), findsNothing);
        expect(inList(find.text('Shila Das')), findsOneWidget);
        // Opening Shila again never shows the password.
        await openPerson(tester, 'Shila Das');
        expect(find.text(added.password), findsNothing);
        expect(find.text(l10n.statusMustChoose), findsOneWidget);
      });

      testWidgets('a person who signs in by SMS code or Google gets no '
          'password to see', (tester) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await tapAndSettle(tester, button<FilledButton>(l10n.peopleAdd));
        await typeInto(tester, 'person-name', 'Jamal Uddin');
        await tapAndSettle(tester, find.text(l10n.kindField).last);
        expect(find.text(l10n.roleFieldOfficer), findsOneWidget);
        await tapAndSettle(tester, find.byKey(const ValueKey('person-place')));
        await tapAndSettle(tester, find.text('South region'));
        await typeInto(tester, 'person-phone', '01812 345678');
        expect(find.text(l10n.personCannotSignIn), findsNothing);

        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        final added = api.created.single;
        expect(added.kind, PersonKind.field);
        expect(added.oneTime, isFalse);
        expect(added.draft.role, fieldOfficerRole);
        expect(added.draft.phone, '+8801812345678');
        expect(added.draft.email, isEmpty);
        // A long random password the server needs, never shown.
        expect(added.password.length, 48);
        expect(find.text(added.password), findsNothing);
        expect(find.text(l10n.otpCopy), findsNothing);
        expect(find.byType(PersonEditor), findsNothing);
        expect(find.text(l10n.personAdded('Jamal Uddin')), findsOneWidget);
      });

      testWidgets('choosing "SMS code or Google only" with an email', (
        tester,
      ) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await tapAndSettle(tester, button<FilledButton>(l10n.peopleAdd));
        await typeInto(tester, 'person-name', 'Mitu Roy');
        await pickFromMenu(tester, l10n.accountRole, l10n.roleMe);
        await tapAndSettle(tester, find.byKey(const ValueKey('person-place')));
        await tapAndSettle(tester, find.text('Head office'));
        await typeInto(tester, 'person-email', 'mitu@example.org');
        await tapAndSettle(tester, find.byKey(const ValueKey('signin-other')));
        // An unconfirmed address and no number: nobody could sign in.
        expect(find.text(l10n.personCannotSignIn), findsOneWidget);
        await tapAndSettle(
          tester,
          find.byKey(const ValueKey('person-verified')),
        );
        expect(find.text(l10n.personCannotSignIn), findsNothing);
        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        final added = api.created.single;
        expect(added.oneTime, isFalse);
        expect(added.draft.verified, isTrue);
        expect(find.text(l10n.otpCopy), findsNothing);
      });

      testWidgets('server refusals appear under the right field', (
        tester,
      ) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await tapAndSettle(tester, button<FilledButton>(l10n.peopleAdd));
        await typeInto(tester, 'person-name', 'Shila Das');
        await pickFromMenu(tester, l10n.accountRole, l10n.roleOrgAdmin);
        await tapAndSettle(tester, find.byKey(const ValueKey('person-place')));
        await tapAndSettle(tester, find.text('Head office'));
        await typeInto(tester, 'person-phone', '01712 000000');
        // An organisation admin needs an email address.
        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        expect(find.text(l10n.personErrorAdminEmail), findsOneWidget);
        expect(api.created, isEmpty);

        await typeInto(tester, 'person-email', 'karim@example.org');
        api.personFailure = const AppProblem(
          ProblemKind.detailsInvalid,
          statusCode: 400,
          fields: <String, String>{
            'email': 'Value must be unique.',
            'phone': 'Value must be unique.',
          },
          codes: <String, String>{
            'email': 'validation_not_unique',
            'phone': 'validation_not_unique',
          },
        );
        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        expect(find.text(l10n.problemDetailsInvalid), findsOneWidget);
        expect(find.text(l10n.personErrorEmailTaken), findsOneWidget);
        expect(find.text(l10n.personErrorPhoneTaken), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(l10n.personErrorEmailTaken)).dy,
          greaterThan(tester.getTopLeft(fieldIn('person-email')).dy),
        );

        // The server's own check, translated.
        api.personFailure = const AppProblem(
          ProblemKind.detailsInvalid,
          statusCode: 400,
          fields: <String, String>{
            'email':
                'Give an email address or a phone number, so this person '
                'can sign in.',
          },
          codes: <String, String>{
            'email': 'validation_email_or_phone_required',
          },
        );
        await typeInto(tester, 'person-email', 'shila@example.org');
        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        expect(find.text(l10n.personErrorEmailOrPhone), findsOneWidget);
        // Typing clears the message.
        await typeInto(tester, 'person-email', 'shila.das@example.org');
        await tester.pumpAndSettle();
        expect(find.text(l10n.personErrorEmailOrPhone), findsNothing);
      });

      testWidgets('editing saves only changes; the last admin is kept', (
        tester,
      ) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await openPerson(tester, 'Karim Hossain');
        expect(find.text(l10n.personSignOutNote), findsOneWidget);
        expect(find.text(l10n.personKindFixed), findsOneWidget);
        expect(find.text(l10n.unsavedChanges), findsNothing);

        await pickFromMenu(tester, l10n.accountRole, l10n.roleBranchManager);
        expect(find.text(l10n.unsavedChanges), findsOneWidget);
        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        final (before, draft) = api.updates.single;
        expect(before.id, 's2');
        expect(draft.changesFrom(before), <String, dynamic>{
          'role': 'branch_manager',
        });
        expect(find.text(l10n.personSaved), findsOneWidget);
        expect(find.text(l10n.unsavedChanges), findsNothing);
        // Let the message go, so it does not cover the Save button.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // The server refuses to leave the organisation without an admin.
        api.personFailure = const AppProblem(
          ProblemKind.detailsInvalid,
          statusCode: 400,
          fields: <String, String>{
            'role':
                'This is the only active organisation admin. Make someone '
                'else an organisation admin first.',
          },
          codes: <String, String>{'role': 'validation_last_org_admin'},
        );
        await pickFromMenu(tester, l10n.accountRole, l10n.roleSupervisor);
        await tapAndSettle(tester, find.byKey(const ValueKey('person-save')));
        expect(find.text(l10n.personErrorLastAdmin), findsOneWidget);
      });

      testWidgets('a changed email address is no longer confirmed', (
        tester,
      ) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await pickFromMenu(tester, l10n.peopleStatus, l10n.statusDeactivated);
        await openPerson(tester, 'Rina Akter');
        Switch verified() => tester.widget<Switch>(
          find.byKey(const ValueKey('person-verified')),
        );
        expect(verified().value, isTrue);
        await typeInto(tester, 'person-email', 'rina.akter@example.org');
        expect(verified().value, isFalse);
        await typeInto(tester, 'person-email', 'rina@example.org');
        expect(verified().value, isTrue);
      });

      testWidgets('deactivating asks first; reactivating does not', (
        tester,
      ) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await openPerson(tester, 'Karim Hossain');
        final active = find.byKey(const ValueKey('person-active'));
        await tapAndSettle(tester, active);
        expect(
          find.text(l10n.deactivateTitle('Karim Hossain')),
          findsOneWidget,
        );
        expect(find.text(l10n.deactivateBody), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.actionCancel));
        expect(api.activeChanges, isEmpty);
        expect(tester.widget<Switch>(active).value, isTrue);

        await tapAndSettle(tester, active);
        await tapAndSettle(tester, button<FilledButton>(l10n.deactivateButton));
        expect(api.activeChanges.single.$2, isFalse);
        expect(tester.widget<Switch>(active).value, isFalse);
        expect(find.text(l10n.statusDeactivated), findsOneWidget);
        expect(
          find.text(l10n.personDeactivated('Karim Hossain')),
          findsOneWidget,
        );

        await tapAndSettle(tester, active);
        expect(find.text(l10n.deactivateBody), findsNothing);
        expect(api.activeChanges.last.$2, isTrue);
        expect(tester.widget<Switch>(active).value, isTrue);
      });

      testWidgets('the only active admin cannot demote or deactivate '
          'themselves', (tester) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')))
          ..activeOrgAdmins = 1;
        final l10n = await openPeople(tester, api, lang: lang);
        await openPerson(tester, 'Tania Rahman');
        expect(find.text(l10n.personOnlyAdmin), findsWidgets);
        final active = find.byKey(const ValueKey('person-active'));
        expect(tester.widget<Switch>(active).onChanged, isNull);
        expect(
          tester
              .widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>))
              .enabled,
          isFalse,
        );

        // With another admin, the switch works; a refusal from the server
        // (someone else stepped down meanwhile) is shown under it.
        await tester.pumpWidget(const SizedBox());
        final api2 = peopleApi(FakeManagerApi(user: staff('org_admin')));
        await openPeople(tester, api2, lang: lang);
        await openPerson(tester, 'Tania Rahman');
        api2.personFailure = const AppProblem(
          ProblemKind.detailsInvalid,
          statusCode: 400,
          fields: <String, String>{'role': 'This is the only active admin.'},
          codes: <String, String>{'role': 'validation_last_org_admin'},
        );
        await tapAndSettle(tester, find.byKey(const ValueKey('person-active')));
        expect(find.text(l10n.deactivateSelfBody), findsOneWidget);
        await tapAndSettle(tester, button<FilledButton>(l10n.deactivateButton));
        expect(find.text(l10n.personErrorLastAdmin), findsOneWidget);
        expect(
          tester
              .widget<Switch>(find.byKey(const ValueKey('person-active')))
              .value,
          isTrue,
        );
      });

      testWidgets('a locked sign-in can be unlocked', (tester) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await openPerson(tester, 'Karim Hossain');
        expect(find.text(l10n.statusLocked), findsOneWidget);
        expect(
          find.textContaining(l10n.personLockedNote('').substring(0, 10)),
          findsOneWidget,
        );
        await tapAndSettle(tester, button<OutlinedButton>(l10n.unlockButton));
        expect(api.unlocked.single.id, 'lock1');
        expect(find.text(l10n.statusLocked), findsNothing);
        expect(find.text(l10n.unlockButton), findsNothing);
        expect(find.text(l10n.unlockDone('Karim Hossain')), findsOneWidget);
      });

      testWidgets('a new one-time password: confirm, then shown once', (
        tester,
      ) async {
        final copied = watchClipboard(tester);
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await openPerson(tester, 'Karim Hossain');
        await tapAndSettle(tester, button<OutlinedButton>(l10n.resetButton));
        expect(
          find.text(l10n.resetConfirmTitle('Karim Hossain')),
          findsOneWidget,
        );
        await tapAndSettle(tester, button<TextButton>(l10n.actionCancel));
        expect(api.resets, isEmpty);

        await tapAndSettle(tester, button<OutlinedButton>(l10n.resetButton));
        await tapAndSettle(
          tester,
          button<FilledButton>(l10n.resetConfirmButton),
        );
        final (who, password) = api.resets.single;
        expect(who.id, 's2');
        expect(password.length, 14);
        expect(find.text(password), findsOneWidget);
        expect(find.text(l10n.otpGive('Karim Hossain')), findsOneWidget);
        await tapAndSettle(tester, find.text(l10n.otpCopy));
        expect(copied, <String>[password]);
        await tapAndSettle(tester, button<FilledButton>(l10n.otpDone));
        expect(find.text(password), findsNothing);
        expect(find.text(l10n.statusMustChoose), findsOneWidget);
      });

      testWidgets('no one-time password without an email address', (
        tester,
      ) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        api.people[PersonKind.field]!.add(
          person(
            id: 'f2',
            name: 'Babul Mia',
            kind: PersonKind.field,
            role: fieldOfficerRole,
            phone: '+8801899999999',
          ),
        );
        final l10n = await openPeople(tester, api, lang: lang);
        await tapAndSettle(tester, find.text(l10n.kindField).first);
        await openPerson(tester, 'Babul Mia');
        expect(find.text(l10n.resetNeedsEmail), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(button<OutlinedButton>(l10n.resetButton))
              .onPressed,
          isNull,
        );
      });

      testWidgets('asks before leaving a form with changes', (tester) async {
        final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
        final l10n = await openPeople(tester, api, lang: lang);
        await tapAndSettle(tester, button<FilledButton>(l10n.peopleAdd));
        await typeInto(tester, 'person-name', 'Half Typed');
        await tapAndSettle(tester, button<TextButton>(l10n.peopleBack));
        expect(find.text(l10n.leaveTitle), findsOneWidget);
        expect(find.text(l10n.leavePersonBody), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.leaveStay));
        expect(find.byType(PersonEditor), findsOneWidget);
        await tapAndSettle(tester, button<TextButton>(l10n.peopleBack));
        await tapAndSettle(tester, button<FilledButton>(l10n.leaveDiscard));
        expect(find.byType(PersonEditor), findsNothing);
        expect(api.created, isEmpty);
      });

      testWidgets('works at 1024 and 600 px wide', (tester) async {
        for (final size in <Size>[
          const Size(1024, 700),
          const Size(600, 900),
        ]) {
          await tester.pumpWidget(const SizedBox());
          final api = peopleApi(FakeManagerApi(user: staff('org_admin')));
          final l10n = await openPeople(tester, api, lang: lang, size: size);
          expect(tester.takeException(), isNull, reason: '$size list');
          await openPerson(tester, 'Karim Hossain');
          expect(tester.takeException(), isNull, reason: '$size person');
          await tapAndSettle(tester, button<TextButton>(l10n.peopleBack));
          await tapAndSettle(tester, button<FilledButton>(l10n.peopleAdd));
          expect(tester.takeException(), isNull, reason: '$size add');
        }
      });
    });
  }
}
