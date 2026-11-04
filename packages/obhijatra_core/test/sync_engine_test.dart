import 'dart:async';
import 'dart:math';

import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

import 'support/fake_server.dart';
import 'support/test_support.dart';

void main() {
  late FakeObhijatraServer fake;
  late DeviceDatabase db;
  late OutboxRepository outbox;
  late ObhijatraServer server;
  final engines = <SyncEngine>[];

  SyncEngine engine({
    Backoff backoff = const Backoff(),
    bool autoRetry = false,
    ObhijatraServer? using,
  }) {
    final e = SyncEngine(
      database: db,
      server: using ?? server,
      attachments: MemoryAttachments(),
      backoff: backoff,
      random: Random(42),
      autoRetry: autoRetry,
    );
    engines.add(e);
    return e;
  }

  Future<String> queueOne() async =>
      (await outbox.enqueue(await fillHouseholdVisit())).instanceId;

  setUp(() async {
    fake = FakeObhijatraServer(xform: householdVisitXForm);
    db = memoryDatabase();
    outbox = OutboxRepository(db);
    server = ObhijatraServer(
      baseUrl: FakeObhijatraServer.baseUrl,
      appVersion: '0.1.0',
      authStore: await SettingsRepository(db).authStore(),
      httpClientFactory: fake.client,
    );
    await server.signIn(email: 'field1@example.org', password: fakePassword);
  });

  tearDown(() async {
    for (final e in engines) {
      await e.dispose();
    }
    engines.clear();
    server.close();
    await db.close();
  });

  test('drains the outbox oldest first and records the sync', () async {
    final a = await queueOne();
    final b = await queueOne();
    final sync = engine();
    await sync.start();

    final report = await sync.syncNow();
    expect(report.sent, 2);
    expect(report.stoppedBy, isNull);
    expect(fake.submissions.keys, [a, b]);
    for (final id in [a, b]) {
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.sent);
      expect(entry.serverId, fake.submissions[id]!.id);
    }
    await pumpEventQueue();
    expect(sync.status.queued, 0);
    expect(sync.status.isSending, isFalse);
    expect(sync.status.isOffline, isFalse);
    expect(sync.status.lastSyncedAt, isNotNull);
    expect(await SettingsRepository(db).lastSyncedAt(), isNotNull);
    // Sent entries are kept on the device.
    expect(await outbox.entries(), hasLength(2));
  });

  test('offline: nothing changes and the status says so', () async {
    final id = await queueOne();
    fake.metaGlitches.add(const NoConnection());
    final sync = engine();
    await sync.start();

    final report = await sync.syncNow();
    expect(report.stoppedBy, ProblemCode.offline);
    expect(sync.status.isOffline, isTrue);
    expect(sync.status.queued, 1);
    final entry = (await outbox.find(id))!;
    expect(entry.state, OutboxState.queued);
    expect(entry.attempts, 0);

    // Back online.
    expect((await sync.syncNow()).sent, 1);
    expect(sync.status.isOffline, isFalse);
  });

  test('a connection lost mid-upload backs off with jitter', () async {
    final a = await queueOne();
    final b = await queueOne();
    fake.submissionGlitches.add(const NoConnection());
    final sync = engine(backoff: const Backoff(base: Duration(seconds: 20)));
    await sync.start();

    final before = DateTime.now().toUtc();
    final report = await sync.syncNow();
    expect(report.stoppedBy, ProblemCode.offline);
    expect(report.retrying, 1);
    final entry = (await outbox.find(a))!;
    expect(entry.state, OutboxState.queued);
    expect(entry.attempts, 1);
    expect(entry.lastError, 'offline');
    final wait = entry.nextAttemptAt!.difference(before);
    expect(wait.inSeconds, inInclusiveRange(9, 21));
    // The run stopped: the second entry was not tried.
    expect((await outbox.find(b))!.attempts, 0);
    expect(sync.status.isOffline, isTrue);

    // Not due yet; "Sync now" ignores the backoff.
    expect((await sync.syncNow()).sent, 1); // only b
    expect((await outbox.find(a))!.state, OutboxState.queued);
    expect((await sync.syncNow(ignoreBackoff: true)).sent, 1);
    expect((await outbox.find(a))!.state, OutboxState.sent);
  });

  test('a server error retries; the attempt count grows the wait', () async {
    final id = await queueOne();
    const backoff = Backoff(base: Duration(seconds: 10));
    final sync = engine(backoff: backoff);
    await sync.start();
    fake.submissionGlitches.addAll(const [ErrorStatus(500), ErrorStatus(503)]);

    await sync.syncNow(ignoreBackoff: true);
    final first = (await outbox.find(id))!;
    await sync.syncNow(ignoreBackoff: true);
    final second = (await outbox.find(id))!;
    expect(second.attempts, 2);
    expect(second.lastError, 'serverError');
    expect(
      second.nextAttemptAt!.difference(second.updatedAt).inSeconds,
      inInclusiveRange(10, 20),
    );
    expect(
      first.nextAttemptAt!.difference(first.updatedAt).inSeconds,
      inInclusiveRange(5, 10),
    );
    await sync.syncNow(ignoreBackoff: true);
    expect((await outbox.find(id))!.state, OutboxState.sent);
  });

  test(
    '409 becomes a problem with a plain-language code; the run goes on',
    () async {
      final clash = await fillHouseholdVisit();
      // Another copy with this instance ID, different content, is already on
      // the server.
      fake.submissions[clash.instanceId] = StoredSubmission(
        'other0000000000',
        clash.xml.replaceFirst('Rahima', 'Rokeya'),
        'fielduser1abcde',
        const [],
      );
      await outbox.enqueue(clash);
      final next = await queueOne();
      final sync = engine();
      await sync.start();

      final report = await sync.syncNow();
      expect(report.problems, 1);
      expect(report.sent, 1);
      final entry = (await outbox.find(clash.instanceId))!;
      expect(entry.state, OutboxState.problem);
      expect(
        ProblemCode.fromName(entry.lastError),
        ProblemCode.duplicateInstance,
      );
      expect(entry.lastErrorMessage, contains('was not replaced'));
      expect(entry.instanceXml, clash.xml); // kept, never deleted
      expect((await outbox.find(next))!.state, OutboxState.sent);
      await pumpEventQueue();
      expect(sync.status.problems, 1);
    },
  );

  test('an unpublished form version is a problem a person can retry', () async {
    final instance = await fillHouseholdVisit();
    final other = FakeObhijatraServer();
    final unpublished = ObhijatraServer(
      baseUrl: FakeObhijatraServer.baseUrl,
      appVersion: '0.1.0',
      httpClientFactory: other.client,
    );
    addTearDown(unpublished.close);
    await unpublished.signIn(
      email: 'field1@example.org',
      password: fakePassword,
    );
    await outbox.enqueue(instance);
    final sync = engine(using: unpublished);
    await sync.start();

    await sync.syncNow();
    expect(
      (await outbox.find(instance.instanceId))!.lastError,
      'formNotOnServer',
    );
    other.publish(householdVisitXForm);
    expect(await outbox.retry(instance.instanceId), isTrue);
    expect((await sync.syncNow()).sent, 1);
  });

  test(
    'an app older than min_client_version keeps its data and stops',
    () async {
      final id = await queueOne();
      fake.meta = {...fake.meta, 'min_client_version': '0.2.0'};
      final sync = engine();
      await sync.start();

      final report = await sync.syncNow();
      expect(report.stoppedBy, ProblemCode.appUpdateRequired);
      expect(sync.status.blockedBy, ProblemCode.appUpdateRequired);
      expect(fake.submissions, isEmpty);
      expect(fake.log.where((l) => l.contains('submissions')), isEmpty);
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(entry.instanceXml, isNotEmpty);
    },
  );

  test('a rejected session stops the run without counting the try', () async {
    final id = await queueOne();
    fake.submissionGlitches.add(const ErrorStatus(401));
    final sync = engine();
    await sync.start();

    final report = await sync.syncNow();
    expect(report.stoppedBy, ProblemCode.signInRequired);
    expect(sync.status.blockedBy, ProblemCode.signInRequired);
    final entry = (await outbox.find(id))!;
    expect(entry.state, OutboxState.queued);
    expect(entry.attempts, 0);

    // Signing out locally is noticed before any upload.
    server.signOut();
    expect((await sync.syncNow()).stoppedBy, ProblemCode.signInRequired);
  });

  test('submissions are never sent under another user\'s account', () async {
    final id = await queueOne();
    fake.metaGlitches.add(const NoConnection());
    final sync = engine();
    await sync.start();
    await sync.syncNow(); // offline: nothing decided yet
    expect((await outbox.find(id))!.state, OutboxState.queued);

    // field1 syncs once, which makes this database theirs.
    expect((await sync.syncNow()).sent, 1);
    final next = await queueOne();

    // Another officer signs in on the same phone.
    fake.users['field2@example.org'] = 'fielduser2abcde';
    await server.signIn(email: 'field2@example.org', password: fakePassword);
    final report = await sync.syncNow();
    expect(report.stoppedBy, ProblemCode.differentUser);
    expect(sync.status.blockedBy, ProblemCode.differentUser);
    expect((await outbox.find(next))!.state, OutboxState.queued);
    expect(fake.submissions, hasLength(1));

    // Back as field1, the queue drains; then field2 may take over.
    await server.signIn(email: 'field1@example.org', password: fakePassword);
    expect((await sync.syncNow()).sent, 1);
    await server.signIn(email: 'field2@example.org', password: fakePassword);
    expect((await sync.syncNow()).stoppedBy, isNull);
    expect(
      await SettingsRepository(db).read(SettingsRepository.ownerKey),
      'fielduser2abcde',
    );
  });

  test(
    'an app killed mid-send re-sends on restart; the server keeps one copy',
    () async {
      final stored = await queueOne();
      final notStored = await queueOne();
      // First life: the upload of `stored` reached the server but the app
      // died before recording the answer; `notStored` was claimed and the
      // app died before the request left the phone.
      expect(await outbox.markSending(stored), isTrue);
      await server.submit(
        instanceXml: (await outbox.find(stored))!.instanceXml,
      );
      expect(await outbox.markSending(notStored), isTrue);

      // Second life.
      final sync = engine();
      await sync.start();
      await pumpEventQueue();
      expect(sync.status.queued, 2);
      final report = await sync.syncNow();
      expect(report.sent, 2);
      expect(fake.submissions, hasLength(2));
      expect((await outbox.find(stored))!.state, OutboxState.sent);
      expect((await outbox.find(notStored))!.state, OutboxState.sent);
    },
  );

  test(
    'a lost response is retried and acknowledged as already received',
    () async {
      final id = await queueOne();
      fake.submissionGlitches.add(const LostResponse());
      final sync = engine();
      await sync.start();

      expect((await sync.syncNow()).stoppedBy, ProblemCode.offline);
      expect(fake.submissions, hasLength(1)); // the server did store it
      expect((await outbox.find(id))!.state, OutboxState.queued);

      expect((await sync.syncNow(ignoreBackoff: true)).sent, 1);
      expect((await outbox.find(id))!.state, OutboxState.sent);
      expect(fake.submissions, hasLength(1));
    },
  );

  test('a missing photo is a problem; the submission is kept', () async {
    final instance = await fillHouseholdVisit();
    await outbox.enqueue(instance, attachmentPaths: ['/media/gone.jpg']);
    final sync = engine();
    await sync.start();

    final report = await sync.syncNow();
    expect(report.problems, 1);
    final entry = (await outbox.find(instance.instanceId))!;
    expect(entry.state, OutboxState.problem);
    expect(entry.lastError, 'attachmentMissing');
    expect(fake.submissions, isEmpty);
  });

  test('overlapping calls share one run', () async {
    await queueOne();
    final sync = engine();
    await sync.start();
    final runs = await Future.wait([sync.syncNow(), sync.syncNow()]);
    expect(identical(runs[0], runs[1]), isTrue);
    expect(fake.log.where((l) => l.endsWith('/submissions')), hasLength(1));
  });

  test('the status stream reports sending and the queue', () async {
    final sync = engine();
    await sync.start();
    final seen = <SyncStatus>[];
    final subscription = sync.watchStatus().listen(seen.add);
    addTearDown(subscription.cancel);

    await queueOne();
    await pumpEventQueue();
    expect(seen.last.queued, 1);
    await sync.syncNow();
    await pumpEventQueue();
    expect(seen.any((s) => s.isSending), isTrue);
    expect(seen.last.isSending, isFalse);
    expect(seen.last.queued, 0);
    expect(seen.last.lastSyncedAt, isNotNull);
  });

  test('retries by itself after the backoff when auto-retry is on', () async {
    final id = await queueOne();
    fake.submissionGlitches.add(const ErrorStatus(502));
    final sync = engine(
      backoff: const Backoff(
        base: Duration(milliseconds: 40),
        max: Duration(milliseconds: 80),
      ),
      autoRetry: true,
    );
    await sync.start();
    await sync.syncNow();
    expect((await outbox.find(id))!.state, OutboxState.queued);
    expect(sync.status.nextAttemptAt, isNotNull);

    final sent = sync.watchStatus().firstWhere(
      (s) => s.queued == 0 && !s.isSending,
    );
    await sent.timeout(const Duration(seconds: 5));
    expect((await outbox.find(id))!.state, OutboxState.sent);
  });
}
