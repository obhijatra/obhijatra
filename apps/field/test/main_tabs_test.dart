import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/screens/main_shell.dart';
import 'package:obhijatra_field/src/widgets/bottom_nav.dart';

import 'support/harness.dart';

Future<TestEnv> openShell(
  WidgetTester tester,
  String language,
  double scale, {
  MainTab tab = MainTab.today,
  bool online = true,
  bool withForm = true,
  void Function(TestEnv env)? setup,
}) async {
  final env = TestEnv(xform: withForm ? householdVisitXForm : null)
    ..startOnline = online;
  setup?.call(env);
  await tester.runAsync(() async {
    await env.seedSignedIn();
    if (withForm) await env.storeForm(householdVisitXForm);
  });
  await pumpScreen(
    tester,
    env,
    MainShell(initialTab: tab),
    language: language,
    textScale: scale,
  );
  return env;
}

void main() {
  group('Today', () {
    matrix('shows the date, counts, the form and no offline banner', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openShell(tester, language, scale);
      expect(find.text(l.todayTitle), findsWidgets);
      expect(await reveal(tester, find.text(l.statWaiting)), findsOneWidget);
      expect(await reveal(tester, find.text(l.statDrafts)), findsOneWidget);
      expect(find.textContaining(l.offlineTitle), findsNothing);
      expect(await reveal(tester, find.text('Household visit')), findsWidgets);
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });

    matrix('shows the full-width offline banner when there is no signal', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openShell(tester, language, scale, online: false);
      expect(find.textContaining(l.offlineTitle), findsOneWidget);
      expect(find.textContaining(l.offlineMessage), findsOneWidget);
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });

    matrix(
      'offline banner appears when signal drops and goes when it returns',
      (tester, language, scale, l) async {
        final env = await openShell(tester, language, scale);
        expect(find.textContaining(l.offlineTitle), findsNothing);
        env.online.add(false);
        await settleApp(tester);
        expect(find.textContaining(l.offlineTitle), findsOneWidget);
        env.online.add(true);
        await settleApp(tester);
        expect(find.textContaining(l.offlineTitle), findsNothing);
        await endTest(tester, env);
      },
    );

    matrix('asks to sign in again when the session has ended', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = TestEnv(xform: householdVisitXForm);
      await tester.runAsync(() async {
        await env.seedSignedIn();
        await env.storeForm(householdVisitXForm);
        await OutboxRepository(env.db).enqueue(
          const FinalisedInstance(
            form: FormVersionRef('household_visit', '2026110401'),
            instanceId: 'uuid:aaaaaaaa-0000-4000-8000-000000000002',
            xml: '<data id="household_visit" version="2026110401"><meta><instanceID>uuid:aaaaaaaa-0000-4000-8000-000000000002</instanceID></meta></data>',
            attachmentNames: <String>[],
          ),
        );
      });
      // The server forgets the sign-in, as when a session runs out.
      env.server.expireSessions();
      await pumpScreen(
        tester,
        env,
        const MainShell(),
        language: language,
        textScale: scale,
      );
      expect(
        await reveal(tester, find.text(l.signInAgainBanner)),
        findsOneWidget,
      );
      await endTest(tester, env);
    });

    matrix('says what to do when no forms are on the phone yet', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openShell(
        tester,
        language,
        scale,
        tab: MainTab.forms,
        withForm: false,
      );
      expect(
        await reveal(tester, find.text(l.formsEmptyTitle)),
        findsOneWidget,
      );
      await endTest(tester, env);
    });
  });

  group('Tabs', () {
    matrix('the bottom bar moves between the four places', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openShell(tester, language, scale);
      for (final label in <String>[
        l.navForms,
        l.navSending,
        l.navMore,
        l.navToday,
      ]) {
        await tester.tap(find.text(label).last);
        await settleApp(tester);
      }
      expect(find.text(l.todayTitle), findsWidgets);
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });

    matrix('Sending shows a waiting form and offline banner', (
      tester,
      language,
      scale,
      l,
    ) async {
      final env = await openShell(
        tester,
        language,
        scale,
        tab: MainTab.sending,
        online: false,
      );
      expect(find.textContaining(l.offlineTitle), findsOneWidget);
      await expectAccessibleTargets(tester);
      await endTest(tester, env);
    });
  });
}
