import 'dart:math';

import 'package:clock/clock.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

import 'support/test_support.dart';

void main() {
  late DeviceDatabase db;
  late OutboxRepository outbox;

  setUp(() {
    db = memoryDatabase();
    outbox = OutboxRepository(db);
  });
  tearDown(() => db.close());

  group('state machine', () {
    test('allows exactly the documented moves', () {
      const s = OutboxState.values;
      final allowed = {
        for (final from in s)
          for (final to in s)
            if (canMoveOutbox(from, to)) '${from.name}->${to.name}',
      };
      expect(allowed, {
        'queued->sending',
        'sending->sent',
        'sending->queued',
        'sending->problem',
        'problem->queued',
      });
    });

    test('a queued entry is claimed once; sent is final', () async {
      final entry = await outbox.enqueue(await fillHouseholdVisit());
      final id = entry.instanceId;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);

      expect(await outbox.markSent(id, serverId: 'x'), isFalse); // not sending
      expect(await outbox.markSending(id), isTrue);
      expect(await outbox.markSending(id), isFalse); // already claimed
      expect((await outbox.find(id))!.attempts, 1);

      expect(await outbox.markSent(id, serverId: 'srv1'), isTrue);
      final sent = (await outbox.find(id))!;
      expect(sent.state, OutboxState.sent);
      expect(sent.serverId, 'srv1');
      expect(sent.sentAt, isNotNull);
      // Nothing moves a sent entry, and its receipt is never deleted.
      expect(await outbox.markSending(id), isFalse);
      expect(await outbox.retry(id), isFalse);
      expect(await outbox.recoverInterrupted(), 0);
      expect((await outbox.find(id))!.state, OutboxState.sent);
    });

    test('a confirmed submission keeps only a small receipt', () async {
      final instance = await fillHouseholdVisit();
      final entry = await outbox.enqueue(
        instance,
        attachmentPaths: ['photo-1.jpg'],
      );
      final id = entry.instanceId;
      await outbox.markSending(id);
      // A temporary failure first, so there is an error to clear.
      await outbox.markRetry(
        id,
        problem: ProblemCode.serverError,
        serverMessage: 'Something went wrong.',
        nextAttemptAt: DateTime.now(),
      );
      await outbox.markSending(id);
      expect(await outbox.markSent(id, serverId: 'srv1'), isTrue);

      final receipt = (await outbox.find(id))!;
      // The submission itself is gone from the phone…
      expect(receipt.instanceXml, isEmpty);
      expect(OutboxRepository.attachmentPathsOf(receipt), isEmpty);
      expect(receipt.lastError, isNull);
      expect(receipt.lastErrorMessage, isNull);
      // …and the receipt still says what was sent, when, and that it was.
      expect(receipt.instanceId, id);
      expect(receipt.formId, sampleFormId);
      expect(receipt.formVersion, sampleFormVersion);
      expect(receipt.createdAt, entry.createdAt);
      expect(receipt.sentAt, isNotNull);
      expect(receipt.state, OutboxState.sent);
      expect(receipt.serverId, 'srv1');
      expect(
        receipt.plaintextSha256,
        OutboxRepository.plaintextDigest(instance.xml),
      );
      final listed = await outbox.watchOutbox().first;
      expect(listed.map((e) => e.instanceId), [id]);
    });

    test('a temporary failure queues again with a backoff time', () async {
      final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      final now = DateTime.utc(2026, 11, 4, 10);
      await withClock(Clock.fixed(now), () async {
        await outbox.markSending(id);
        await outbox.markRetry(
          id,
          problem: ProblemCode.serverError,
          serverMessage: 'Something went wrong.',
          nextAttemptAt: now.add(const Duration(seconds: 30)),
        );
      });
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(ProblemCode.fromName(entry.lastError), ProblemCode.serverError);
      expect(entry.lastErrorMessage, 'Something went wrong.');
      expect(entry.attempts, 1);

      expect(await outbox.due(now), isEmpty);
      expect(await outbox.due(now, ignoreBackoff: true), hasLength(1));
      expect(
        await outbox.due(now.add(const Duration(seconds: 30))),
        hasLength(1),
      );
      expect(
        await outbox.nextAttemptTime(),
        now.add(const Duration(seconds: 30)),
      );
    });

    test('a refusal becomes a problem a person can retry', () async {
      final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      await outbox.markSending(id);
      await outbox.markProblem(
        id,
        problem: ProblemCode.duplicateInstance,
        serverMessage: 'A different submission with this instance ID…',
      );
      var entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.problem);
      expect(entry.lastError, 'duplicateInstance');
      expect(await outbox.due(DateTime.now()), isEmpty);

      expect(await outbox.retry(id), isTrue);
      entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);
    });

    test('a blocked try is released without counting it', () async {
      final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      await outbox.markSending(id);
      await outbox.release(id, problem: ProblemCode.signInRequired);
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);
      expect(entry.lastError, 'signInRequired');
    });

    test('entries left mid-send by a stopped app are recovered', () async {
      final a = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      final b = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      await outbox.markSending(a);
      await outbox.markSending(b);
      expect(await outbox.recoverInterrupted(), 2);
      expect(await outbox.entries(state: OutboxState.queued), hasLength(2));
      // The try that was cut off still counts towards backoff.
      expect((await outbox.find(a))!.attempts, 1);
    });
  });

  group('enqueue', () {
    test('moves a draft into the outbox in one transaction', () async {
      final session = await FormEntrySession.start(
        xformXml: householdVisitXForm,
      );
      addTearDown(session.close);
      final drafts = DraftRepository(db);
      await drafts.save(session);
      expect(await drafts.find(session.instanceId), isNotNull);

      answerByLabel(session, 'Date of visit', '2026-11-01');
      session.next();
      answerByLabel(session, 'What happened', 'declined');
      session.next();
      answerByLabel(session, 'Why could', 'They asked us to come next week.');
      final finalised = session.finalise() as Finalised;
      final entry = await outbox.enqueue(
        finalised.instance,
        attachmentPaths: ['/data/media/photo-1.jpg'],
      );

      expect(entry.instanceId, session.instanceId);
      expect(entry.formId, sampleFormId);
      expect(entry.formVersion, sampleFormVersion);
      expect(entry.instanceXml, finalised.instance.xml);
      expect(OutboxRepository.attachmentPathsOf(entry), [
        '/data/media/photo-1.jpg',
      ]);
      expect(await drafts.find(session.instanceId), isNull);
    });

    test('is idempotent for the same XML and refuses different XML', () async {
      final instance = await fillHouseholdVisit();
      final first = await outbox.enqueue(instance);
      final again = await outbox.enqueue(instance);
      expect(again.createdAt, first.createdAt);

      final altered = FinalisedInstance(
        form: instance.form,
        instanceId: instance.instanceId,
        xml: instance.xml.replaceFirst('Rahima', 'Rokeya'),
        attachmentNames: const [],
      );
      await expectLater(
        outbox.enqueue(altered),
        throwsA(
          isA<ObhijatraException>().having(
            (e) => e.code,
            'code',
            ProblemCode.duplicateInstance,
          ),
        ),
      );
      expect(
        (await outbox.find(instance.instanceId))!.instanceXml,
        instance.xml,
      );
    });

    test('runs the field protector once, before storing', () async {
      final protector = _CountingProtector();
      final protected = OutboxRepository(db, protector: protector);
      final entry = await protected.enqueue(await fillHouseholdVisit());
      expect(protector.calls, 1);
      expect(entry.instanceXml, contains('<!-- protected -->'));
    });

    test('looks the instance up before protecting it, so queuing it again '
        'returns the stored entry even when protection is random', () async {
      final protector = _RandomNonceProtector();
      final protected = OutboxRepository(db, protector: protector);
      final instance = await fillHouseholdVisit();

      final first = await protected.enqueue(instance);
      final again = await protected.enqueue(instance);

      expect(protector.calls, 1, reason: 'protected only on insert');
      expect(again.instanceXml, first.instanceXml);
      expect(again.createdAt, first.createdAt);
      expect(await protected.entries(), hasLength(1));
    });

    test('stores the SHA-256 of the unprotected XML for the check', () async {
      final protected = OutboxRepository(
        db,
        protector: _RandomNonceProtector(),
      );
      final instance = await fillHouseholdVisit();
      final entry = await protected.enqueue(instance);
      expect(
        entry.plaintextSha256,
        OutboxRepository.plaintextDigest(instance.xml),
      );
      expect(entry.plaintextSha256, hasLength(64));
      expect(
        entry.plaintextSha256,
        isNot(OutboxRepository.plaintextDigest(entry.instanceXml)),
      );
    });

    test('different XML under a stored id is refused without protecting '
        'it', () async {
      final protector = _RandomNonceProtector();
      final protected = OutboxRepository(db, protector: protector);
      final instance = await fillHouseholdVisit();
      final stored = await protected.enqueue(instance);
      await expectLater(
        protected.enqueue(
          FinalisedInstance(
            form: instance.form,
            instanceId: instance.instanceId,
            xml: instance.xml.replaceFirst('Rahima', 'Rokeya'),
            attachmentNames: const [],
          ),
        ),
        throwsA(
          isA<ObhijatraException>().having(
            (e) => e.code,
            'code',
            ProblemCode.duplicateInstance,
          ),
        ),
      );
      expect(protector.calls, 1);
      expect(
        (await protected.find(instance.instanceId))!.instanceXml,
        stored.instanceXml,
      );
    });

    test('queuing an instance the server already holds returns its '
        'receipt', () async {
      final instance = await fillHouseholdVisit();
      final id = (await outbox.enqueue(instance)).instanceId;
      await outbox.markSending(id);
      await outbox.markSent(id, serverId: 'srv1');

      final again = await outbox.enqueue(instance);
      expect(again.state, OutboxState.sent);
      expect(again.instanceXml, isEmpty);
      expect(await outbox.entries(), hasLength(1));
    });
  });

  test('counts are watched as the outbox changes', () async {
    final counts = outbox.watchCounts();
    final seen = <OutboxCounts>[];
    final subscription = counts.listen(seen.add);
    addTearDown(subscription.cancel);

    final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
    await outbox.markSending(id);
    await outbox.markSent(id, serverId: 's');
    await pumpEventQueue();
    expect(seen.last, const OutboxCounts(sent: 1));
    expect(seen.last.pending, 0);
  });

  test('entries are watched newest first, as the outbox changes', () async {
    final seen = <List<OutboxEntry>>[];
    final subscription = outbox.watchOutbox().listen(seen.add);
    addTearDown(subscription.cancel);
    final limited = <List<OutboxEntry>>[];
    final one = outbox.watchOutbox(limit: 1).listen(limited.add);
    addTearDown(one.cancel);

    await pumpEventQueue();
    expect(seen.last, isEmpty);
    final first = await withClock(
      Clock.fixed(DateTime.utc(2026, 11, 4, 9)),
      () async => (await outbox.enqueue(await fillHouseholdVisit())).instanceId,
    );
    final second = await withClock(
      Clock.fixed(DateTime.utc(2026, 11, 4, 10)),
      () async => (await outbox.enqueue(await fillHouseholdVisit())).instanceId,
    );
    await pumpEventQueue();
    expect(seen.last.map((e) => e.instanceId), [second, first]);
    expect(limited.last.map((e) => e.instanceId), [second]);

    // A state change is seen too.
    await outbox.markSending(first);
    await outbox.markSent(first, serverId: 's');
    await pumpEventQueue();
    expect(seen.last.map((e) => e.state), [
      OutboxState.queued,
      OutboxState.sent,
    ]);
  });

  test('drafts are watched, most recently saved first', () async {
    final drafts = DraftRepository(db);
    final seen = <List<Draft>>[];
    final subscription = drafts.watchDrafts().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(seen.last, isEmpty);

    final a = await FormEntrySession.start(xformXml: householdVisitXForm);
    addTearDown(a.close);
    final b = await FormEntrySession.start(xformXml: householdVisitXForm);
    addTearDown(b.close);
    await withClock(
      Clock.fixed(DateTime.utc(2026, 11, 4, 9)),
      () => drafts.save(a),
    );
    await withClock(
      Clock.fixed(DateTime.utc(2026, 11, 4, 10)),
      () => drafts.save(b),
    );
    await pumpEventQueue();
    expect(seen.last.map((d) => d.instanceId), [b.instanceId, a.instanceId]);

    // Saving again moves a draft to the top; deleting removes it.
    await withClock(
      Clock.fixed(DateTime.utc(2026, 11, 4, 11)),
      () => drafts.save(a),
    );
    await pumpEventQueue();
    expect(seen.last.map((d) => d.instanceId), [a.instanceId, b.instanceId]);
    await drafts.delete(b.instanceId);
    await pumpEventQueue();
    expect(seen.last.map((d) => d.instanceId), [a.instanceId]);
  });
}

/// Encrypts with a fresh random nonce each time, as Phase 3 protection
/// will: protecting the same XML twice gives different XML.
final class _RandomNonceProtector implements FieldProtector {
  final _random = Random.secure();
  int calls = 0;

  @override
  Future<String> protectInstance({
    required String instanceXml,
    required FormVersionRef form,
  }) async {
    calls++;
    final nonce = List.generate(8, (_) => _random.nextInt(256)).join('.');
    return instanceXml.replaceFirst('<meta>', '<!-- nonce $nonce --><meta>');
  }
}

final class _CountingProtector implements FieldProtector {
  int calls = 0;

  @override
  Future<String> protectInstance({
    required String instanceXml,
    required FormVersionRef form,
  }) async {
    calls++;
    return instanceXml.replaceFirst('<meta>', '<!-- protected --><meta>');
  }
}
