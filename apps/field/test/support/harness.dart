// Shared helpers for the field app's widget tests: an in-memory encrypted-
// database stand-in, a fake server, fixed time, phone-sized screens, and
// the language and text-size matrix.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/l10n/app_localizations_bn.dart';
import 'package:obhijatra_field/l10n/app_localizations_en.dart';
import 'package:obhijatra_field/src/app.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';

/// The core's sample form (English and Bangla labels, select_one, integer
/// with a constraint, text, date, a skip rule and required questions).
final String householdVisitXForm = File(
  '../../packages/obhijatra_core/test/fixtures/household_visit.xml',
).readAsStringSync();

/// A form with one question of every kind the app shows, plus kinds it
/// cannot show yet, for the screen tests.
const String kitchenSinkXForm = '''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms">
  <h:head>
    <h:title>Kitchen sink</h:title>
    <model odk:xforms-version="1.0.0">
      <instance>
        <data id="kitchen_sink" version="1">
          <welcome/><water/><tools/><age/><weight/><visit/><when/><name/><picture/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/welcome" type="string" readonly="true()"/>
      <bind nodeset="/data/water" type="string" required="true()"/>
      <bind nodeset="/data/tools" type="string"/>
      <bind nodeset="/data/age" type="int"/>
      <bind nodeset="/data/weight" type="decimal"/>
      <bind nodeset="/data/visit" type="date"/>
      <bind nodeset="/data/when" type="time"/>
      <bind nodeset="/data/name" type="string"/>
      <bind nodeset="/data/picture" type="binary" required="true()"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/welcome"><label>Welcome to the visit.</label></input>
    <select1 ref="/data/water"><label>Where does the drinking water come from?</label>
      <item><label>Tube well</label><value>tubewell</value></item>
      <item><label>Pond or river</label><value>pond</value></item>
    </select1>
    <select ref="/data/tools"><label>Which tools does the household own?</label>
      <item><label>Plough</label><value>plough</value></item>
      <item><label>Sickle</label><value>sickle</value></item>
      <item><label>Pump</label><value>pump</value></item>
    </select>
    <input ref="/data/age"><label>Age of the oldest person</label></input>
    <input ref="/data/weight"><label>Weight in kilograms</label></input>
    <input ref="/data/visit"><label>Date of visit</label></input>
    <input ref="/data/when"><label>Time of visit</label></input>
    <input ref="/data/name"><label>Name of the household head</label></input>
    <upload ref="/data/picture" mediatype="image/*"><label>Photo of the house</label></upload>
  </h:body>
</h:html>''';

/// The moment "now" is in tests: Wednesday 4 November 2026, 10:30.
final DateTime testNow = DateTime(2026, 11, 4, 10, 30);

/// The languages tests run in.
const List<String> testLanguages = <String>['bn', 'en'];

/// The text sizes tests run at.
const List<double> testScales = <double>[1.0, 2.0];

/// Everything a screen test needs.
///
/// Every test makes its own in-memory database, so drift's "two databases"
/// warning does not apply.
class TestEnv {
  TestEnv({String? xform, FakeObhijatraServer? server})
    : db = _newDatabase(),
      server = server ?? FakeObhijatraServer(xform: xform);

  static DeviceDatabase _newDatabase() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return DeviceDatabase(NativeDatabase.memory());
  }

  final DeviceDatabase db;
  final FakeObhijatraServer server;

  /// A controllable connectivity stream.
  final StreamController<bool> online = StreamController<bool>.broadcast();
  bool startOnline = true;

  /// Addresses the app tried to open outside itself.
  final List<Uri> opened = <Uri>[];

  /// Whether opening a link works.
  bool canOpenLinks = true;

  late final List<Override> overrides = <Override>[
    deviceDatabaseProvider.overrideWith((ref) async => db),
    httpClientFactoryProvider.overrideWithValue(server.client),
    attachmentStoreProvider.overrideWith((ref) async => _NoAttachments()),
    nowProvider.overrideWithValue(() => testNow),
    syncAutoRetryProvider.overrideWithValue(false),
    onlineProvider.overrideWith((ref) async* {
      yield startOnline;
      yield* online.stream;
    }),
    urlLauncherProvider.overrideWithValue((uri) async {
      opened.add(uri);
      return canOpenLinks;
    }),
  ];

  /// Opens the encrypted-database stand-in with the server address (and
  /// optionally a signed-in user) already saved, as after first use.
  Future<void> seedSignedIn({bool signedIn = true}) async {
    final settings = SettingsRepository(db);
    await settings.write(
      serverUrlSettingKey0,
      FakeObhijatraServer.baseUrl.toString(),
    );
    if (signedIn) {
      // Sign in through a real client so the saved session is genuine.
      final store = await settings.authStore();
      final client = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: appReleaseVersion,
        authStore: store,
        httpClientFactory: server.client,
      );
      await client.signIn(email: fakeEmail, password: fakePassword);
      client.close();
    }
  }

  /// Stores [xform] on the phone as a downloaded form.
  Future<void> storeForm(String xform) =>
      FormRepository(db).storeFormVersion(xformXml: xform);

  /// Saves the language the person chose.
  Future<void> seedLanguage(String code) =>
      SettingsRepository(db).write(languageSettingKey0, code);

  Future<void> dispose() async {
    await online.close();
    await db.close();
  }
}

class _NoAttachments implements AttachmentStore {
  @override
  Future<Uint8List> read(String path) =>
      throw const ObhijatraException(ProblemCode.attachmentMissing);
}

/// The settings keys, re-exported so tests do not repeat the strings.
const String serverUrlSettingKey0 = serverUrlSettingKey;

/// See [serverUrlSettingKey0].
const String languageSettingKey0 = languageSettingKey;

/// Makes the test screen phone-sized (360 x 800 logical pixels).
void usePhone(WidgetTester tester, {double textScale = 1.0}) {
  tester.view
    ..physicalSize = const Size(360 * 3, 800 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Shows [home] in the real app (theme, languages, providers) in [language].
Future<void> pumpScreen(
  WidgetTester tester,
  TestEnv env,
  Widget home, {
  String language = 'bn',
  double textScale = 1.0,
  bool settle = true,
}) async {
  usePhone(tester, textScale: textScale);
  await tester.runAsync(() => env.seedLanguage(language));
  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: env.overrides,
      child: ObhijatraFieldApp(home: home),
    ),
  );
  if (settle) await settleApp(tester);
}

/// Shows the whole app, starting at the gate.
Future<void> pumpApp(
  WidgetTester tester,
  TestEnv env, {
  String language = 'bn',
  double textScale = 1.0,
}) => pumpScreen(
  tester,
  env,
  const AppGate(),
  language: language,
  textScale: textScale,
);

/// Lets providers, streams and animations finish.
Future<void> settleApp(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

/// Takes the app down so no timers or streams outlive the test.
Future<void> endTest(WidgetTester tester, TestEnv env) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(env.dispose);
}

/// Reads a provider-backed value after [tester] pumped the app.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ObhijatraFieldApp)));

/// The sync engine's status right now.
Future<SyncStatus> currentSyncStatus(WidgetTester tester) async {
  final engine = await containerOf(tester).read(syncEngineProvider.future);
  return engine!.status;
}

/// A form whose first question appears only after the second is answered
/// "yes", so it can be reached at the end with an answer missing (the finish
/// screen's safety net).
const String lateRelevanceXForm = '''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms">
  <h:head>
    <h:title>Late question</h:title>
    <model odk:xforms-version="1.0.0">
      <instance>
        <data id="late_question" version="1">
          <extra/><gate/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/extra" type="int" required="true()" relevant="/data/gate = 'yes'"/>
      <bind nodeset="/data/gate" type="string" required="true()"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/extra"><label>How many goats?</label></input>
    <select1 ref="/data/gate"><label>Does the household keep animals?</label>
      <item><label>Yes</label><value>yes</value></item>
      <item><label>No</label><value>no</value></item>
    </select1>
  </h:body>
</h:html>''';

/// The generated words for [language].
AppLocalizations wordsFor(String language) =>
    language == 'bn' ? AppLocalizationsBn() : AppLocalizationsEn();

/// Runs [body] once for each language and text size, as separate tests.
void matrix(
  String name,
  Future<void> Function(
    WidgetTester tester,
    String language,
    double scale,
    AppLocalizations l,
  )
  body, {
  List<double> scales = testScales,
  List<String> languages = testLanguages,
}) {
  for (final language in languages) {
    for (final scale in scales) {
      testWidgets('$name [$language, text x$scale]', (tester) async {
        await body(tester, language, scale, wordsFor(language));
      });
    }
  }
}

/// Fails if a tappable thing is smaller than 48 x 48 dp or has no label.
Future<void> expectAccessibleTargets(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
}

/// Scrolls the screen's list until [finder] is built and fully inside the
/// visible list (long screens build their rows lazily and a bar at the bottom
/// can cover the last rows), then returns it. Looks downwards, then upwards.
Future<Finder> reveal(WidgetTester tester, Finder finder) async {
  Future<bool> bringIn() async {
    if (finder.evaluate().isEmpty) return false;
    await tester.ensureVisible(finder.first);
    await tester.pump();
    return true;
  }

  if (await bringIn()) return finder;
  final scrollable = find.byType(Scrollable).first;
  for (final step in <double>[150, -150]) {
    try {
      await tester.scrollUntilVisible(
        finder,
        step,
        scrollable: scrollable,
        maxScrolls: 60,
      );
      await bringIn();
      return finder;
    } on StateError {
      // Not in this direction; try the other.
    }
  }
  return finder;
}
