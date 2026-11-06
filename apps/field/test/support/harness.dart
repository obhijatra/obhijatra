// Shared helpers for the field app's widget tests: an in-memory encrypted-
// database stand-in, a fake server, fixed time, phone-sized screens, and
// the language and text-size matrix.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show QueryExecutor, driftRuntimeOptions;
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
import 'package:obhijatra_field/src/platform/device_authenticator.dart';
import 'package:obhijatra_field/src/platform/sign_in_browser.dart';
import 'package:obhijatra_field/src/providers/app_lock_provider.dart';
import 'package:obhijatra_field/src/providers/device_providers.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:sqlite3/sqlite3.dart';

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

/// PBKDF2 iterations for app PINs in tests.
const int testPinIterations = 1000;

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
      server = server ?? FakeObhijatraServer(xform: xform) {
    // Every app test runs against the server's device checks: a request
    // the app forgot to sign fails the test. A phone that enrols is
    // approved at once, unless a test plays the approver itself.
    this.server
      ..requireDevices = true
      ..approveDevicesAtOnce = true;
  }

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

  /// What "now" is for the app; tests move it forward.
  DateTime now = testNow;

  /// The app lock's protected values (the OS key store stand-in).
  final MemorySecureValues secureValues = MemorySecureValues();

  /// The phone's own screen lock.
  final FakeDeviceAuth deviceAuth = FakeDeviceAuth();

  /// The browser tab Google's sign-in page opens in.
  final FakeBrowser browser = FakeBrowser();

  /// The phone's device keys and enrolment (the OS key store stand-in).
  final MemoryDeviceKeyStore deviceStore = MemoryDeviceKeyStore();

  /// The overrides every test shares: the app lock is open from the start
  /// (lock tests use [lockedOverrides] instead) and the database is [db].
  late final List<Override> overrides = <Override>[
    deviceDatabaseProvider.overrideWith((ref) async => db),
    appLockProvider.overrideWith(_OpenLock.new),
    ..._common,
  ];

  /// The overrides for app-lock tests: the real app lock, and a database
  /// opened through [opener] only when the lock allows it.
  late final List<Override> lockedOverrides = <Override>[
    databaseOpenerProvider.overrideWith((ref) async => opener),
    keyStoreProvider.overrideWithValue(keys),
    // Fewer PBKDF2 iterations than on a phone, to keep tests quick.
    appLockStoreProvider.overrideWith((ref) => lockStore()),
    ..._common,
  ];

  /// The app lock's rules over [secureValues], as the app builds them but
  /// with [testPinIterations]; [at] fixes the time (default: [now]).
  AppLock lockStore({DateTime? at}) => AppLock(
    secureValues,
    now: () => at ?? now,
    pinIterations: testPinIterations,
  );

  /// The database "file" for [lockedOverrides].
  final SharedMemoryOpener opener = SharedMemoryOpener();

  /// The database key for [opener].
  final MemoryKeyStore keys = MemoryKeyStore();

  /// Writes what an earlier use of the app left in [opener]'s database,
  /// with its key.
  Future<void> seedDevice(Future<void> Function(DeviceDatabase db) body) async {
    if (await keys.readDatabaseKey() == null) await keys.createDatabaseKey();
    await opener.seed(body);
  }

  late final List<Override> _common = <Override>[
    secureValuesProvider.overrideWithValue(secureValues),
    deviceKeyStoreProvider.overrideWithValue(deviceStore),
    deviceAuthenticatorProvider.overrideWithValue(deviceAuth),
    pinComputeProvider.overrideWithValue(runHere),
    httpClientFactoryProvider.overrideWithValue(server.client),
    attachmentStoreProvider.overrideWith((ref) async => _NoAttachments()),
    nowProvider.overrideWithValue(() => now),
    syncAutoRetryProvider.overrideWithValue(false),
    onlineProvider.overrideWith((ref) async* {
      yield startOnline;
      yield* online.stream;
    }),
    signInBrowserProvider.overrideWithValue(browser),
    urlLauncherProvider.overrideWithValue((uri) async {
      opened.add(uri);
      return canOpenLinks;
    }),
  ];

  /// Opens the encrypted-database stand-in with the server address (and
  /// optionally a signed-in user) already saved, as after first use. With
  /// [into], that database is used instead of [db].
  ///
  /// A signed-in phone is enrolled too (in [deviceStore]); with
  /// [deviceApproved] it is approved, as the app last heard.
  Future<void> seedSignedIn({
    bool signedIn = true,
    DeviceDatabase? into,
    bool deviceApproved = true,
  }) async {
    final settings = SettingsRepository(into ?? db);
    await settings.write(
      serverUrlSettingKey0,
      FakeObhijatraServer.baseUrl.toString(),
    );
    if (signedIn) {
      // Sign in and enrol through a real client, so the saved session and
      // the phone's device are genuine. That happened earlier, with the
      // phone's clock right: a test may set the server's clock apart after.
      final offset = server.clockOffset;
      server.clockOffset = Duration.zero;
      final identity = await DeviceIdentity.open(deviceStore);
      final store = await settings.authStore();
      final client = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: appReleaseVersion,
        authStore: store,
        signer: identity,
        httpClientFactory: server.client,
      );
      await client.signIn(email: fakeEmail, password: fakePassword);
      final atOnce = server.approveDevicesAtOnce;
      server.approveDevicesAtOnce = deviceApproved;
      final status = await identity.ensureEnrolled(
        client,
        label: 'Field app, Android',
        platform: DevicePlatform.android,
      );
      server.approveDevicesAtOnce = atOnce;
      if (deviceApproved && status.state != DeviceState.active) {
        server.approveDevice(status.id, identity.checkCode!);
        await identity.refresh(client);
      }
      client.close();
      await identity.close();
      server.clockOffset = offset;
    }
  }

  /// This phone's device on the fake server, once enrolled.
  FakeDevice? get phoneDevice {
    final id = DeviceEnrolment.decode(deviceStore.enrolmentText)?.deviceId;
    return id == null ? null : server.devices[id];
  }

  /// Stores [xform] on the phone as a downloaded form.
  Future<void> storeForm(String xform) =>
      FormRepository(db).storeFormVersion(xformXml: xform);

  /// Saves the language the person chose (in the database, and in the
  /// protected store the lock screens read it from).
  Future<void> seedLanguage(String code) async {
    secureValues.values[languageSecureKey] = code;
    await SettingsRepository(db).write(languageSettingKey0, code);
  }

  Future<void> dispose() async {
    await online.close();
    await db.close();
    opener.dispose();
  }
}

class _NoAttachments implements AttachmentStore {
  @override
  Future<Uint8List> read(String path) =>
      throw const ObhijatraException(ProblemCode.attachmentMissing);

  @override
  Future<void> delete(String path) async {}
}

/// The app lock, open from the start (tests that are not about the lock).
class _OpenLock extends AppLockController {
  @override
  Future<AppLockState> build() async => const LockOpen();
}

/// The OS key store stand-in for the app lock's values.
class MemorySecureValues implements SecureValueStore {
  /// The stored values, by name.
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async => values[name] = value;

  @override
  Future<void> delete(String name) async => values.remove(name);
}

/// The phone's own screen lock, scripted by the test.
class FakeDeviceAuth implements DeviceAuthenticator {
  /// Whether the phone has a screen lock.
  bool screenLock = true;

  /// What the next prompts answer, in order; then [answer].
  final List<DeviceUnlockResult> answers = <DeviceUnlockResult>[];

  /// The answer once [answers] is used up.
  DeviceUnlockResult answer = DeviceUnlockResult.unlocked;

  /// How many times the prompt was shown.
  int prompts = 0;

  /// The words of the last prompt.
  DevicePromptText? lastText;

  @override
  Future<bool> hasScreenLock() async => screenLock;

  @override
  Future<DeviceUnlockResult> unlock(DevicePromptText text) async {
    prompts++;
    lastText = text;
    return answers.isNotEmpty ? answers.removeAt(0) : answer;
  }
}

/// The browser tab for Google sign-in, scripted by the test: it records
/// what the app opened; the test then plays the person's part with
/// `FakeObhijatraServer.finishGoogleSignIn`.
class FakeBrowser implements SignInBrowser {
  /// The addresses the app opened.
  final List<Uri> opened = <Uri>[];

  /// How many times the app closed the tab.
  int closes = 0;

  /// Whether the phone can open a browser.
  bool works = true;

  @override
  Future<void> open(Uri url) async {
    if (!works) throw const ObhijatraException(ProblemCode.browserUnavailable);
    opened.add(url);
  }

  @override
  Future<void> close() async => closes++;
}

/// A database key kept in memory.
class MemoryKeyStore implements KeyStore {
  String? _hex;

  @override
  Future<DatabaseKey?> readDatabaseKey() async =>
      _hex == null ? null : DatabaseKey.fromHex(_hex!);

  @override
  Future<DatabaseKey> createDatabaseKey() async {
    final key = DatabaseKey.generate();
    _hex = key.toHex();
    return key;
  }
}

/// One in-memory SQLite database that survives being closed and opened
/// again (as a file would), counting the opens.
class SharedMemoryOpener implements DeviceDatabaseOpener {
  final Database _raw = sqlite3.openInMemory();

  /// Whether the "file" exists.
  bool exists = false;

  /// How many times the database was opened.
  int opens = 0;

  @override
  Future<bool> databaseExists() async => exists;

  @override
  QueryExecutor open(DatabaseKey key) {
    opens++;
    exists = true;
    return NativeDatabase.opened(_raw, closeUnderlyingOnClose: false);
  }

  /// Writes what an earlier use of the app left in the database (not counted
  /// as an open by the app).
  Future<void> seed(Future<void> Function(DeviceDatabase db) body) async {
    final db = DeviceDatabase(
      NativeDatabase.opened(_raw, closeUnderlyingOnClose: false),
    );
    await body(db);
    await db.close();
    exists = true;
  }

  /// Releases the database.
  void dispose() => _raw.close();
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
  bool locked = false,
}) async {
  usePhone(tester, textScale: textScale);
  await tester.runAsync(() => env.seedLanguage(language));
  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: locked ? env.lockedOverrides : env.overrides,
      child: ObhijatraFieldApp(home: home),
    ),
  );
  if (settle) await settleApp(tester);
}

/// Shows the whole app, starting at the gate; with [locked], behind the
/// real app lock (see [TestEnv.lockedOverrides]).
Future<void> pumpApp(
  WidgetTester tester,
  TestEnv env, {
  String language = 'bn',
  double textScale = 1.0,
  bool locked = false,
}) => pumpScreen(
  tester,
  env,
  const AppGate(),
  language: language,
  textScale: textScale,
  locked: locked,
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
