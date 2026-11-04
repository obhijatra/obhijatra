// Phase 1 gate: a submission queued on the phone syncs to the real
// obhijatra-server, and one queued before a server restart (an upgrade on
// the same data) syncs afterwards.
//
// Runs the server binary from server/dist (or OBHIJATRA_SERVER_BIN).
// Run only this test with:  dart test -t e2e
@Tags(['e2e'])
@TestOn('vm')
@Timeout(Duration(minutes: 4))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

import '../support/test_support.dart';

const _superuserPassword = 'e2e-superuser-password-1';
const _adminEmail = 'admin@example.org';
const _adminPassword = 'e2e-admin-password-1';
const _fieldEmail = 'field.officer@example.org';
const _fieldPassword = 'e2e-field-password-1';

void main() {
  late Directory work;
  late _Server server;

  setUpAll(() async {
    work = await Directory.systemTemp.createTemp('obhijatra_e2e_');
    server = _Server(_serverBinary(), work, await _Server.freePort());
    await server.init();
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
    await work.delete(recursive: true);
  });

  test('queued submissions sync, also across a server restart', () async {
    // ---- The organisation admin sets up a branch, a field user and the
    // ---- sample form through the server's ordinary API.
    final admin = await _Admin.signIn(server.baseUrl);
    addTearDown(admin.close);
    final root = (await admin.list('locations')).single;
    final branch = await admin.create('locations', {
      'name': 'Test branch',
      'parent': root['id'],
    });
    final fieldUser = await admin.create('field_users', {
      'email': _fieldEmail,
      'password': _fieldPassword,
      'passwordConfirm': _fieldPassword,
      'name': 'Field Officer',
      'role': 'field_officer',
      'location': branch['id'],
      'active': true,
    });
    final form = await admin.create('forms', {
      'form_id': sampleFormId,
      'title': 'Household visit',
    });
    await admin.publishFormVersion(
      formRecordId: form['id']! as String,
      version: sampleFormVersion,
      xform: householdVisitXForm,
    );

    // ---- First life of the app.
    final keys = MemoryKeyStore();
    final dbFile = File('${work.path}/device/device.sqlite');
    await dbFile.parent.create();
    var phone = await _Phone.open(server.baseUrl, keys, dbFile);

    final meta = await phone.server.fetchMeta();
    expect(meta.syncBlocker('0.1.0'), isNull);
    // The real server dates its answers, so the clock check has data.
    expect(meta.serverTime, isNotNull);
    expect(meta.clockSkewed(DateTime.now()), isFalse);
    await phone.signIn();
    final refresh = await phone.forms.refreshFromServer(phone.server);
    expect(refresh.added.single.version, sampleFormVersion);
    expect(refresh.failed, isEmpty);

    // Fill the form headlessly from the cached copy, as offline work does.
    final first = await phone.fill(head: 'Rahima Begum', size: '5');
    expect((await phone.outbox.find(first))!.state, OutboxState.queued);
    final report = await phone.sync.syncNow();
    expect(report.sent, 1, reason: 'report: ${report.stoppedBy}');
    expect((await phone.outbox.find(first))!.state, OutboxState.sent);

    // The submission is on the server, byte for byte, attributed to the
    // field user and placed in their branch.
    final stored = await admin.submission(first);
    expect(stored['submitted_by'], fieldUser['id']);
    expect(stored['location_path'], branch['path']);
    expect(stored['review_state'], 'Received');
    expect(
      await admin.submissionXml(stored),
      (await phone.outbox.find(first))!.instanceXml,
    );

    // A retry of the same bytes is acknowledged, never duplicated.
    final retry = await phone.server.submit(
      instanceXml: (await phone.outbox.find(first))!.instanceXml,
    );
    expect(retry.status, ReceiptStatus.alreadyReceived);

    // ---- The server goes down for an upgrade; the field officer keeps
    // ---- working and a second submission is queued.
    await server.stop();
    final second = await phone.fill(head: 'Karim Mia', size: '3');
    final offline = await phone.sync.syncNow();
    expect(offline.stoppedBy, ProblemCode.offline);
    expect(phone.sync.status.isOffline, isTrue);
    expect(phone.sync.status.queued, 1);
    expect((await phone.outbox.find(second))!.state, OutboxState.queued);

    // The app is closed.
    await phone.close();

    // ---- The upgraded server starts on the same data.
    await server.start();

    // ---- Second life of the app: same encrypted database, saved session.
    phone = await _Phone.open(server.baseUrl, keys, dbFile);
    addTearDown(phone.close);
    expect(phone.server.hasValidSession, isTrue);
    expect(keys.created, 1);

    final after = await phone.sync.syncNow();
    expect(after.sent, 1, reason: 'report: ${after.stoppedBy}');
    expect((await phone.outbox.find(second))!.state, OutboxState.sent);
    expect((await admin.submission(second))['submitted_by'], fieldUser['id']);
    expect(await admin.count('submissions'), 2);

    await pumpEventQueue();
    final status = phone.sync.status;
    expect(status.queued, 0);
    expect(status.problems, 0);
    expect(status.isOffline, isFalse);
    expect(status.lastSyncedAt, isNotNull);
  });
}

/// The phone: encrypted database, server client, repositories and engine.
final class _Phone {
  _Phone._(this.db, this.server)
    : forms = FormRepository(db),
      drafts = DraftRepository(db),
      outbox = OutboxRepository(db),
      sync = SyncEngine(database: db, server: server, autoRetry: false);

  static Future<_Phone> open(Uri baseUrl, KeyStore keys, File file) async {
    final db = await openDeviceDatabase(
      keyStore: keys,
      opener: FileDatabaseOpener(file),
    );
    final server = ObhijatraServer(
      baseUrl: baseUrl,
      appVersion: obhijatraCoreVersion,
      authStore: await SettingsRepository(db).authStore(),
      timeout: const Duration(seconds: 10),
    );
    final phone = _Phone._(db, server);
    await phone.sync.start();
    return phone;
  }

  final DeviceDatabase db;
  final ObhijatraServer server;
  final FormRepository forms;
  final DraftRepository drafts;
  final OutboxRepository outbox;
  final SyncEngine sync;

  /// Signs in, waiting out the server's login rate limit if needed.
  Future<void> signIn() async {
    for (var attempt = 1; ; attempt++) {
      try {
        await server.signIn(email: _fieldEmail, password: _fieldPassword);
        return;
      } on ObhijatraException catch (e) {
        if (e.code != ProblemCode.serverBusy || attempt == 3) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 3500));
      }
    }
  }

  /// Fills the cached sample form, saving the draft after every screen,
  /// and queues it. Returns the instance id.
  Future<String> fill({required String head, required String size}) async {
    final version = (await forms.latestVersion(sampleFormId))!;
    final session = await FormEntrySession.start(xformXml: version.xformXml);
    try {
      Future<void> step(String label, String value) async {
        expect(answerByLabel(session, label, value), isNull, reason: label);
        expect(session.next(), isA<Moved>(), reason: label);
        await drafts.save(session);
      }

      await step('Date of visit', '2026-11-03');
      await step('What happened', 'met');
      await step('Name of the household head', head);
      await step('How many people', size);
      await step('How many of them', '1');
      expect(session.screen, isA<QuestionScreen>()); // notes, optional
      session.next();
      expect(session.screen, isA<EndOfFormScreen>());
      final result = session.finalise() as Finalised;
      expect(await drafts.find(session.instanceId), isNotNull);
      await outbox.enqueue(result.instance);
      expect(await drafts.find(session.instanceId), isNull);
      return result.instance.instanceId;
    } finally {
      await session.close();
    }
  }

  Future<void> close() async {
    await sync.dispose();
    server.close();
    await db.close();
  }
}

/// The real server process.
final class _Server {
  _Server(this.binary, this.work, this.port);

  final String binary;
  final Directory work;
  final int port;
  Process? _process;
  final StringBuffer _output = StringBuffer();

  Uri get baseUrl => Uri.parse('http://127.0.0.1:$port');

  String get _dataDir => '${work.path}/pb_data';

  /// The environment without any OBHIJATRA_ variable of the caller.
  Map<String, String> _environment([Map<String, String> extra = const {}]) => {
    for (final e in Platform.environment.entries)
      if (!e.key.startsWith('OBHIJATRA_')) e.key: e.value,
    ...extra,
  };

  Future<void> init() async {
    final result = await Process.run(
      binary,
      [
        'init',
        '--dir',
        _dataDir,
        '--non-interactive',
        '--org-name',
        'Obhijatra E2E Test Organisation',
        '--country',
        'BD',
        '--url',
        baseUrl.toString(),
        '--superuser-email',
        'root@example.org',
        '--admin-name',
        'Test Admin',
        '--admin-email',
        _adminEmail,
      ],
      environment: _environment({
        'OBHIJATRA_INIT_SUPERUSER_PASSWORD': _superuserPassword,
        'OBHIJATRA_INIT_ADMIN_PASSWORD': _adminPassword,
      }),
      includeParentEnvironment: false,
    );
    if (result.exitCode != 0) {
      fail(
        'init failed (${result.exitCode}):\n${result.stdout}\n${result.stderr}',
      );
    }
  }

  Future<void> start() async {
    final process = await Process.start(
      binary,
      ['serve', '--dir', _dataDir, '--http', '127.0.0.1:$port'],
      environment: _environment(),
      includeParentEnvironment: false,
    );
    _process = process;
    process.stdout.transform(utf8.decoder).listen(_output.write);
    process.stderr.transform(utf8.decoder).listen(_output.write);

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    final client = http.Client();
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final response = await client
              .get(baseUrl.resolve('/api/health'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) return;
        } on Object {
          // Not listening yet.
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      client.close();
    }
    fail('The server did not start within 30 seconds:\n$_output');
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    _process = null;
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return process.exitCode;
      },
    );
  }

  /// A port the operating system reports free right now.
  static Future<int> freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }
}

/// The organisation admin, using the PocketBase record API directly.
final class _Admin {
  _Admin._(this.base, this.token, this.client);

  static Future<_Admin> signIn(Uri base) async {
    final client = http.Client();
    final response = await client.post(
      base.resolve('/api/collections/staff_users/auth-with-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identity': _adminEmail, 'password': _adminPassword}),
    );
    expect(response.statusCode, 200, reason: response.body);
    final json = jsonDecode(response.body) as Map<String, Object?>;
    return _Admin._(base, json['token']! as String, client);
  }

  final Uri base;
  final String token;
  final http.Client client;

  Map<String, String> get _auth => {'Authorization': token};

  Future<Map<String, Object?>> create(
    String collection,
    Map<String, Object?> body,
  ) async {
    final response = await client.post(
      base.resolve('/api/collections/$collection/records'),
      headers: {..._auth, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    expect(response.statusCode, 200, reason: '$collection: ${response.body}');
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  Future<List<Map<String, Object?>>> list(
    String collection, {
    String? filter,
  }) async {
    final url = base
        .resolve('/api/collections/$collection/records')
        .replace(queryParameters: {'filter': ?filter, 'perPage': '200'});
    final response = await client.get(url, headers: _auth);
    expect(response.statusCode, 200, reason: response.body);
    final json = jsonDecode(response.body) as Map<String, Object?>;
    return (json['items']! as List<Object?>).cast<Map<String, Object?>>();
  }

  Future<int> count(String collection) async => (await list(collection)).length;

  Future<Map<String, Object?>> submission(String instanceId) async =>
      (await list('submissions', filter: "instance_id = '$instanceId'")).single;

  Future<String> submissionXml(Map<String, Object?> record) async {
    final tokenResponse = await client.post(
      base.resolve('/api/files/token'),
      headers: _auth,
    );
    expect(tokenResponse.statusCode, 200, reason: tokenResponse.body);
    final fileToken =
        (jsonDecode(tokenResponse.body) as Map<String, Object?>)['token']!
            as String;
    final url = base
        .resolve('/api/files/submissions/${record['id']}/${record['xml']}')
        .replace(queryParameters: {'token': fileToken});
    final response = await client.get(url);
    expect(response.statusCode, 200, reason: response.body);
    return utf8.decode(response.bodyBytes);
  }

  Future<void> publishFormVersion({
    required String formRecordId,
    required String version,
    required String xform,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            base.resolve('/api/collections/form_versions/records'),
          )
          ..headers.addAll(_auth)
          ..fields.addAll({
            'form': formRecordId,
            'version': version,
            'published': 'true',
          })
          ..files.add(
            http.MultipartFile.fromString(
              'xform',
              xform,
              filename: '$sampleFormId.xml',
            ),
          );
    final response = await http.Response.fromStream(await client.send(request));
    expect(response.statusCode, 200, reason: response.body);
  }

  void close() => client.close();
}

/// The server binary for this machine, from server/dist, or the path in
/// OBHIJATRA_SERVER_BIN.
String _serverBinary() {
  final override = Platform.environment['OBHIJATRA_SERVER_BIN'];
  if (override != null && override.isNotEmpty) return override;
  final suffix = switch (Abi.current()) {
    Abi.linuxX64 => 'linux_amd64',
    Abi.linuxArm64 => 'linux_arm64',
    Abi.macosArm64 => 'darwin_arm64',
    Abi.windowsX64 => 'windows_amd64.exe',
    final abi => throw UnsupportedError('No server build for $abi'),
  };
  final dist = Directory('../../server/dist');
  final matches = dist.existsSync()
      ? dist
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_$suffix'))
            .toList()
      : <File>[];
  if (matches.isEmpty) {
    fail(
      'No obhijatra-server build for $suffix in ${dist.absolute.path}. '
      'Build it (server/scripts/build-all.sh) or set OBHIJATRA_SERVER_BIN.',
    );
  }
  matches.sort((a, b) => a.path.compareTo(b.path));
  return matches.last.absolute.path;
}
